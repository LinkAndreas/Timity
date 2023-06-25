import UIKit
import StoreKit

final class AppRatingController: ThemeableViewController, PopupViewController {
    weak var presentationDelegate: PopupContainableControllerDelegate?

    private let contentView = UIView(frame: .zero)
    private let horizontalStackView = UIStackView(frame: .zero)
    private lazy var leftButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
        self?.leftButtonTapped()
    })

    private lazy var rightButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
        self?.rightButtonTapped()
    })

    override func loadView() {
        view = PopupContentView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        contentView.layoutIfNeeded()
        contentView.layer.shadowPath = UIBezierPath(rect: contentView.bounds).cgPath
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupLayout()
    }

    private func setupUI() {
        setupContentView()
        setupHorizontalStackView()
        setupLeftButton()
        setupRightButton()
    }

    private func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.masksToBounds = false
        contentView.layer.shadowOpacity = 0.2
        contentView.layer.shadowOffset = CGSize(width: 0, height: 10)
        contentView.layer.shadowRadius = 15
    }

    private func setupHorizontalStackView() {
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.spacing = 16
        horizontalStackView.axis = .horizontal
        horizontalStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        horizontalStackView.setContentHuggingPriority(.required, for: .vertical)
    }

    private func setupLeftButton() {
        leftButton.translatesAutoresizingMaskIntoConstraints = false
        leftButton.imageView?.contentMode = .scaleAspectFit
        leftButton.contentVerticalAlignment = .fill
        leftButton.contentHorizontalAlignment = .fill
        leftButton.setImage(UIImage(systemName: "hand.thumbsdown.circle"), for: .normal)
    }

    private func setupRightButton() {
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.imageView?.contentMode = .scaleAspectFit
        rightButton.contentVerticalAlignment = .fill
        rightButton.contentHorizontalAlignment = .fill
        rightButton.setImage(UIImage(systemName: "hand.thumbsup.circle"), for: .normal)
    }

    private func setupLayout() {
        view.addSubview(contentView)
        contentView.addSubview(horizontalStackView)
        horizontalStackView.addArrangedSubview(leftButton)
        horizontalStackView.addArrangedSubview(rightButton)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            horizontalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            horizontalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            leftButton.widthAnchor.constraint(equalToConstant: 66),
            leftButton.heightAnchor.constraint(equalToConstant: 66),
            rightButton.widthAnchor.constraint(equalToConstant: 66),
            rightButton.heightAnchor.constraint(equalToConstant: 66)
        ])
    }

    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)

        view.backgroundColor = .clear

        leftButton.tintColor = theme.highlightColor
        rightButton.tintColor = theme.highlightColor

        contentView.backgroundColor = theme.foregroundColor
        contentView.layer.shadowColor = theme.shadowColor.cgColor
    }

    private func leftButtonTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            self.presentationDelegate?.didDismiss(in: self)
        }
    }

    private func rightButtonTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            self.presentationDelegate?.didDismiss(in: self)
            SKStoreReviewController.requestReview(in: .app)
        }
    }
}
