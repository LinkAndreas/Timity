import UIKit

final class AppRatingController: ThemeableViewController, PopupViewController {
    weak var presentationDelegate: PopupContainableControllerDelegate?

    private let contentView = UIView(frame: .zero)
    private let horizontalStackView = UIStackView(frame: .zero)
    private let leadingVerticalSpacer = UIView(frame: .zero)
    private let leadingVerticalStackView = UIStackView(frame: .zero)
    private let trailingStackView = UIStackView(frame: .zero)
    private let headlineLabel = UILabel(frame: .zero)
    private lazy var dislikeButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
        self?.dislikeButtonTapped()
    })

    private lazy var likeButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
        self?.likeButtonTapped()
    })

    private lazy var dismissButton = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
        self?.dismissButtonTapped()
    })
    
    private var contentWidthConstraint: NSLayoutConstraint?
    
    private let headline: String
    private let dismissButtonTitle: String
    private let onLikeButtonTapped: () -> Void
    private let onDislikeButtonTapped: () -> Void
    private let onDismissButtonTapped: () -> Void

    init(
        headline: String,
        dismissButtonTitle: String,
        onLikeButtonTapped: @escaping () -> Void,
        onDislikeButtonTapped: @escaping () -> Void,
        onDismissButtonTapped: @escaping () -> Void
    ) {
        self.headline = headline
        self.dismissButtonTitle = dismissButtonTitle
        self.onLikeButtonTapped = onLikeButtonTapped
        self.onDislikeButtonTapped = onDislikeButtonTapped
        self.onDismissButtonTapped = onDismissButtonTapped
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Use other init instead.")
    }
    
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
        setupLeadingVerticalStackView()
        setupLeadingVerticalSpacer()
        setupTrailingStackView()
        setupHeadlineLabel()
        setupDislikeButton()
        setupLikeButton()
        setupDismissButton()
    }

    private func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.masksToBounds = false
        contentView.layer.shadowOpacity = 0.2
        contentView.layer.shadowOffset = CGSize(width: 0, height: 10)
        contentView.layer.shadowRadius = 15
        contentView.layer.cornerRadius = 10
    }

    private func setupHorizontalStackView() {
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        horizontalStackView.spacing = 16
        horizontalStackView.axis = .horizontal
        horizontalStackView.alignment = .leading
        horizontalStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        horizontalStackView.setContentHuggingPriority(.required, for: .vertical)
    }
    
    private func setupLeadingVerticalStackView() {
        leadingVerticalStackView.translatesAutoresizingMaskIntoConstraints = false
        leadingVerticalStackView.spacing = 0
        leadingVerticalStackView.axis = .vertical
        leadingVerticalStackView.alignment = .leading
        leadingVerticalStackView.distribution = .fill
        leadingVerticalStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        leadingVerticalStackView.setContentHuggingPriority(.required, for: .vertical)
    }
    
    private func setupLeadingVerticalSpacer() {
        leadingVerticalSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        leadingVerticalSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
    
    private func setupTrailingStackView() {
        trailingStackView.translatesAutoresizingMaskIntoConstraints = false
        trailingStackView.spacing = 16
        trailingStackView.axis = .horizontal
        trailingStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        trailingStackView.setContentHuggingPriority(.required, for: .vertical)
    }
    
    private func setupHeadlineLabel() {
        headlineLabel.text = headline
        headlineLabel.numberOfLines = 0
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.font = .preferredFont(forTextStyle: .body)
        headlineLabel.lineBreakMode = .byWordWrapping
    }
    
    private func setupDismissButton() {
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.setTitle(dismissButtonTitle, for: [])
    }

    private func setupDislikeButton() {
        dislikeButton.translatesAutoresizingMaskIntoConstraints = false
        dislikeButton.imageView?.contentMode = .scaleAspectFit
        dislikeButton.contentVerticalAlignment = .fill
        dislikeButton.contentHorizontalAlignment = .fill
        dislikeButton.setImage(UIImage(systemName: "hand.thumbsdown.circle"), for: .normal)
    }

    private func setupLikeButton() {
        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.imageView?.contentMode = .scaleAspectFit
        likeButton.contentVerticalAlignment = .fill
        likeButton.contentHorizontalAlignment = .fill
        likeButton.setImage(UIImage(systemName: "hand.thumbsup.circle"), for: .normal)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        contentWidthConstraint?.isActive = view.traitCollection.horizontalSizeClass == .compact
    }

    private func setupLayout() {
        view.addSubview(contentView)
        contentView.addSubview(horizontalStackView)
        horizontalStackView.addArrangedSubview(leadingVerticalStackView)
        horizontalStackView.addArrangedSubview(trailingStackView)
        leadingVerticalStackView.addArrangedSubview(headlineLabel)
        leadingVerticalStackView.addArrangedSubview(leadingVerticalSpacer)
        leadingVerticalStackView.addArrangedSubview(dismissButton)
        trailingStackView.addArrangedSubview(dislikeButton)
        trailingStackView.addArrangedSubview(likeButton)
        
        let widthConstraint = contentView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32)
        self.contentWidthConstraint = widthConstraint
        widthConstraint.isActive = view.traitCollection.horizontalSizeClass == .compact
        
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            contentView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            horizontalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            horizontalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            horizontalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            leadingVerticalSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),
            dislikeButton.widthAnchor.constraint(equalToConstant: 66),
            dislikeButton.heightAnchor.constraint(equalToConstant: 66),
            likeButton.widthAnchor.constraint(equalToConstant: 66),
            likeButton.heightAnchor.constraint(equalToConstant: 66)
        ])
    }

    override func updateAccordingToTheme(_ theme: Theme) {
        super.updateAccordingToTheme(theme)

        view.backgroundColor = .clear

        dislikeButton.tintColor = theme.highlightColor
        likeButton.tintColor = theme.highlightColor

        contentView.backgroundColor = theme.foregroundColor
        contentView.layer.shadowColor = theme.shadowColor.cgColor
    }

    private func dislikeButtonTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            self.presentationDelegate?.didDismiss(in: self)
            self.onDislikeButtonTapped()
        }
    }

    private func likeButtonTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            self.presentationDelegate?.didDismiss(in: self)
            self.onLikeButtonTapped()
        }
    }
    
    private func dismissButtonTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            self.presentationDelegate?.didDismiss(in: self)
            self.onDismissButtonTapped()
        }
    }
}
