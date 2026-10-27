import SwiftUI

struct PullToRefresh: ViewModifier {
    static let threshold: CGFloat = 80

    let action: () async -> Void

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
            .gesture(
                ReleaseRecognizer {
                    if isPastThreshold {
                        Task { await action() }
                    }
                }
            )
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

private struct ReleaseRecognizer: UIGestureRecognizerRepresentable {
    let onRelease: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        if recognizer.state == .ended {
            onRelease()
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

extension View {
    func pullToRefresh(_ action: @escaping () async -> Void) -> some View {
        modifier(PullToRefresh(action: action))
    }
}
