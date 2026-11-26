@testable import GrabberKit
import TestSupport
import XCTest

final class ShieldProbeTests: XCTestCase {
    func testShieldReplyValidation() {
        let ok = Data("{\"server_uptime\": 1.5, \"version\": \"2.0.2\"}".utf8)
        XCTAssertTrue(isOwnReply(200, ok))
        XCTAssertFalse(isOwnReply(404, ok))
        XCTAssertFalse(isOwnReply(200, Data("not json".utf8)))
        XCTAssertFalse(isOwnReply(200, Data("{\"server_uptime\": 1}".utf8)))
        XCTAssertFalse(isOwnReply(200, Data("{\"version\": \"2.0.2\"}".utf8)))
    }

    func testReplyFromAServerOlderThanTheChildIsRejected() {
        let older = Data("{\"server_uptime\": 3600, \"version\": \"2.0.2\"}".utf8)
        XCTAssertFalse(isOwnReply(200, older))
    }

    func testPortCheckSeesALoopbackListener() throws {
        let listener = try TestListener(address: "127.0.0.1")
        XCTAssertFalse(LoopbackPortChecker().isFree(listener.port))
    }

    func testPortCheckSeesAnAllInterfacesListener() throws {
        let listener = try TestListener(address: "0.0.0.0")
        XCTAssertFalse(LoopbackPortChecker().isFree(listener.port))
    }

    func testPortCheckReportsAClosedPortFree() throws {
        let port = try TestListener(address: "127.0.0.1").port
        XCTAssertTrue(LoopbackPortChecker().isFree(port))
    }

    private func isOwnReply(_ status: Int, _ body: Data) -> Bool {
        URLSessionShieldPinger.isOwnChildReply(statusCode: status, body: body, maxUptime: 5)
    }
}

private final class TestListener {
    let port: Int
    private let descriptor: Int32

    init(address host: String) throws {
        descriptor = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr(host)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let descriptor = descriptor
        let ready = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { raw in
                bind(descriptor, raw, length) == 0 && listen(descriptor, 1) == 0
                    && getsockname(descriptor, raw, &length) == 0
            }
        }
        guard ready else { throw POSIXError(.EADDRNOTAVAIL) }
        port = Int(in_port_t(bigEndian: address.sin_port))
    }

    deinit {
        close(descriptor)
    }
}
