import SwiftUI
import PhotosUI
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - FreshliAvatar
//
// The single avatar component used everywhere the app needs to display
// a user's profile picture: Profile tab header, Community marketplace
// listing cards, comment threads, family-sharing roster, etc.
//
// Behaviour:
//   - Renders the user's uploaded photo from `avatarURL` via SwiftUI's
//     `AsyncImage` with a graceful loading state and a deterministic
//     coloured-initials fallback for users who haven't uploaded one.
//   - Initials fallback: first letter of first word + first letter of
//     last word from `displayName`, white text on a stable per-user
//     coloured background derived from a hash of the user's id —
//     consistent across launches so the same user always gets the same
//     colour, but no single colour is over-represented.
//   - Sizes scale with `AvatarSize` so the same view works for the
//     14pt comment-thread avatar and the 96pt profile-header avatar.
//
// This view is presentational only. The upload flow is handled by
// `FreshliAvatarPicker` below.
// ══════════════════════════════════════════════════════════════════

public enum AvatarSize: CGFloat {
    case xs = 24    // pile views
    case sm = 36    // list rows
    case md = 48    // listing cards
    case lg = 72    // profile detail
    case xl = 96    // profile header
    case xxl = 128  // edit profile sheet

    var fontSize: CGFloat { rawValue * 0.42 }
    var fontWeight: Font.Weight {
        rawValue >= 72 ? .bold : .semibold
    }
}

@MainActor
public struct FreshliAvatar: View {
    let displayName: String
    let avatarURL: String?
    let userIdSeed: String
    let size: AvatarSize

    public init(
        displayName: String,
        avatarURL: String?,
        userIdSeed: String = "",
        size: AvatarSize = .md
    ) {
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.userIdSeed = userIdSeed
        self.size = size
    }

    public var body: some View {
        Group {
            if let urlString = avatarURL?.trimmingCharacters(in: .whitespaces),
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        initialsFallback
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                    .opacity(0.7)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsFallback
                    @unknown default:
                        initialsFallback
                    }
                }
            } else {
                initialsFallback
            }
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: size.rawValue >= 72 ? 2 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(displayName.isEmpty ? String(localized: "Profile picture") : "\(displayName)'s profile picture")
    }

    private var initialsFallback: some View {
        ZStack {
            Self.colorForSeed(userIdSeed.isEmpty ? displayName : userIdSeed)
            Text(initials)
                .font(.system(size: size.fontSize, weight: size.fontWeight, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let parts = displayName
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map(String.init)
        guard !parts.isEmpty else { return "?" }
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.last?.prefix(1) ?? ""
        return (String(first) + String(last)).uppercased()
    }

    /// Deterministic colour from a hash of the seed. Picks from a 12-
    /// colour palette tuned for white text legibility (WCAG AA on white).
    private static func colorForSeed(_ seed: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.133, green: 0.773, blue: 0.369),  // green
            Color(red: 0.078, green: 0.722, blue: 0.651),  // teal
            Color(red: 0.231, green: 0.510, blue: 0.965),  // blue
            Color(red: 0.553, green: 0.361, blue: 0.965),  // purple
            Color(red: 0.835, green: 0.337, blue: 0.620),  // pink
            Color(red: 0.961, green: 0.620, blue: 0.043),  // amber
            Color(red: 0.831, green: 0.094, blue: 0.239),  // red
            Color(red: 0.180, green: 0.529, blue: 0.451),  // emerald-deep
            Color(red: 0.388, green: 0.400, blue: 0.965),  // indigo
            Color(red: 0.937, green: 0.471, blue: 0.137),  // orange
            Color(red: 0.314, green: 0.624, blue: 0.471),  // sage
            Color(red: 0.471, green: 0.314, blue: 0.624)   // violet
        ]
        var hash: UInt32 = 5381
        for byte in seed.utf8 {
            hash = (hash &* 33) &+ UInt32(byte)
        }
        return palette[Int(hash) % palette.count]
    }
}

