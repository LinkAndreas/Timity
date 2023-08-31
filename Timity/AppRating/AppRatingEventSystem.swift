import Foundation
import StoreKit

final class AppRatingEventSystem {
    private var isPaused: Bool = false
    private var eventAddedEventCounter: Int = 0
    private var usedCalculatorEventCounter: Int = 0

    private let config: AppRatingEventSystemConfig
    private var dataSource: AppRatingEventSystemDataSource
    private let onPopupTriggerReceived: (_ notifyTriggerHandled: @escaping () -> Void) -> Void

    init(
        config: AppRatingEventSystemConfig,
        dataSource: AppRatingEventSystemDataSource,
        onPopupTriggerReceived: @escaping (_ notifyTriggerHandled: @escaping () -> Void) -> Void
    ) {
        self.config = config
        self.dataSource = dataSource
        self.onPopupTriggerReceived = onPopupTriggerReceived
    }
    
    func send(event: AppRatingEvent) {
        guard !isPaused else { return }
        guard !dataSource.isPopupAnswered else { return }
        guard dataSource.popupDismissCount < config.maxDismissCount else { return }

        switch event {
        case .eventAdded:
            eventAddedEventCounter += 1
        case .usedCalculator:
            usedCalculatorEventCounter += 1
        }
        
        checkPopupTrigger()
    }
    
    private func checkPopupTrigger() {
        if eventAddedEventCounter >= config.eventAddedThreshold {
            triggerPopup()
        } else if usedCalculatorEventCounter >= config.usedCalculatorThreshold {
            triggerPopup()
        }
    }
    
    private func triggerPopup() {
        isPaused = true
        onPopupTriggerReceived { [weak self] in
            self?.isPaused = false
        }
        resetEventCounters()
    }
    
    private func resetEventCounters() {
        resetEventAddedEventCounter()
        resetUsedCalculatorEventCounter()
    }
    
    private func resetEventAddedEventCounter() {
        eventAddedEventCounter = 0
    }
    
    private func resetUsedCalculatorEventCounter() {
        usedCalculatorEventCounter = 0
    }
}

extension AppRatingEventSystem {
    static var `default`: AppRatingEventSystem = {
        let config = AppRatingEventSystemConfig(
            eventAddedThreshold: 2,
            usedCalculatorThreshold: 3,
            maxDismissCount: 3
        )
        let dataSource = LocalAppRatingEventSystemDataSource()
        return AppRatingEventSystem(
            config: config,
            dataSource: dataSource,
            onPopupTriggerReceived: { notifyTriggerHandled in
                let presenter = AppRatingPopupPresenter(
                    popupDismissCount: dataSource.popupDismissCount,
                    maxPopupDismissCount: config.maxDismissCount
                )
                let popup = Popup(controller: AppRatingController(
                    headline: presenter.headline,
                    dismissButtonTitle: presenter.dismissButtonTitle,
                    onLikeButtonTapped: {
                        Settings.shared.isAppRatingPopupAnswered = true
                        SKStoreReviewController.requestReview(in: .active)
                        notifyTriggerHandled()
                    },
                    onDislikeButtonTapped: {
                        Settings.shared.isAppRatingPopupAnswered = true
                        notifyTriggerHandled()
                        AlertManager.shared.showFeedbackMailComposer()
                    },
                    onDismissButtonTapped: {
                        Settings.shared.appRatingPopupDismissCount += 1
                        notifyTriggerHandled()
                    }
                ))
                PopupManager.shared.enqueue(popup: popup)
            }
        )
    }()
}

final class LocalAppRatingEventSystemDataSource: AppRatingEventSystemDataSource {
    var popupDismissCount: Int {
        get { Settings.shared.appRatingPopupDismissCount }
        set { Settings.shared.appRatingPopupDismissCount = newValue }
    }
    
    var isPopupAnswered: Bool {
        Settings.shared.isAppRatingPopupAnswered
    }
}
