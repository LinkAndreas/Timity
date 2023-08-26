import UIKit

final class PopupManager {
    static let shared = PopupManager()

    private var window: UIWindow?
    private var isPresenting: Bool = false
    private var queue: [Popup] = []

    func enqueue(popup: Popup) {
        queue.append(popup)
        presentNextPopupIfNeeded()
    }
}

extension PopupManager {
    private func presentNextPopupIfNeeded() {
        guard !queue.isEmpty else { return }

        isPresenting = true

        window = PopupWindow(windowScene: .app)
        window?.frame = UIScreen.main.bounds
        window?.windowLevel = UIWindow.Level.statusBar + 2
        window?.rootViewController = UIViewController()
        window?.isHidden = false
        let nextPopup = queue.removeFirst()
        nextPopup.controller.modalPresentationStyle = .fullScreen
        nextPopup.controller.presentationDelegate = self
        window?.rootViewController?.present(nextPopup.controller, animated: true)
    }

    private func dismiss() {
        window?.isHidden = true
        isPresenting = false
    }
}

extension PopupManager: PopupContainableControllerDelegate {
    func didDismiss(in controller: PopupViewController) {
        dismiss()
        presentNextPopupIfNeeded()
    }
}
