import Foundation

public protocol ShieldPinging: Sendable {
    func ping(_ url: URL, timeout: TimeInterval, maxUptime: TimeInterval) async -> Bool
}

protocol LoopbackPortChecking: Sendable {
    func isFree(_ port: Int) -> Bool
}

struct AlwaysFreePortChecker: LoopbackPortChecking {
    func isFree(_: Int) -> Bool {
        true
    }
}

// A port is free only when nothing is listening on it, so the app can bind it for its own child.
struct LoopbackPortChecker: LoopbackPortChecking {
    // Both are tried: BSD lets a loopback bind succeed beside an all-interfaces listener, and the reverse.
    func isFree(_ port: Int) -> Bool {
        canBind("127.0.0.1", port: port) && canBind("0.0.0.0", port: port)
    }

    private func canBind(_ host: String, port: Int) -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr.s_addr = inet_addr(host)
        // A restart must be able to reuse its own port while it is still in TIME_WAIT.
        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { raw in
                bind(descriptor, raw, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return bound == 0
    }
}

struct URLSessionShieldPinger: ShieldPinging {
    func ping(_ url: URL, timeout: TimeInterval, maxUptime: TimeInterval) async -> Bool {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            return false
        }
        guard let http = response as? HTTPURLResponse else {
            return false
        }
        return Self.isOwnChildReply(statusCode: http.statusCode, body: data, maxUptime: maxUptime)
    }

    // A server that has been up longer than our child has lived belongs to someone else.
    static func isOwnChildReply(statusCode: Int, body: Data, maxUptime: TimeInterval) -> Bool {
        guard (200 ..< 300).contains(statusCode),
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              object["version"] is String,
              let uptime = object["server_uptime"] as? Double
        else { return false }
        return uptime <= maxUptime
    }
}
