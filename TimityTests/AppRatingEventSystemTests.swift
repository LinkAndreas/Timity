import XCTest
@testable import Timity

final class AppRatingEventSystemTests: XCTestCase {
    func test_init_doesNotTriggerPopup() {
        let config = anyAppRatingEventSystemConfig()
        let (spy, _) = makeSUT(config: config)
        
        XCTAssertEqual(spy.receivedMessages, [])
    }
    
    func test_send_handlesEvent() {
        let config = anyAppRatingEventSystemConfig(
            eventAddedThreshold: 1,
            usedCalculatorThreshold: 3,
            silenceReminderThreshold: 3
        )
        let (spy, sut) = makeSUT(config: config)
        
        XCTAssertEqual(spy.receivedMessages, [])
        
        sut.send(event: .eventAdded)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])
        
        sut.send(event: .usedEventCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])
        
        sut.send(event: .usedDurationCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])

        sut.send(event: .usedTimeCalculator)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger])
        
        sut.send(event: .eventAdded)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])
        
        sut.send(event: .usedTimeCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])

        sut.send(event: .usedTimeCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])

        sut.send(event: .usedTimeCalculator)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])
    }
}

extension AppRatingEventSystemTests {
    private final class Spy {
        enum Message: Equatable {
            case popupTrigger
        }
    
        private(set) var receivedMessages: [Message] = []

        func didReceivePopupTrigger() {
            receivedMessages.append(.popupTrigger)
        }
    }
    
    private final class TriggerCounterDataSource: AppRatingTriggerCounterDataSource {
        var counter: Int = 0
    }

    private func makeSUT(
        config: AppRatingEventSystemConfig
    ) -> (Spy, AppRatingEventSystem) {
        let spy = Spy()
        let triggerCounterDataSource = TriggerCounterDataSource()
        let sut = AppRatingEventSystem(
            config: config,
            triggerCounterDataSource: triggerCounterDataSource,
            onPopupTriggerReceived: spy.didReceivePopupTrigger
        )
        return (spy, sut)
    }
    
    private func anyAppRatingEventSystemConfig(
        eventAddedThreshold: Int = 0,
        usedCalculatorThreshold: Int = 0,
        silenceReminderThreshold: Int = 0
    ) -> AppRatingEventSystemConfig {
        AppRatingEventSystemConfig(
            eventAddedThreshold: eventAddedThreshold,
            usedCalculatorThreshold: usedCalculatorThreshold,
            silenceReminderThreshold: silenceReminderThreshold
        )
    }
}
