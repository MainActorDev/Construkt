import Foundation

/// Stable key used by keyed effect policies (`latest`, `queue`, etc).
///
/// Keys define effect coordination groups. Two effects with the same key share
/// a policy lane.
public struct EffectKey: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}

/// Stale feedback strategy for completed effects.
public enum StaleEffectStrategy: Sendable, Equatable {
    /// Drop feedback when runtime epoch no longer matches the effect's origin epoch.
    case drop

    /// Accept feedback regardless of epoch drift.
    case accept
}

/// Scheduling strategy for asynchronous effects.
public enum EffectPolicy: Sendable, Equatable {
    /// Launch every effect immediately with no coordination.
    case concurrent

    /// Keep all starts, but only accept feedback from the latest generation for key.
    case latest(EffectKey)

    /// Serialize effects by key; each starts after the previous completes.
    case queue(EffectKey)

    /// Ignore new effect submissions while one is already running for key.
    case dropIfRunning(EffectKey)

    /// Cancel running effect and immediately replace it with the new one.
    case restartable(EffectKey)

    /// Delay starts by interval and coalesce bursts to latest submission.
    case debounce(EffectKey, TimeInterval)

    /// Associated key when policy is keyed; `nil` for `.concurrent`.
    public var key: EffectKey? {
        switch self {
        case .concurrent:
            return nil
        case .latest(let key), .queue(let key), .dropIfRunning(let key), .restartable(let key), .debounce(let key, _):
            return key
        }
    }
}
