public enum ErrorClass: Sendable, Equatable, Codable {
    case rateLimited(retryAfterSeconds: Int? = nil)
    case botCheck
    case sabrGated
    case formatsMissing
    case cookieReadFailed
    case geoBlocked
    case `private`
    case unavailable
    case ageRestricted
    case networkDown
    case diskFull
    case permissionDenied
    case incomplete
    case depMissing
    case potProviderDown
    case passcodeRequired
    case passcodeRejected
    case unknown(raw: String)

    private enum CodingKeys: String, CodingKey {
        case kind, value
    }

    private static let decodeMap: [String: @Sendable (KeyedDecodingContainer<CodingKeys>) throws -> Self] = [
        "rateLimited": { @Sendable in
            try .rateLimited(retryAfterSeconds: $0.decodeIfPresent(Int.self, forKey: .value))
        },
        "botCheck": { @Sendable _ in .botCheck },
        "sabrGated": { @Sendable _ in .sabrGated },
        "formatsMissing": { @Sendable _ in .formatsMissing },
        "cookieReadFailed": { @Sendable _ in .cookieReadFailed },
        "geoBlocked": { @Sendable _ in .geoBlocked },
        "private": { @Sendable _ in .private },
        "unavailable": { @Sendable _ in .unavailable },
        "ageRestricted": { @Sendable _ in .ageRestricted },
        "networkDown": { @Sendable _ in .networkDown },
        "diskFull": { @Sendable _ in .diskFull },
        "permissionDenied": { @Sendable _ in .permissionDenied },
        "incomplete": { @Sendable _ in .incomplete },
        "depMissing": { @Sendable _ in .depMissing },
        "potProviderDown": { @Sendable _ in .potProviderDown },
        "passcodeRequired": { @Sendable _ in .passcodeRequired },
        "passcodeRejected": { @Sendable _ in .passcodeRejected },
        "unknown": { @Sendable in try .unknown(raw: $0.decode(String.self, forKey: .value)) }
    ]

    private var encodeKind: String {
        switch self {
        case .rateLimited: "rateLimited"
        case .botCheck: "botCheck"
        case .sabrGated: "sabrGated"
        case .formatsMissing: "formatsMissing"
        case .cookieReadFailed: "cookieReadFailed"
        case .geoBlocked: "geoBlocked"
        case .private: "private"
        case .unavailable: "unavailable"
        case .ageRestricted: "ageRestricted"
        case .networkDown: "networkDown"
        case .diskFull: "diskFull"
        case .permissionDenied: "permissionDenied"
        case .incomplete: "incomplete"
        case .depMissing: "depMissing"
        case .potProviderDown: "potProviderDown"
        case .passcodeRequired: "passcodeRequired"
        case .passcodeRejected: "passcodeRejected"
        case .unknown: "unknown"
        }
    }

    private var encodeValue: String? {
        switch self {
        case let .rateLimited(seconds): seconds.map(String.init)
        case let .unknown(raw): raw
        default: nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        guard let factory = Self.decodeMap[kind] else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container, debugDescription: "unknown"
            )
        }
        self = try factory(container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(encodeKind, forKey: .kind)
        if let value = encodeValue {
            try container.encode(value, forKey: .value)
        }
    }
}
