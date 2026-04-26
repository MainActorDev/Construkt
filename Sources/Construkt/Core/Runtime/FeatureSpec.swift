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

// MARK: - ReduceResult Composition

extension ReduceResult {
    /// Transforms effects and outputs into different types.
    /// Used to embed a child feature's reduce result into a parent.
    ///
    /// ```swift
    /// let childResult = ChildFeature.reduce(state: &state.child, intent: childIntent)
    /// return childResult.map(
    ///     effect: { ParentEffect.child($0) },
    ///     output: { ParentOutput.child($0) }
    /// )
    /// ```
    public func map<NewEffect: Sendable, NewOutput: Sendable>(
        effect: (Effect) -> NewEffect,
        output: (Output) -> NewOutput
    ) -> ReduceResult<NewEffect, NewOutput> {
        ReduceResult<NewEffect, NewOutput>(
            effects: effects.map(effect),
            outputs: outputs.map(output)
        )
    }

    /// Maps only the effects, preserving output type.
    ///
    /// ```swift
    /// childResult.mapEffects { ParentEffect.child($0) }
    /// ```
    public func mapEffects<NewEffect: Sendable>(
        _ transform: (Effect) -> NewEffect
    ) -> ReduceResult<NewEffect, Output> {
        ReduceResult<NewEffect, Output>(
            effects: effects.map(transform),
            outputs: outputs
        )
    }

    /// Maps only the outputs, preserving effect type.
    ///
    /// ```swift
    /// childResult.mapOutputs { ParentOutput.child($0) }
    /// ```
    public func mapOutputs<NewOutput: Sendable>(
        _ transform: (Output) -> NewOutput
    ) -> ReduceResult<Effect, NewOutput> {
        ReduceResult<Effect, NewOutput>(
            effects: effects,
            outputs: outputs.map(transform)
        )
    }

    /// Merges effects and outputs from another result into this one.
    ///
    /// ```swift
    /// let childResult = ChildFeature.reduce(state: &state.child, intent: childIntent)
    ///     .map(effect: { .child($0) }, output: { .child($0) })
    /// let parentExtra = ReduceResult<Effect, Output>(effects: [.trackEvent])
    /// return childResult.merged(with: parentExtra)
    /// ```
    public func merged(with other: ReduceResult<Effect, Output>) -> ReduceResult<Effect, Output> {
        ReduceResult(
            effects: effects + other.effects,
            outputs: outputs + other.outputs
        )
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

// MARK: - EffectFeedback Composition

extension EffectFeedback {
    /// Transforms intents and outputs into different types.
    /// Used to embed a child feature's effect feedback into a parent.
    ///
    /// ```swift
    /// let childFeedback = try await childExecutor(childEffect, deps.childDeps)
    /// return childFeedback.map(
    ///     intent: { ParentIntent.child($0) },
    ///     output: { ParentOutput.child($0) }
    /// )
    /// ```
    public func map<NewIntent: Sendable, NewOutput: Sendable>(
        intent: (Intent) -> NewIntent,
        output: (Output) -> NewOutput
    ) -> EffectFeedback<NewIntent, NewOutput> {
        EffectFeedback<NewIntent, NewOutput>(
            intents: intents.map(intent),
            outputs: outputs.map(output)
        )
    }

    /// Maps only the intents, preserving output type.
    ///
    /// ```swift
    /// childFeedback.mapIntents { ParentIntent.child($0) }
    /// ```
    public func mapIntents<NewIntent: Sendable>(
        _ transform: (Intent) -> NewIntent
    ) -> EffectFeedback<NewIntent, Output> {
        EffectFeedback<NewIntent, Output>(
            intents: intents.map(transform),
            outputs: outputs
        )
    }

    /// Maps only the outputs, preserving intent type.
    ///
    /// ```swift
    /// childFeedback.mapOutputs { ParentOutput.child($0) }
    /// ```
    public func mapOutputs<NewOutput: Sendable>(
        _ transform: (Output) -> NewOutput
    ) -> EffectFeedback<Intent, NewOutput> {
        EffectFeedback<Intent, NewOutput>(
            intents: intents,
            outputs: outputs.map(transform)
        )
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
