import SwiftUI
import LinkPresentation

// MARK: - Link Preview Card
// Uses LinkPresentation framework to fetch rich metadata (title, icon, image)
// for replenish item product links.

struct LinkPreviewCard: View {
    let url: URL
    let itemName: String

    @State private var metadata: LinkMetadataState = .loading

    var body: some View {
        Group {
            switch metadata {
            case .loading:
                loadingView
            case .loaded(let title, let siteName):
                loadedView(title: title, siteName: siteName)
            case .failed:
                fallbackView
            }
        }
        .task(id: url) {
            await fetchMetadata()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        HStack(spacing: PSSpacing.md) {
            RoundedRectangle(cornerRadius: PSSpacing.radiusSm)
                .fill(PSColors.backgroundSecondary)
                .frame(width: 44, height: 44)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                }

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(PSColors.backgroundSecondary)
                    .frame(width: 140, height: 12)

                RoundedRectangle(cornerRadius: 4)
                    .fill(PSColors.backgroundSecondary)
                    .frame(width: 90, height: 10)
            }

            Spacer()
        }
        .padding(PSSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func loadedView(title: String, siteName: String?) -> some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(PSColors.primaryGreen)
                .frame(width: 44, height: 44)
                .background(PSColors.primaryGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(title)
                    .font(PSTypography.caption1Medium)
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)

                if let siteName {
                    Text(siteName)
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(PSSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var fallbackView: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: "globe")
                .font(.system(size: 20))
                .foregroundStyle(PSColors.textTertiary)
                .frame(width: 44, height: 44)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))

            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(itemName)
                    .font(PSTypography.caption1Medium)
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)

                Text(url.host ?? url.absoluteString)
                    .font(PSTypography.caption2)
                    .foregroundStyle(PSColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(PSSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Metadata Fetch

    @MainActor
    private func fetchMetadata() async {
        metadata = .loading
        let provider = LPMetadataProvider()

        do {
            let lpMetadata = try await provider.startFetchingMetadata(for: url)
            let title = lpMetadata.title ?? itemName
            let siteName = lpMetadata.url?.host
            metadata = .loaded(title: title, siteName: siteName)
        } catch {
            metadata = .failed
        }
    }
}

// MARK: - Metadata State

private enum LinkMetadataState {
    case loading
    case loaded(title: String, siteName: String?)
    case failed
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        LinkPreviewCard(
            url: URL(string: "https://instacart.com/store/search?q=milk")!,
            itemName: "Whole Milk"
        )

        LinkPreviewCard(
            url: URL(string: "https://amazon.com/fresh")!,
            itemName: "Organic Eggs"
        )
    }
    .padding()
    .background(PSColors.backgroundPrimary)
}
