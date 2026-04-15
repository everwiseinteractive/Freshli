import SwiftUI

struct FamilySharingView: View {
    @Environment(FamilySyncService.self) var familyService
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var showInviteSheet = false
    @State private var showConfirmLeave = false
    @State private var showJoinSheet = false
    @State private var memberToRemove: FamilyMember?
    @State private var familyName = ""
    @State private var joinShareURL: String = ""
    @State private var memberName = ""
    @State private var isCreating = false
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xl) {
                    syncStatusIndicator

                    if let family = familyService.currentFamily {
                        familyContent(family)
                    } else {
                        emptyState
                    }

                    if let error = errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .navigationTitle("Family Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .background(PSColors.backgroundPrimary)
            .sheet(isPresented: $showJoinSheet) {
                joinFamilySheet
                    .presentationDragIndicator(.visible)
                    .sheetTransition()
            }
        }
    }

    // MARK: - Sync Status Indicator

    private var syncStatusIndicator: some View {
        HStack(spacing: PSSpacing.sm) {
            switch familyService.syncStatus {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PSColors.primaryGreen)
                Text("Ready")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

            case .syncing:
                ProgressView()
                    .tint(PSColors.primaryGreen)
                Text("Syncing...")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PSColors.primaryGreen)
                Text("Synced")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textSecondary)

            case .error(let message):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(PSColors.expiredRed)
                Text(message.userMessage)
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.expiredRed)
            }

            Spacer()
        }
        .padding(PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(PSColors.expiredRed)

                Text(error)
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()

                Button {
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.expiredRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
    }

    // MARK: - Family Content

    private func familyContent(_ family: FamilyGroup) -> some View {
        VStack(spacing: PSSpacing.xl) {
            // Family group card
            PSCard {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: PSSpacing.xs) {
                            Text(family.name)
                                .font(PSTypography.headline)
                                .foregroundStyle(PSColors.textPrimary)

                            Text("\(family.members.count) member\(family.members.count == 1 ? "" : "s")")
                                .font(PSTypography.caption1)
                                .foregroundStyle(PSColors.textSecondary)

                            if familyService.isFamilyOwner {
                                Text("Owner")
                                    .font(PSTypography.caption2)
                                    .foregroundStyle(PSColors.primaryGreen)
                            }
                        }

                        Spacer()

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(PSColors.primaryGreen)
                    }

                    Divider()

                    // Members list
                    VStack(spacing: PSSpacing.md) {
                        ForEach(family.members) { member in
                            memberRow(member, family: family)
                        }
                    }
                }
            }

            // Invite section
            inviteSection

            // Shared pantry toggle
            sharedPantrySection

            // Leave family option (for non-owners)
            if !familyService.isFamilyOwner {
                VStack(spacing: PSSpacing.md) {
                    PSButton(
                        title: "Leave Family",
                        style: .secondary,
                        size: .medium,
                        isFullWidth: true,
                        action: {
                            showConfirmLeave = true
                        }
                    )
                }
            }

            // Danger zone (for owners)
            if familyService.isFamilyOwner {
                dangerZone
            }
        }
    }

    private func memberRow(_ member: FamilyMember, family: FamilyGroup) -> some View {
        HStack(spacing: PSSpacing.md) {
            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text(member.name)
                    .font(PSTypography.callout)
                    .foregroundStyle(PSColors.textPrimary)

                HStack(spacing: PSSpacing.sm) {
                    PSBadge(text: member.role.displayName, variant: .default, style: .subtle)

                    Text(member.joinDate.formatted(date: .abbreviated, time: .omitted))
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textTertiary)
                }
            }

            Spacer()

            if familyService.isFamilyOwner && member.role == .member {
                Menu {
                    Button("Remove Member", role: .destructive) {
                        memberToRemove = member
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(PSColors.textSecondary)
                }
                .accessibilityLabel("Remove \(member.name)")
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .confirmationDialog("Remove Member?", isPresented: .constant(memberToRemove != nil)) {
            if let member = memberToRemove {
                Button("Remove", role: .destructive) {
                    Task {
                        do {
                            try await familyService.removeMember(member)
                            memberToRemove = nil
                            PSHaptics.shared.success()
                        } catch {
                            errorMessage = error.localizedDescription
                            memberToRemove = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    memberToRemove = nil
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.name) from the family?")
            }
        }
    }

    // MARK: - Invite Section

    private var inviteSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Invite Family Members")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PSCard {
                VStack(spacing: PSSpacing.md) {
                    if let inviteURL = familyService.inviteURL {
                        HStack(spacing: PSSpacing.md) {
                            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                Text("Invite Link")
                                    .font(PSTypography.caption1)
                                    .foregroundStyle(PSColors.textSecondary)

                                Text(inviteURL.host() ?? "Invite")
                                    .font(PSTypography.callout)
                                    .foregroundStyle(PSColors.textPrimary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(spacing: PSSpacing.sm) {
                                Button {
                                    UIPasteboard.general.string = inviteURL.absoluteString
                                    PSHaptics.shared.lightTap()
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(PSColors.primaryGreen)
                                        .frame(width: 40, height: 40)
                                        .background(PSColors.primaryGreen.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                                }
                                .accessibilityLabel("Copy invite link")

                                ShareLink(
                                    item: inviteURL,
                                    subject: Text("Join Freshli Family"),
                                    message: Text("Join my Freshli family to share pantry items!"),
                                    label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(PSColors.primaryGreen)
                                            .frame(width: 40, height: 40)
                                            .background(PSColors.primaryGreen.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                                    }
                                )
                                .accessibilityLabel("Share invite link")
                            }
                        }
                        .padding(PSSpacing.md)
                        .background(PSColors.green50)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    } else {
                        Text("No invite link available")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Shared Pantry Section

    private var sharedPantrySection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Shared Pantry")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PSCard {
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Sync Pantry Across Devices")
                            .font(PSTypography.callout)
                            .foregroundStyle(PSColors.textPrimary)

                        Text("All family members see the same pantry")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { familyService.currentFamily?.sharedPantryEnabled ?? false },
                        set: { _ in
                            Task {
                                do {
                                    try await familyService.toggleSharedPantry()
                                    PSHaptics.shared.lightTap()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    ))
                    .tint(PSColors.primaryGreen)
                    .accessibilityLabel("Enable shared pantry")
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Family Management")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PSCard {
                VStack(spacing: PSSpacing.md) {
                    Button(role: .destructive) {
                        showConfirmLeave = true
                    } label: {
                        HStack(spacing: PSSpacing.md) {
                            Image(systemName: "arrow.uturn.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Leave Family")
                                .font(PSTypography.callout)
                            Spacer()
                        }
                        .foregroundStyle(PSColors.expiredRed)
                        .padding(PSSpacing.md)
                    }
                }
            }
            .confirmationDialog("Leave Family?", isPresented: $showConfirmLeave) {
                Button("Leave Family", role: .destructive) {
                    Task {
                        do {
                            try await familyService.leaveFamily()
                            PSHaptics.shared.success()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll no longer have access to the shared pantry. You can rejoin with an invite link later.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PSSpacing.lg) {
            PSEmptyState(
                icon: "person.2",
                title: "No Family Group Yet",
                message: "Create a family group to share your pantry with household members and sync across devices.",
                actionTitle: "Create Family",
                action: {
                    showInviteSheet = true
                }
            )

            PSButton(
                title: "Join Existing Family",
                style: .secondary,
                size: .medium,
                isFullWidth: true,
                action: {
                    showJoinSheet = true
                }
            )
        }
        .sheet(isPresented: $showInviteSheet) {
            createFamilySheet
                .presentationDragIndicator(.visible)
                .sheetTransition()
        }
    }

    private var createFamilySheet: some View {
        NavigationStack {
            Form {
                Section("Family Name") {
                    TextField("e.g., Smith Household", text: $familyName)
                }

                Section("") {
                    PSButton(
                        title: "Create Family",
                        style: .primary,
                        size: .medium,
                        isFullWidth: true,
                        isLoading: isCreating,
                        action: {
                            if !familyName.isEmpty {
                                isCreating = true
                                Task {
                                    do {
                                        try await familyService.createFamily(name: familyName)
                                        showInviteSheet = false
                                        familyName = ""
                                        PSHaptics.shared.success()
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                    isCreating = false
                                }
                            }
                        }
                    )
                    .disabled(familyName.isEmpty || isCreating)
                }
            }
            .navigationTitle("Create Family Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showInviteSheet = false
                        familyName = ""
                        isCreating = false
                    }
                }
            }
        }
    }

    private var joinFamilySheet: some View {
        NavigationStack {
            Form {
                Section("Share Link or Code") {
                    TextField("Paste invite link or code", text: $joinShareURL)
                }

                Section("Your Name") {
                    TextField("Your name in the family", text: $memberName)
                }

                Section("") {
                    PSButton(
                        title: "Join Family",
                        style: .primary,
                        size: .medium,
                        isFullWidth: true,
                        isLoading: isJoining,
                        action: {
                            if !joinShareURL.isEmpty && !memberName.isEmpty {
                                isJoining = true
                                Task {
                                    do {
                                        if let url = URL(string: joinShareURL) {
                                            try await familyService.joinFamily(shareURL: url, memberName: memberName)
                                            showJoinSheet = false
                                            joinShareURL = ""
                                            memberName = ""
                                            PSHaptics.shared.success()
                                        } else {
                                            errorMessage = "Invalid URL or code format"
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                    isJoining = false
                                }
                            }
                        }
                    )
                    .disabled(joinShareURL.isEmpty || memberName.isEmpty || isJoining)
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showJoinSheet = false
                        joinShareURL = ""
                        memberName = ""
                        isJoining = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var familyService = FamilySyncService()
    @Previewable @State var subscriptionService = SubscriptionService()

    // Create sample family for preview
    let previewFamily = FamilyGroup(
        name: "Smith Household",
        members: [
            FamilyMember(name: "Alice", role: .admin),
            FamilyMember(name: "Bob", role: .member),
            FamilyMember(name: "Charlie", role: .member)
        ],
        sharedPantryEnabled: true,
        zoneID: "FreshliFamily"
    )

    FamilySharingView()
        .environment(familyService)
        .environment(subscriptionService)
        .onAppear {
            familyService.currentFamily = previewFamily
            familyService.inviteURL = URL(string: "https://freshli.app/family/invite")
        }
}
