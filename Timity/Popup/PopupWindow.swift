import UIKit

final class PopupWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        return hitView is PopupContentView ? nil : hitView
    }
}
