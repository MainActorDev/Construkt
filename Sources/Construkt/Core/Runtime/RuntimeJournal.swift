import Foundation

/// Reasons a scheduled/running effect can be dropped by policy/runtime checks.
public enum PolicyDropReason: String, Sendable {
    /// `.dropIfRunning` rejected new submission because same-key effect is active.
    case alreadyRunning

    /// Feedback was considered stale because origin epoch differs from current epoch.
    case staleEpoch

    /// `.latest` accepted a newer generation and superseded this effect's feedback.
    case supersededByLatest
}

/// Runtime trace event for diagnostics and deterministic test assertions.
public enum RuntimeJournalEvent<Intent: Sendable, Effect: Sendable>: Sendable {
    case intentReceived(Intent)
    case stateCommitted(epoch: UInt64)
    case outputPublished(count: Int)
    case effectScheduled(Effect, policy: EffectPolicy, epoch: UInt64)
    case effectStarted(Effect, epoch: UInt64)
    case effectCompleted(Effect, epoch: UInt64)
    case effectCancelled(Effect)
    case effectDropped(Effect, reason: PolicyDropReason)
    case effectFailed(Effect, message: String)
}

/// Timestamped journal entry.
public struct RuntimeJournalEntry<Intent: Sendable, Effect: Sendable>: Sendable {
    public let timestamp: Date
    public let event: RuntimeJournalEvent<Intent, Effect>

    public init(timestamp: Date = Date(), event: RuntimeJournalEvent<Intent, Effect>) {
        self.timestamp = timestamp
        self.event = event
    }
}

/// Bounded in-memory event log for runtime internals.
/// Uses a circular buffer for O(1) append and eviction.
public struct RuntimeJournal<Intent: Sendable, Effect: Sendable>: Sendable {
    private let capacity: Int
    private var buffer: [RuntimeJournalEntry<Intent, Effect>?]
    private var head: Int = 0
    private var count: Int = 0

    public init(capacity: Int = 300) {
        let cap = max(1, capacity)
        self.capacity = cap
        self.buffer = Array(repeating: nil, count: cap)
    }

    /// Appends an event. O(1) — overwrites oldest entry when at capacity.
    public mutating func append(_ event: RuntimeJournalEvent<Intent, Effect>) {
        let index = (head + count) % capacity
        buffer[index] = .init(event: event)

        if count == capacity {
            head = (head + 1) % capacity
        } else {
            count += 1
        }
    }

    /// Returns entries in chronological order.
    public func snapshot() -> [RuntimeJournalEntry<Intent, Effect>] {
        var result: [RuntimeJournalEntry<Intent, Effect>] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let index = (head + i) % capacity
            if let entry = buffer[index] {
                result.append(entry)
            }
        }
        return result
    }
}
