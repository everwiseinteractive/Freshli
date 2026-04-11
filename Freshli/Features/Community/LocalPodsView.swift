import SwiftUI
import MapKit

// MARK: - Local Pods View
// Hyper-local "Verified Pod" micro-communities + Community Fridge map.

struct LocalPodsView: View {
    @State private var podService = CommunityPodsService.shared
    @State private var activeTab: PodsTab = .pods
    @State private var showJoinSheet = false
    @State private var selectedPod: LocalPod?
    @State private var showCodeSheet = false
    @State private var joinCodeInput = ""
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.505, longitude: -0.09),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))
    @Namespace private var tabNamespace

    enum PodsTab: String, CaseIterable {
        case pods   = "My Pods"
        case fridges = "Community Fridges"
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if activeTab == .pods {
                ScrollView {
                    VStack(spacing: PSSpacing.xxl) {
                        podsHero
                        nearbyPodsSection
                        createPodSection
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.vertical, PSSpacing.lg)
                }
                .background(PSColors.backgroundPrimary)
            } else {
                communityFridgeContent
            }
        }
        .navigationTitle("Local Network")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCodeSheet) { joinByCodeSheet }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PodsTab.allCases, id: \.self) { tab in
                Button {
                    PSHaptics.shared.lightTap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab }
                } label: {
                    VStack(spacing: PSSpacing.xxs) {
                        Text(tab.rawValue)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                            .foregroundStyle(activeTab == tab ? PSColors.primaryGreen : PSColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PSSpacing.md)
                        Rectangle()
                            .fill(activeTab == tab ? PSColors.primaryGreen : Color.clear)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "podTab", in: tabNamespace, isSource: activeTab == tab)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(PSColors.surfaceCard)
    }

    // MARK: - Pods Hero

    private var podsHero: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x3B82F6).opacity(0.15), PSColors.accentTeal.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                Image(systemName: "person.3.fill")
                    .font(.system(size: PSLayout.scaledFont(30)))
                    .foregroundStyle(Color(hex: 0x3B82F6))
            }
            VStack(spacing: PSSpacing.xs) {
                Text("Your Building, Your Community")
                    .font(.system(size: PSLayout.scaledFont(19), weight: .black, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Share food with neighbours one flight of stairs away — no travel, no awkward handoffs.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Nearby Pods

    private var nearbyPodsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            HStack {
                sectionHeader("Pods Near You", icon: "location.fill", color: Color(hex: 0x3B82F6))
                Spacer()
                Button { showCodeSheet = true } label: {
                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "number").font(.system(size: PSLayout.scaledFont(11)))
                        Text("Enter Code")
                            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: 0x3B82F6))
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(Color(hex: 0x3B82F6).opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
            ForEach(podService.nearbyPods) { pod in
                podRow(pod)
            }
        }
    }

    private func podRow(_ pod: LocalPod) -> some View {
        let joined = podService.isJoined(pod)
        return HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(pod.podType.color.opacity(0.12))
                    .frame(width: PSLayout.scaled(48), height: PSLayout.scaled(48))
                Image(systemName: pod.podType.icon)
                    .font(.system(size: PSLayout.scaledFont(20)))
                    .foregroundStyle(pod.podType.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PSSpacing.xs) {
                    Text(pod.name)
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    if pod.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: PSLayout.scaledFont(11)))
                            .foregroundStyle(Color(hex: 0x3B82F6))
                    }
                }
                Text(pod.address)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(1)
                HStack(spacing: PSSpacing.sm) {
                    Label("\(pod.memberCount) members", systemImage: "person.2")
                    Label("\(pod.activeListings) active", systemImage: "tag.fill")
                }
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .labelStyle(.titleAndIcon)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: PSSpacing.xs) {
                Text(formatDistance(pod.distanceMetres))
                    .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
                Button {
                    PSHaptics.shared.mediumTap()
                    if joined { podService.leave(pod: pod) } else { podService.join(pod: pod) }
                } label: {
                    Text(joined ? "Leave" : "Join")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                        .foregroundStyle(joined ? PSColors.expiredRed : .white)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.xs)
                        .background(joined ? PSColors.expiredRed.opacity(0.1) : pod.podType.color)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(PSSpacing.lg)
        .background(joined ? pod.podType.color.opacity(0.04) : PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(joined ? pod.podType.color.opacity(0.3) : PSColors.borderLight, lineWidth: 1))
    }

    // MARK: - Create Pod CTA

    private var createPodSection: some View {
        VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(24)))
                    .foregroundStyle(PSColors.primaryGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a Pod")
                        .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Set up a micro-community for your building or street")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(PSSpacing.lg)
            .background(PSColors.primaryGreen.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.primaryGreen.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Community Fridge Map

    private var communityFridgeContent: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                ForEach(podService.communityFridges) { fridge in
                    Annotation(fridge.name, coordinate: CLLocationCoordinate2D(
                        latitude: fridge.latitude, longitude: fridge.longitude)) {
                        fridgeMapPin(fridge)
                    }
                }
            }
            .frame(maxHeight: PSLayout.scaled(300))

            ScrollView {
                VStack(spacing: PSSpacing.md) {
                    HStack {
                        sectionHeader("Community Fridges", icon: "refrigerator.fill", color: PSColors.accentTeal)
                        Spacer()
                        Text("\(podService.communityFridges.filter { $0.currentStatus == .available }.count) available")
                            .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                            .foregroundStyle(PSColors.primaryGreen)
                            .padding(.horizontal, PSSpacing.sm)
                            .padding(.vertical, PSSpacing.xxs)
                            .background(PSColors.primaryGreen.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    ForEach(podService.communityFridges) { fridge in
                        fridgeRow(fridge)
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)
            }
            .background(PSColors.backgroundPrimary)
        }
    }

    private func fridgeMapPin(_ fridge: CommunityFridge) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(fridge.currentStatus.color.opacity(0.2))
                    .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: PSLayout.scaledFont(16)))
                    .foregroundStyle(fridge.currentStatus.color)
            }
            Image(systemName: "triangle.fill")
                .font(.system(size: PSLayout.scaledFont(6)))
                .foregroundStyle(fridge.currentStatus.color.opacity(0.6))
                .rotationEffect(.degrees(180))
        }
    }

    private func fridgeRow(_ fridge: CommunityFridge) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fridge.currentStatus.color.opacity(0.12))
                    .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                Image(systemName: fridge.currentStatus.icon)
                    .font(.system(size: PSLayout.scaledFont(18)))
                    .foregroundStyle(fridge.currentStatus.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(fridge.name)
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(fridge.address)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(1)
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: fridge.isOpen24h ? "clock.fill" : "clock")
                        .font(.system(size: PSLayout.scaledFont(10)))
                    Text(fridge.isOpen24h ? "Open 24/7" : (fridge.openingHours ?? "See hours"))
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                }
                .foregroundStyle(PSColors.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: PSSpacing.xxs) {
                Text(fridge.currentStatus.rawValue)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                    .foregroundStyle(fridge.currentStatus.color)
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, 2)
                    .background(fridge.currentStatus.color.opacity(0.1))
                    .clipShape(Capsule())
                Text(fridge.organisedBy)
                    .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(PSColors.borderLight, lineWidth: 1))
    }

    // MARK: - Join by Code Sheet

    private var joinByCodeSheet: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.xxl) {
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(50)))
                        .foregroundStyle(Color(hex: 0x3B82F6))
                    Text("Join with a Pod Code")
                        .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                    Text("Your neighbour can share a 6-character code to invite you to their pod.")
                        .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Pod Code (e.g. MAPLE7)", text: $joinCodeInput)
                    .font(.system(size: PSLayout.scaledFont(20), weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textCase(.uppercase)
                    .padding(PSSpacing.lg)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))

                Button {
                    PSHaptics.shared.mediumTap()
                    showCodeSheet = false
                } label: {
                    Text("Join Pod")
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PSSpacing.lg)
                        .background(Color(hex: 0x3B82F6))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(joinCodeInput.count < 4)
                .opacity(joinCodeInput.count < 4 ? 0.5 : 1)

                Spacer()
            }
            .padding(PSSpacing.screenHorizontal)
            .padding(.top, PSSpacing.xxl)
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Enter Pod Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showCodeSheet = false }
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon).font(.system(size: PSLayout.scaledFont(13))).foregroundStyle(color)
            Text(title)
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase).tracking(0.5)
        }
    }

    private func formatDistance(_ metres: Double) -> String {
        metres < 1000 ? "\(Int(metres))m away" : String(format: "%.1fkm", metres / 1000)
    }
}

#Preview {
    NavigationStack { LocalPodsView() }
}
