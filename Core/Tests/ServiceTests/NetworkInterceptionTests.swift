import XCTest
@testable import Service

class NetworkInterceptionTests: XCTestCase {

    func testNetworkInterceptionDetected() {
        let service = Service.shared
        let result = service.checkForNetworkInterception()
        XCTAssertTrue(result, "Network interception should be detected.")
    }

    func testNetworkInterceptionNotDetected() {
        let service = Service.shared
        let result = service.checkForNetworkInterception()
        XCTAssertFalse(result, "Network interception should not be detected.")
    }
}
