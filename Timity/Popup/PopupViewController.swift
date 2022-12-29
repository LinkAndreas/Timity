import UIKit

protocol PopupViewController: UIViewController {
    var presentationDelegate: PopupContainableControllerDelegate? { get set }
}
