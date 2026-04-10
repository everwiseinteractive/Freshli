import SwiftUI
import SwiftData

struct CommunityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    
    @State private var listings: [SharedListingDTO] = []
    @State private var isLoading = false
    @State private var showCreateListing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: PSSpacing.sm) {
                    Text("Community")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    Text("Share surplus food with neighbors")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                .padding(.top, PSSpacing.xl)
                
                // Create Listing Button
                Button {
                    PSHaptics.shared.lightTap()
                    showCreateListing = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Share Food")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PSSpacing.lg)
                    .background(PSColors.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                
                // Listings
                if isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else if listings.isEmpty {
                    PSEmptyState(
                        icon: "person.2",
                        title: "No Active Listings",
                        message: "Be the first to share food in your community!",
                        actionTitle: "Share Food",
                        action: { showCreateListing = true }
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: PSSpacing.lg) {
                        ForEach(listings, id: \.id) { listing in
                            CommunityListingCard(listing: listing)
                        }
                    }
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                }
            }
            .padding(.bottom, PSLayout.tabBarContentPadding)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadListings()
        }
        .sheet(isPresented: $showCreateListing) {
            CreateListingView()
        }
    }
    
    private func loadListings() async {
        isLoading = true
        listings = await syncService.fetchActiveListings()
        isLoading = false
    }
}

// MARK: - Community Listing Card

private struct CommunityListingCard: View {
    let listing: SharedListingDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: PSSpacing.xs) {
                    Text(listing.itemName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    
                    Text(listing.listingType == "share" ? "Free to Share" : "Donation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(listing.listingType == "share" ? PSColors.primaryGreen : Color.purple)
                }
                
                Spacer()
                
                Text(listing.quantity)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)
            }
            
            Text(listing.itemDescription)
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(2)
            
            Divider()
            
            HStack {
                Label("Pickup", systemImage: "mappin.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                
                Spacer()
                
                Text(listing.createdAt.relativeDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Create Listing View (Stub)

private struct CreateListingView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xl) {
                    Text("Share Food with Community")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top, PSSpacing.xl)
                    
                    Text("Feature coming soon!")
                        .font(.system(size: 16))
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            }
            .navigationTitle("Share Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CommunityView()
            .modelContainer(for: SharedListing.self, inMemory: true)
    }
}
