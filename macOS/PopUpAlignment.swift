import Foundation

enum PopUpAlignment: String, CaseIterable {
    static let key = "popUpAlignment"

    case left
    case center
    case right

    var name: String {
        switch self {
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        }
    }

    func x(width: CGFloat, under icon: NSRect) -> CGFloat {
        switch self {
        case .left: icon.minX
        case .center: icon.midX - width / 2
        case .right: icon.maxX - width
        }
    }
}
