import XCTest
@testable import Timity

final class AppRatingEventSystem {
    private let onPopupTriggerReceived: () -> Void

    init(onPopupTriggerReceived: @escaping () -> Void) {
        self.onPopupTriggerReceived = onPopupTriggerReceived
    }
}

final class AppRatingEventSystemTests: XCTestCase {
    func test_init_doesNotTriggerPopup() {
        let (spy, _) = makeSUT()
        
        XCTAssertEqual(spy.receivedMessages, [])
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

    private func makeSUT() -> (Spy, AppRatingEventSystem) {
        let spy = Spy()
        let sut = AppRatingEventSystem(
            onPopupTriggerReceived: spy.didReceivePopupTrigger
        )
        return (spy, sut)
    }
}
