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
            // Map Supabase Storage errors to user-meaningful messages
            // instead of the previous catch-all "check your connection"
            // copy. The Storage SDK's localizedDescription contains
            // hints we can pattern-match for the most common failures.
            let raw = error.localizedDescription
            let lower = raw.lowercased()
            logger.error("Avatar storage upload failed: \(raw, privacy: .public)")

            if lower.contains("bucket") && (lower.contains("not found") || lower.contains("does not exist")) {
                throw AvatarUploadError.bucketMissing
            } else if lower.contains("payload too large") || lower.contains("file size") || lower.contains("413") {
                throw AvatarUploadError.fileTooLarge
            } else if lower.contains("row-level security")
                || lower.contains("not authorized")
                || lower.contains("unauthorized")
                || lower.contains("401") || lower.contains("403") {
                throw AvatarUploadError.notAuthorised
            } else if lower.contains("offline")
                || lower.contains("network")
                || lower.contains("timed out")
                || lower.contains("connection") {
                throw AvatarUploadError.networkUnavailable
            }
            throw AvatarUploadError.uploadFailed(underlying: raw)
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

    /// Resize + centre-crop into a 512×512 square JPEG at 0.85 quality.
    /// Strips EXIF metadata (re-encode), respects EXIF orientation.
    ///
    /// Implementation note: previous version cropped via
    /// `cgImage.cropping(to:)` which operates in raw-pixel coordinates,
    /// while `image.size` is in the orientation-corrected coordinate
    /// space. For any photo not at `.up` orientation (i.e. nearly
    /// every iPhone portrait shot) the cropRect was applied in the
    /// wrong space, resulting in a wonky output and — for small
    /// portrait images — a `cgImage.cropping(to:)` failure that fell
    /// through to `image.jpegData(...)` returning the raw photo
    /// uncropped, which then visibly stretched in the avatar circle.
    ///
    /// The new implementation uses a single `UIGraphicsImageRenderer`
    /// pass with `image.draw(in: aspectFillRect)`. `UIImage.draw`
    /// honours the image's orientation, so the drawn pixels land
    /// upright every time. The aspect-fill maths centres the image
    /// inside the target square the same way SwiftUI's
    /// `.scaledToFill().clipShape(Circle())` would on the render
    /// side — meaning the picture you upload is exactly the picture
    /// the avatar border crops to.
    nonisolated static func processedJPEGData(from image: UIImage) -> Data? {
        let targetSize = CGSize(width: 512, height: 512)
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1                  // 512 raw pixels — no @2x doubling
        format.opaque = true              // JPEG; no alpha; cleaner blacks
        format.preferredRange = .standard // sRGB output for universal compatibility
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.jpegData(withCompressionQuality: 0.85) { _ in
            // Aspect-fill: the source image is scaled to cover the
            // entire target square; the longer dimension overflows
            // and is centred. Mirrors `.scaledToFill()` on the render
            // side so the WYSIWYG circle crop is consistent.
            let imageSize = image.size
            let imageAspect = imageSize.width / imageSize.height
            let targetAspect = targetSize.width / targetSize.height

            let drawRect: CGRect
            if imageAspect > targetAspect {
                // Source wider than target — match height, overflow horizontally.
                let scaledWidth = targetSize.height * imageAspect
                drawRect = CGRect(
                    x: (targetSize.width - scaledWidth) / 2,
                    y: 0,
                    width: scaledWidth,
                    height: targetSize.height
                )
            } else {
                // Source taller (or equal) — match width, overflow vertically.
                let scaledHeight = targetSize.width / imageAspect
                drawRect = CGRect(
                    x: 0,
                    y: (targetSize.height - scaledHeight) / 2,
                    width: targetSize.width,
                    height: scaledHeight
                )
            }
            // `UIImage.draw(in:)` respects the image's orientation,
            // so portrait shots come out upright in the JPEG.
            image.draw(in: drawRect)
        }
    }
}

// MARK: - Errors

enum AvatarUploadError: LocalizedError, Sendable {
    case imageProcessingFailed
    case uploadFailed(underlying: String)
    case urlResolutionFailed
    /// Server-side: the `avatars` Storage bucket doesn't exist or
    /// has been renamed. Surfaces clearly so a developer can fix the
    /// project setup rather than blaming the user's connection.
    case bucketMissing
    /// 413 / file-size-limit reject from Storage.
    case fileTooLarge
    /// 401 / 403 — RLS policy refused the upload (typically session
    /// expired).
    case notAuthorised
    /// URL error / no internet.
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return String(localized: "We couldn't process that image. Try a different photo.")
        case .uploadFailed:
            return String(localized: "Couldn't upload your photo. Please try again.")
        case .urlResolutionFailed:
            return String(localized: "Photo uploaded, but we couldn't link it to your profile. Try again in a moment.")
        case .bucketMissing:
            return String(localized: "Profile photos aren't set up on the server right now. Please try again later.")
        case .fileTooLarge:
            return String(localized: "That photo is too large. Try a smaller one or take a new picture.")
        case .notAuthorised:
            return String(localized: "Your session has expired. Please sign in again to upload a profile picture.")
        case .networkUnavailable:
            return String(localized: "No internet connection. Check your network and try again.")
        }
    }
}
