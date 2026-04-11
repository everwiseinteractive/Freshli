import SwiftUI

// MARK: - FlowLayout
// A layout that wraps views into rows like text — each view is placed on the current
// row; if it doesn't fit, it starts a new row. Ideal for tag chips and substitution
// alternatives where the number of items is dynamic.

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    /// Convenience initialiser — equal horizontal and vertical spacing.
    init(spacing: CGFloat) {
        self.horizontalSpacing = spacing
        self.verticalSpacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, index != 0 {
                height += rowHeight + verticalSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? horizontalSpacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var rowX: CGFloat = bounds.minX
        var rowY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if rowX + size.width > bounds.maxX, index != 0 {
                rowX = bounds.minX
                rowY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: rowX, y: rowY), proposal: ProposedViewSize(size))
            rowX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
        ForEach(["spinach", "kale", "arugula", "rocket", "watercress", "bok choy"], id: \.self) { tag in
            Text(tag)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
        }
    }
    .padding()
}
