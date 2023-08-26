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
            maxDismissCount: 3
        )
        let (spy, sut) = makeSUT(config: config)
        
        XCTAssertEqual(spy.receivedMessages, [])
        
        sut.send(event: .eventAdded)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])
        
        sut.send(event: .eventAdded)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])
        
        spy.notifyTriggerHandled(atIndex: 0)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])
        
        sut.send(event: .usedCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])

        sut.send(event: .usedCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger])
        
        sut.send(event: .usedCalculator)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger])
        
        spy.notifyTriggerHandled(atIndex: 1)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger])

        sut.send(event: .eventAdded)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])
        
        spy.notifyTriggerHandled(atIndex: 2)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])

        sut.send(event: .usedCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])

        sut.send(event: .usedCalculator)
        
        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])

        sut.send(event: .usedCalculator)

        XCTAssertEqual(spy.receivedMessages, [.popupTrigger, .popupTrigger, .popupTrigger])
    }
}

extension AppRatingEventSystemTests {
    private final class Spy {
        enum Message: Equatable {
            case popupTrigger
        }
    
        private(set) var receivedMessages: [Message] = []
        private var notifyTriggerHandlers: [() -> Void] = []

        func didReceivePopupTrigger(notifyTriggerHandled: @escaping () -> Void) {
            receivedMessages.append(.popupTrigger)
            notifyTriggerHandlers.append(notifyTriggerHandled)
        }
        
        func notifyTriggerHandled(atIndex index: Int = 0) {
            notifyTriggerHandlers[index]()
        }
    }
    
    private final class DataSource: AppRatingEventSystemDataSource {
        var isPopupAnswered: Bool = false
        var popupDismissCount: Int = 0
    }

    private func makeSUT(
        config: AppRatingEventSystemConfig
    ) -> (Spy, AppRatingEventSystem) {
        let spy = Spy()
        let dataSource = DataSource()
        let sut = AppRatingEventSystem(
            config: config,
            dataSource: dataSource,
            onPopupTriggerReceived: { notifyTriggerHandled in
                dataSource.popupDismissCount += 1
                spy.didReceivePopupTrigger(notifyTriggerHandled: notifyTriggerHandled)
            }
        )
        return (spy, sut)
    }
    
    private func anyAppRatingEventSystemConfig(
        eventAddedThreshold: Int = 0,
        usedCalculatorThreshold: Int = 0,
        maxDismissCount: Int = 0
    ) -> AppRatingEventSystemConfig {
        AppRatingEventSystemConfig(
            eventAddedThreshold: eventAddedThreshold,
            usedCalculatorThreshold: usedCalculatorThreshold,
            maxDismissCount: maxDismissCount
        )
    }
}
