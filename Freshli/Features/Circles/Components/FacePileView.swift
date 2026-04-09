import SwiftUI

// MARK: - Face Pile View
// Overlapping avatar stack showing circle members. Uses HStack with negative spacing
// and zIndex ordering so earlier avatars layer on top.

struct FacePileView: View {
    let members: [SupabaseCircleMember]
    var maxVisible: Int = 4
    var avatarSize: CGFloat = 36

    private var visibleMembers: [SupabaseCircleMember] {
        Array(members.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, members.count - maxVisible)
    }

    var body: some View {
        HStack(spacing: -(avatarSize * 0.3)) {
            ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                AvatarCircle(
                    displayName: member.displayName,
                    avatarUrl: member.avatarUrl,
                    size: avatarSize
                )
                .zIndex(Double(visibleMembers.count - index))
            }

            if overflowCount > 0 {
                OverflowBadge(count: overflowCount, size: avatarSize)
                    .zIndex(0)
            }
        }
    }
}

// MARK: - Avatar Circle

private struct AvatarCircle: View {
    let displayName: String?
    let avatarUrl: String?
    let size: CGFloat

    private var initials: String {
        guard let name = displayName, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Group {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(PSColors.backgroundPrimary, lineWidth: 2)
        )
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(PSColors.emeraldLight)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(PSColors.primaryGreen)
        }
    }
}

// MARK: - Overflow Badge

private struct OverflowBadge: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(PSColors.backgroundTertiary)
            Text("+\(count)")
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(PSColors.backgroundPrimary, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview {
    let sampleMembers = (0..<6).map { i in
        SupabaseCircleMember(
            id: UUID(),
            circleId: UUID(),
            userId: UUID(),
            role: "member",
            displayName: ["Alice", "Bob", "Carol", "Dan", "Eve", "Frank"][i],
            avatarUrl: nil,
            joinedAt: Date()
        )
    }

    VStack(spacing: PSSpacing.xl) {
        FacePileView(members: Array(sampleMembers.prefix(3)))
        FacePileView(members: sampleMembers)
        FacePileView(members: sampleMembers, maxVisible: 2, avatarSize: 48)
    }
    .padding()
}
