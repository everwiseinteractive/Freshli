import SwiftUI

struct FamilySharingView: View {
    @Environment(FamilySyncService.self) var familyService
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var showInviteSheet = false
    @State private var showConfirmLeave = false
    @State private var memberToRemove: FamilyMember?
    @State private var familyName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xl) {
                    if let family = familyService.currentFamily {
                        familyContent(family)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .navigationTitle("Family Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .background(PSColors.backgroundPrimary)
        }
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

            // Danger zone
            if familyService.isAdmin {
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

            if familyService.isAdmin && member.role == .member {
                Menu {
                    Button("Remove Member", role: .destructive) {
                        memberToRemove = member
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .confirmationDialog("Remove Member?", isPresented: .constant(memberToRemove != nil)) {
            if let member = memberToRemove {
                Button("Remove", role: .destructive) {
                    familyService.removeMember(member)
                    memberToRemove = nil
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
                    if let inviteCode = familyService.inviteCode {
                        HStack(spacing: PSSpacing.md) {
                            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                Text("Invite Code")
                                    .font(PSTypography.caption1)
                                    .foregroundStyle(PSColors.textSecondary)

                                Text(inviteCode)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundStyle(PSColors.textPrimary)
                                    .tracking(2)
                            }

                            Spacer()

                            VStack(spacing: PSSpacing.sm) {
                                Button {
                                    UIPasteboard.general.string = inviteCode
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(PSColors.primaryGreen)
                                        .frame(width: 40, height: 40)
                                        .background(PSColors.primaryGreen.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                                }

                                ShareLink(
                                    item: "Join my Freshli family! Use code: \(inviteCode)",
                                    subject: Text("Join Freshli Family"),
                                    label: {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(PSColors.primaryGreen)
                                            .frame(width: 40, height: 40)
                                            .background(PSColors.primaryGreen.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                                    }
                                )
                            }
                        }
                        .padding(PSSpacing.md)
                        .background(PSColors.green50)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    }

                    PSButton(
                        title: "Generate New Code",
                        style: .secondary,
                        size: .medium,
                        isFullWidth: false,
                        action: {
                            familyService.generateInviteCode()
                        }
                    )
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
                        set: { _ in familyService.toggleSharedPantry() }
                    ))
                    .tint(PSColors.primaryGreen)
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
                    familyService.leaveFamily()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll no longer have access to the shared pantry. You can rejoin with an invite code later.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        PSEmptyState(
            icon: "person.2",
            title: "No Family Group Yet",
            message: "Create a family group to share your pantry with household members and sync across devices.",
            actionTitle: "Create Family",
            action: {
                showInviteSheet = true
            }
        )
        .sheet(isPresented: $showInviteSheet) {
            createFamilySheet
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
                        action: {
                            if !familyName.isEmpty {
                                familyService.createFamily(name: familyName)
                                showInviteSheet = false
                                familyName = ""
                            }
                        }
                    )
                    .disabled(familyName.isEmpty)
                }
            }
            .navigationTitle("Create Family Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showInviteSheet = false
                        familyName = ""
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
        sharedPantryEnabled: true
    )

    FamilySharingView()
        .environment(familyService)
        .environment(subscriptionService)
        .onAppear {
            familyService.currentFamily = previewFamily
            familyService.generateInviteCode()
        }
}
