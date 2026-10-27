import SwiftUI

struct PullToRefresh: ViewModifier {
    static let threshold: CGFloat = 80

    @State private var pullDistance: CGFloat = 0

    private var isPastThreshold: Bool {
        pullDistance >= Self.threshold
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                -(geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, distance in
                pullDistance = distance
            }
            .overlay(alignment: .top) {
                Text(isPastThreshold ? "Release to update" : "Pull to update")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: max(pullDistance, 0))
                    .opacity(min(max(pullDistance, 0) / Self.threshold, 1))
                    .allowsHitTesting(false)
            }
            .sensoryFeedback(.impact, trigger: isPastThreshold) { _, isPast in
                isPast
            }
    }
}

extension View {
    func pullToRefresh() -> some View {
        modifier(PullToRefresh())
    }
}
