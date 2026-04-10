import SwiftUI

// MARK: - Circles View
// Main entry point for Freshli Circles — lists the user's private food-sharing circles
// with face piles and navigation to circle detail / creation.

struct CirclesView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = CirclesViewModel()
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.lg) {
                    headerSection
                    actionButtons

                    if viewModel.isLoading && viewModel.circles.isEmpty {
                        loadingState
                    } else if viewModel.circles.isEmpty {
                        emptyState
                    } else {
                        circlesList
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.large)
            .task {
                guard let userId = authManager.currentUserId else { return }
                await viewModel.loadCircles(userId: userId)
            }
            .refreshable {
                guard let userId = authManager.currentUserId else { return }
                await viewModel.loadCircles(userId: userId)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCircleView(viewModel: viewModel)
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinCircleView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.xs) {
            Text("Your Circles")
                .font(PSTypography.title2)
                .foregroundStyle(PSColors.textPrimary)
            Text("Private food sharing with people you trust")
                .font(PSTypography.subheadline)
                .foregroundStyle(PSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: PSSpacing.md) {
            PSButton(title: "Create Circle", icon: "plus.circle.fill", style: .primary, size: .medium) {
                PSHaptics.shared.lightTap()
                showCreateSheet = true
            }

            PSButton(title: "Join Circle", icon: "person.badge.plus", style: .secondary, size: .medium) {
                PSHaptics.shared.lightTap()
                showJoinSheet = true
            }
        }
    }

    // MARK: - Circles List

    private var circlesList: some View {
        LazyVStack(spacing: PSSpacing.md) {
            ForEach(viewModel.circles) { circle in
                NavigationLink {
                    CircleDetailView(circle: circle, viewModel: viewModel)
                } label: {
                    CircleRowView(circle: circle, viewModel: viewModel)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        PSGlassCard {
            VStack(spacing: PSSpacing.lg) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PSColors.primaryGreen)

                Text("No circles yet")
                    .font(PSTypography.headline)
                    .foregroundStyle(PSColors.textPrimary)

                Text("Create a circle to start sharing food with family, friends, or neighbors privately.")
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, PSSpacing.lg)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: PSSpacing.md) {
            ProgressView()
                .tint(PSColors.primaryGreen)
            Text("Loading your circles...")
                .font(PSTypography.subheadline)
                .foregroundStyle(PSColors.textSecondary)
        }
        .padding(.vertical, PSSpacing.xxxl)
    }
}

// MARK: - Circle Row

private struct CircleRowView: View {
    let circle: SupabaseCircle
    let viewModel: CirclesViewModel

    var body: some View {
        PSCard {
            HStack(spacing: PSSpacing.md) {
                // Emoji avatar
                Text(circle.emoji ?? "🏠")
                    .font(.system(size: 36))
                    .frame(width: 52, height: 52)
                    .background(PSColors.emeraldLight)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))

                VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                    Text(circle.name)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.textPrimary)

                    if let desc = circle.description {
                        Text(desc)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(PSTypography.caption1)
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
    }
}

// MARK: - Join Circle Sheet

private struct JoinCircleView: View {
    @Bindable var viewModel: CirclesViewModel
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.xxl) {
                VStack(spacing: PSSpacing.sm) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(PSColors.primaryGreen)

                    Text("Join a Circle")
                        .font(PSTypography.title2)
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Enter the invite code shared by a circle member")
                        .font(PSTypography.subheadline)
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, PSSpacing.xxl)

                TextField("Invite Code", text: $viewModel.joinCode)
                    .font(PSTypography.title3)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(PSSpacing.lg)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.expiredRed)
                }

                PSButton(title: "Join Circle", icon: "person.badge.plus", isLoading: viewModel.isLoading) {
                    guard let userId = authManager.currentUserId else { return }
                    Task {
                        if await viewModel.joinCircle(userId: userId) {
                            dismiss()
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
