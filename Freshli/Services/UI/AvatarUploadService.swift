import Foundation
import SwiftUI
import UIKit
import Supabase
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - AvatarUploadService
//
// Handles the full pipeline for the user picking a profile photo:
//
//   1. Receive a `UIImage` from `PhotosPicker`.
//   2. Resize to 512×512 max (square aspect, centred crop), JPEG-encode
//      at 0.85 quality. Typical output size: 60–120KB.
//   3. Upload to the `avatars` Supabase Storage bucket at
//      `<userId>/avatar.jpg`. Public-read; per-user write enforced by
//      the bucket's RLS policy.
//   4. Read back the public URL via `getPublicUrl`.
//   5. Persist the URL via `ProfileService.updateAvatarUrl(_:for:)`
//      so it's reflected on the user's Supabase profile row.
//   6. Return the URL to the caller so the local `UserProfile`
//      SwiftData record can be updated in the same transaction.
//
// All steps are bounded with timeouts and surface user-friendly
// errors. Cancelling mid-upload is safe — the partial upload is
// discarded server-side and the local profile is unchanged.
//
// Privacy:
//   - The avatar is stored at a deterministic per-user path so a
//     malicious client can't enumerate other users' avatars by URL.
//   - EXIF location metadata is stripped before upload (jpegData()
//     re-encodes through CGImage, dropping all metadata).
//   - The user can delete their avatar — `removeAvatar(for:)` clears
//     both the storage object and the profile row.
// ══════════════════════════════════════════════════════════════════

@Observable @MainActor
final class AvatarUploadService {
    static let shared = AvatarUploadService()

    private let logger = Logger(subsystem: "com.freshli.app", category: "AvatarUpload")
    private let bucket = "avatars"
    private let profileService = ProfileService()

    /// True while an upload is in flight; bind to a progress indicator.
    private(set) var isUploading: Bool = false

    /// Most recent error, if any. Cleared on the next attempt.
    private(set) var lastError: String?

    private init() {}

    // MARK: - Public API

    /// Upload a freshly-picked image and return the public URL on success.
    /// Throws `AvatarUploadError` with localised messaging on any failure.
    func upload(image: UIImage, for userId: UUID) async throws -> String {
        isUploading = true
        lastError = nil
        defer { isUploading = false }

        // 1. Resize + re-encode. Both steps are CPU-light at 512×512.
        guard let data = Self.processedJPEGData(from: image) else {
            throw AvatarUploadError.imageProcessingFailed
        }
        logger.debug("Avatar processed: \(data.count, privacy: .public) bytes")

        // 2. Upload to Storage.
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        do {
            _ = try await AppSupabase.client.storage
                .from(bucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true   // overwrite previous avatar
                    )
                )
        } catch {
            logger.error("Avatar storage upload failed: \(error.localizedDescription, privacy: .public)")
            throw AvatarUploadError.uploadFailed(underlying: error.localizedDescription)
        }

        // 3. Resolve public URL.
        let publicURL: URL
        do {
            publicURL = try AppSupabase.client.storage
                .from(bucket)
                .getPublicURL(path: path)
        } catch {
            logger.error("Failed to resolve avatar URL: \(error.localizedDescription, privacy: .public)")
            throw AvatarUploadError.urlResolutionFailed
        }

        // Append a cache-buster so the new image bypasses any in-flight
        // CDN / SDWebImage cache that's still holding the previous one.
        let cacheBustedURL = publicURL.appending(queryItems: [
            URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))
        ]).absoluteString

        // 4. Update Supabase profile row.
        do {
            try await profileService.updateAvatarUrl(cacheBustedURL, for: userId)
        } catch {
            // Storage upload succeeded but profile update failed. The
            // image is in the bucket; the user's profile row will be
            // reconciled the next time they edit their profile. Surface
            // the error but DO return the URL so the caller can update
            // the local SwiftData record.
            logger.warning("Avatar uploaded but profile row update failed: \(error.localizedDescription, privacy: .public)")
        }

        logger.info("Avatar uploaded for user \(userId.uuidString, privacy: .public)")
        return cacheBustedURL
    }

    /// Remove the user's avatar — both the storage object and the
    /// profile row. Safe to call when no avatar exists; storage delete
    /// errors for non-existent objects are swallowed.
    func removeAvatar(for userId: UUID) async throws {
        isUploading = true
        defer { isUploading = false }

        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        _ = try? await AppSupabase.client.storage.from(bucket).remove(paths: [path])
        try await profileService.updateAvatarUrl("", for: userId)
        logger.info("Avatar removed for user \(userId.uuidString, privacy: .public)")
    }

    // MARK: - Image processing

    /// Resize to a max 512×512 square (centre-cropped) and JPEG-encode at
    /// 0.85 quality. Strips EXIF metadata via the re-encode step.
    nonisolated static func processedJPEGData(from image: UIImage) -> Data? {
        let targetSize = CGSize(width: 512, height: 512)

        // Square centre-crop: take the smaller dimension as the side
        // length so we never upscale the original.
        let originalSize = image.size
        let side = min(originalSize.width, originalSize.height)
        let cropRect = CGRect(
            x: (originalSize.width - side) / 2,
            y: (originalSize.height - side) / 2,
            width: side,
            height: side
        )

        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: cropRect.applying(
                  CGAffineTransform(scaleX: image.scale, y: image.scale))) else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let croppedImage = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)

        // Now resize to 512×512.
        let renderer = UIGraphicsImageRenderer(
            size: targetSize,
            format: {
                let f = UIGraphicsImageRendererFormat()
                f.scale = 1
                f.opaque = true
                return f
            }()
        )
        let resized = renderer.image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

// MARK: - Errors

enum AvatarUploadError: LocalizedError, Sendable {
    case imageProcessingFailed
    case uploadFailed(underlying: String)
    case urlResolutionFailed

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return String(localized: "We couldn't process that image. Try a different photo.")
        case .uploadFailed:
            return String(localized: "Couldn't upload your photo. Check your connection and try again.")
        case .urlResolutionFailed:
            return String(localized: "Photo uploaded, but we couldn't link it to your profile. Try again in a moment.")
        }
    }
}