// ══════════════════════════════════════════════════════════════════
// MARK: - FreshliAvatarPicker
//
// Edit-profile UI surface: shows the current avatar with a small camera
// badge, opens the system PhotosPicker on tap, runs the upload via
// AvatarUploadService, and reports the resulting URL back via a binding.
//
// Loading and error states are inline — no separate alert needed.
// ══════════════════════════════════════════════════════════════════

@MainActor
public struct FreshliAvatarPicker: View {
    let displayName: String
    let userId: UUID
    @Binding var avatarURL: String?

    @State private var pickerItem: PhotosPickerItem?
    @State private var uploadService = AvatarUploadService.shared
    @State private var inlineError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.freshli.app", category: "FreshliAvatarPicker")

    public init(displayName: String, userId: UUID, avatarURL: Binding<String?>) {
        self.displayName = displayName
        self.userId = userId
        self._avatarURL = avatarURL
    }

    public var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    FreshliAvatar(
                        displayName: displayName,
                        avatarURL: avatarURL,
                        userIdSeed: userId.uuidString,
                        size: .xxl
                    )
                    .opacity(uploadService.isUploading ? 0.55 : 1.0)
                    .overlay {
                        if uploadService.isUploading {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                        }
                    }

                    if !uploadService.isUploading {
                        cameraBadge
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(uploadService.isUploading)
            .accessibilityLabel(String(localized: "Edit profile picture"))
            .accessibilityHint(String(localized: "Opens your photo library to choose a new profile picture"))

            if let error = inlineError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color(red: 0.831, green: 0.094, blue: 0.239))
                    .multilineTextAlignment(.center)
            }

            if avatarURL != nil && !uploadService.isUploading {
                Button(role: .destructive) {
                    Task { await removeAvatar() }
                } label: {
                    Label(String(localized: "Remove photo"), systemImage: "trash")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePicked(newItem) }
        }
    }

    // MARK: - Subviews

    private var cameraBadge: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.133, green: 0.773, blue: 0.369))
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

            Image(systemName: "camera.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Actions

    private func handlePicked(_ item: PhotosPickerItem) async {
        inlineError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                inlineError = String(localized: "We couldn't read that image. Try a different photo.")
                pickerItem = nil
                return
            }
            let url = try await uploadService.upload(image: image, for: userId)
            avatarURL = url
            logger.info("Avatar updated to \(url, privacy: .public)")
        } catch let avatarError as AvatarUploadError {
            inlineError = avatarError.errorDescription
        } catch {
            inlineError = String(localized: "Couldn't update your profile picture. Please try again.")
            logger.error("Avatar upload error: \(error.localizedDescription, privacy: .public)")
        }
        pickerItem = nil
    }

    private func removeAvatar() async {
        inlineError = nil
        do {
            try await uploadService.removeAvatar(for: userId)
            avatarURL = nil
        } catch {
            inlineError = String(localized: "Couldn't remove your photo. Please try again.")
        }
    }
}

// MARK: - Previews

#Preview("Avatar — sizes (initials fallback)") {
    HStack(spacing: 16) {
        FreshliAvatar(displayName: "Sam Wilson", avatarURL: nil, size: .xs)
        FreshliAvatar(displayName: "Maya Rodriguez", avatarURL: nil, size: .sm)
        FreshliAvatar(displayName: "Priya Sharma", avatarURL: nil, size: .md)
        FreshliAvatar(displayName: "Marcus Tan", avatarURL: nil, size: .lg)
        FreshliAvatar(displayName: "Sofia Garcia", avatarURL: nil, size: .xl)
    }
    .padding()
}

#Preview("Avatar — picker") {
    FreshliAvatarPicker(
        displayName: "Sam Wilson",
        userId: UUID(),
        avatarURL: .constant(nil)
    )
    .padding()
}
