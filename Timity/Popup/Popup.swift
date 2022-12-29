import Foundation

struct Popup {
    let identifier: String
    let priority: Int
    let controller: PopupViewController

    init(identifier: String, priority: Int, controller: PopupViewController) {
        self.identifier = identifier
        self.priority = priority
        self.controller = controller
    }
}
