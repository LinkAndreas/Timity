import UIKit

protocol PopupContainableControllerDelegate: AnyObject {
    func didDismiss(in controller: PopupViewController)
}
