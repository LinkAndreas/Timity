import Foundation

final class AppRatingEventSystem {
    private var eventAddedEventCounter: Int = 0
    private var usedCalculatorEventCounter: Int = 0

    private let config: AppRatingEventSystemConfig
    private var triggerCounterDataSource: AppRatingTriggerCounterDataSource
    private let onPopupTriggerReceived: () -> Void

    init(
        config: AppRatingEventSystemConfig,
        triggerCounterDataSource: AppRatingTriggerCounterDataSource,
        onPopupTriggerReceived: @escaping () -> Void
    ) {
        self.config = config
        self.triggerCounterDataSource = triggerCounterDataSource
        self.onPopupTriggerReceived = onPopupTriggerReceived
    }
    
    func send(event: AppRatingEvent) {
        guard triggerCounterDataSource.counter < config.silenceReminderThreshold else { return }

        switch event {
        case .eventAdded:
            eventAddedEventCounter += 1
        case .usedEventCalculator:
            usedCalculatorEventCounter += 1
        case .usedDurationCalculator:
            usedCalculatorEventCounter += 1
        case .usedTimeCalculator:
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
        incrementTriggerCounter()
        onPopupTriggerReceived()
        resetEventCounters()
    }
    
    private func incrementTriggerCounter() {
        triggerCounterDataSource.counter += 1
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
