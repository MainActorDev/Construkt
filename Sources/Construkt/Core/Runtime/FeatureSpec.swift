import Foundation

/// Executes an effect and returns feedback that can emit follow-up intents and outputs.
///
/// - Parameters:
///   - effect: The effect scheduled by `FeatureSpec.reduce`.
///   - dependencies: The concrete dependency bag for the feature.
/// - Returns: Feedback that is routed back into the runtime loop.
public typealias FeatureEffectExecutor<F: FeatureSpec> = @Sendable (
    _ effect: F.Effect,
    _ dependencies: F.Dependencies
) async throws -> EffectFeedback<F.Intent, F.Output>

/// Declarative contract for runtime-managed state machines.
///
/// A `FeatureSpec` defines:
/// - the state model,
/// - incoming intents,
/// - asynchronous effects,
/// - one-off outputs,
/// - and dependencies required by effect execution.
///
/// The runtime enforces serialized reducer execution while allowing effect concurrency
/// according to `EffectPolicy`.
public protocol FeatureSpec: Sendable {
    /// Long-lived, equatable feature state.
    associatedtype State: Sendable & Equatable

    /// Intent/event type processed by the reducer.
    associatedtype Intent: Sendable

    /// Asynchronous work descriptor produced by the reducer.
    associatedtype Effect: Sendable & Hashable

    /// One-off output stream type (navigation, toasts, external events).
    associatedtype Output: Sendable

    /// Dependency bag passed into `FeatureEffectExecutor`.
    associatedtype Dependencies: Sendable

    /// Starting state used when the runtime is created.
    static var initialState: State { get }

    /// Pure reducer step that updates state and schedules effects/outputs.
    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output>

    /// Scheduling policy for each effect instance.
    static func policy(for effect: Effect) -> EffectPolicy

    /// Defines whether feedback for an old epoch should still be accepted.
    static func staleStrategy(for effect: Effect) -> StaleEffectStrategy

    /// Optional error-to-intent mapper for reducer-driven recovery.
    static func mapEffectError(_ error: any Error, effect: Effect) -> Intent?
}

public extension FeatureSpec {
    /// Default stale handling drops feedback when state has moved to a newer epoch.
    static func staleStrategy(for effect: Effect) -> StaleEffectStrategy {
        .drop
    }

    /// Default behavior ignores effect errors at the runtime level.
    static func mapEffectError(_ error: any Error, effect: Effect) -> Intent? {
        nil
    }
}

/// Result of a reducer pass.
///
/// - `effects`: async work to schedule in runtime.
/// - `outputs`: one-off events to publish to `FeatureStore.outputs`.
public struct ReduceResult<Effect: Sendable, Output: Sendable>: Sendable {
    public var effects: [Effect]
    public var outputs: [Output]

    public init(effects: [Effect] = [], outputs: [Output] = []) {
        self.effects = effects
        self.outputs = outputs
    }

    /// Convenience for reducers that only mutate state.
    public static var none: ReduceResult<Effect, Output> {
        .init()
    }
}

/// Result returned by effect execution.
///
/// - `intents`: fed back into the runtime reducer loop.
/// - `outputs`: published directly as one-off events.
public struct EffectFeedback<Intent: Sendable, Output: Sendable>: Sendable {
    public var intents: [Intent]
    public var outputs: [Output]

    public init(intents: [Intent] = [], outputs: [Output] = []) {
        self.intents = intents
        self.outputs = outputs
    }

    /// Convenience for effects with no feedback.
    public static var none: EffectFeedback<Intent, Output> {
        .init()
    }
}

/// Runtime tuning knobs.
public struct RuntimeConfiguration: Sendable {
    /// Max journal entries retained in-memory.
    public var journalCapacity: Int

    /// Whether newly attached state streams immediately receive current state.
    public var emitsInitialStateOnSubscription: Bool

    public init(journalCapacity: Int = 300, emitsInitialStateOnSubscription: Bool = true) {
        self.journalCapacity = max(1, journalCapacity)
        self.emitsInitialStateOnSubscription = emitsInitialStateOnSubscription
    }
}
