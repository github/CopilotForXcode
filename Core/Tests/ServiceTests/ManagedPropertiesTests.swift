import XCTest
@testable import CommunicationBridge

class ManagedPropertiesTests: XCTestCase {

    func testCheckForManagedProperties() {
        let result = checkForManagedProperties()
        XCTAssertFalse(result, "Managed properties should not be detected in this test environment.")
    }

    func testListenerShouldAcceptNewConnection() {
        let serviceDelegate = ServiceDelegate()
        let listener = NSXPCListener(machServiceName: "com.example.service")
        let connection = NSXPCConnection(machServiceName: "com.example.service", options: [])

        let shouldAccept = serviceDelegate.listener(listener, shouldAcceptNewConnection: connection)
        XCTAssertTrue(shouldAccept, "Connection should be accepted in this test environment.")
    }
}
