import Foundation
import Testing
@testable import ConstruktKit

@Suite("Feature Composition")
struct FeatureCompositionTests {

    // MARK: - ReduceResult.map(effect:output:)

    @Test("map transforms effects and outputs simultaneously")
    func mapTransformsBoth() {
        let result = ReduceResult<Int, String>(effects: [1, 2, 3], outputs: ["a", "b"])

        let mapped: ReduceResult<String, Int> = result.map(
            effect: { "effect-\($0)" },
            output: { $0.count }
        )

        #expect(mapped.effects == ["effect-1", "effect-2", "effect-3"])
        #expect(mapped.outputs == [1, 1])
    }

    @Test("map preserves empty arrays")
    func mapPreservesEmptyArrays() {
        let result = ReduceResult<Int, String>(effects: [], outputs: [])

        let mapped: ReduceResult<String, Int> = result.map(
            effect: { "effect-\($0)" },
            output: { $0.count }
        )

        #expect(mapped.effects.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    @Test("map works with .none result")
    func mapWorksWithNone() {
        let result: ReduceResult<Int, String> = .none

        let mapped: ReduceResult<String, Int> = result.map(
            effect: { "effect-\($0)" },
            output: { $0.count }
        )

        #expect(mapped.effects.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    @Test("map transforms effects only when outputs are empty")
    func mapEffectsOnlyWhenOutputsEmpty() {
        let result = ReduceResult<Int, String>(effects: [10, 20])

        let mapped: ReduceResult<String, String> = result.map(
            effect: { "\($0)x" },
            output: { $0 }
        )

        #expect(mapped.effects == ["10x", "20x"])
        #expect(mapped.outputs.isEmpty)
    }

    @Test("map transforms outputs only when effects are empty")
    func mapOutputsOnlyWhenEffectsEmpty() {
        let result = ReduceResult<Int, String>(outputs: ["hello", "world"])

        let mapped: ReduceResult<Int, Int> = result.map(
            effect: { $0 },
            output: { $0.count }
        )

        #expect(mapped.effects.isEmpty)
        #expect(mapped.outputs == [5, 5])
    }

    // MARK: - ReduceResult.mapEffects(_:)

    @Test("mapEffects transforms effects, preserves output type")
    func mapEffectsPreservesOutputs() {
        let result = ReduceResult<Int, String>(effects: [1, 2], outputs: ["a"])

        let mapped: ReduceResult<String, String> = result.mapEffects { "e-\($0)" }

        #expect(mapped.effects == ["e-1", "e-2"])
        #expect(mapped.outputs == ["a"])
    }

    @Test("mapEffects on .none returns .none equivalent")
    func mapEffectsOnNone() {
        let result: ReduceResult<Int, String> = .none

        let mapped: ReduceResult<String, String> = result.mapEffects { "e-\($0)" }

        #expect(mapped.effects.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    // MARK: - ReduceResult.mapOutputs(_:)

    @Test("mapOutputs transforms outputs, preserves effect type")
    func mapOutputsPreservesEffects() {
        let result = ReduceResult<Int, String>(effects: [1], outputs: ["hello", "world"])

        let mapped: ReduceResult<Int, Int> = result.mapOutputs { $0.count }

        #expect(mapped.effects == [1])
        #expect(mapped.outputs == [5, 5])
    }

    @Test("mapOutputs on .none returns .none equivalent")
    func mapOutputsOnNone() {
        let result: ReduceResult<Int, String> = .none

        let mapped: ReduceResult<Int, Int> = result.mapOutputs { $0.count }

        #expect(mapped.effects.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    // MARK: - ReduceResult.merged(with:)

    @Test("merged combines effects and outputs from both results")
    func mergedCombinesBoth() {
        let a = ReduceResult<Int, String>(effects: [1, 2], outputs: ["a"])
        let b = ReduceResult<Int, String>(effects: [3], outputs: ["b", "c"])

        let merged = a.merged(with: b)

        #expect(merged.effects == [1, 2, 3])
        #expect(merged.outputs == ["a", "b", "c"])
    }

    @Test("merging with .none returns original")
    func mergedWithNoneReturnsOriginal() {
        let a = ReduceResult<Int, String>(effects: [1], outputs: ["a"])

        let merged = a.merged(with: .none)

        #expect(merged.effects == [1])
        #expect(merged.outputs == ["a"])
    }

    @Test("merging .none with result returns result")
    func mergedNoneWithResultReturnsResult() {
        let b = ReduceResult<Int, String>(effects: [2], outputs: ["b"])

        let merged = ReduceResult<Int, String>.none.merged(with: b)

        #expect(merged.effects == [2])
        #expect(merged.outputs == ["b"])
    }

    @Test("merging two .none results returns .none equivalent")
    func mergedTwoNonesReturnsNone() {
        let merged = ReduceResult<Int, String>.none.merged(with: .none)

        #expect(merged.effects.isEmpty)
        #expect(merged.outputs.isEmpty)
    }

    // MARK: - EffectFeedback.map(intent:output:)

    @Test("EffectFeedback map transforms intents and outputs simultaneously")
    func feedbackMapTransformsBoth() {
        let feedback = EffectFeedback<Int, String>(intents: [1, 2, 3], outputs: ["a", "b"])

        let mapped: EffectFeedback<String, Int> = feedback.map(
            intent: { "intent-\($0)" },
            output: { $0.count }
        )

        #expect(mapped.intents == ["intent-1", "intent-2", "intent-3"])
        #expect(mapped.outputs == [1, 1])
    }

    @Test("EffectFeedback map preserves empty arrays")
    func feedbackMapPreservesEmptyArrays() {
        let feedback = EffectFeedback<Int, String>(intents: [], outputs: [])

        let mapped: EffectFeedback<String, Int> = feedback.map(
            intent: { "intent-\($0)" },
            output: { $0.count }
        )

        #expect(mapped.intents.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    @Test("EffectFeedback map works with .none feedback")
    func feedbackMapWorksWithNone() {
        let feedback: EffectFeedback<Int, String> = .none

        let mapped: EffectFeedback<String, Int> = feedback.map(
            intent: { "intent-\($0)" },
            output: { $0.count }
        )

        #expect(mapped.intents.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    @Test("EffectFeedback map transforms intents only when outputs are empty")
    func feedbackMapIntentsOnlyWhenOutputsEmpty() {
        let feedback = EffectFeedback<Int, String>(intents: [10, 20])

        let mapped: EffectFeedback<String, String> = feedback.map(
            intent: { "\($0)x" },
            output: { $0 }
        )

        #expect(mapped.intents == ["10x", "20x"])
        #expect(mapped.outputs.isEmpty)
    }

    @Test("EffectFeedback map transforms outputs only when intents are empty")
    func feedbackMapOutputsOnlyWhenIntentsEmpty() {
        let feedback = EffectFeedback<Int, String>(outputs: ["hello", "world"])

        let mapped: EffectFeedback<Int, Int> = feedback.map(
            intent: { $0 },
            output: { $0.count }
        )

        #expect(mapped.intents.isEmpty)
        #expect(mapped.outputs == [5, 5])
    }

    // MARK: - EffectFeedback.mapIntents(_:)

    @Test("EffectFeedback mapIntents transforms intents, preserves output type")
    func feedbackMapIntentsPreservesOutputs() {
        let feedback = EffectFeedback<Int, String>(intents: [1, 2], outputs: ["a"])

        let mapped: EffectFeedback<String, String> = feedback.mapIntents { "i-\($0)" }

        #expect(mapped.intents == ["i-1", "i-2"])
        #expect(mapped.outputs == ["a"])
    }

    @Test("EffectFeedback mapIntents on .none returns .none equivalent")
    func feedbackMapIntentsOnNone() {
        let feedback: EffectFeedback<Int, String> = .none

        let mapped: EffectFeedback<String, String> = feedback.mapIntents { "i-\($0)" }

        #expect(mapped.intents.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }

    // MARK: - EffectFeedback.mapOutputs(_:)

    @Test("EffectFeedback mapOutputs transforms outputs, preserves intent type")
    func feedbackMapOutputsPreservesIntents() {
        let feedback = EffectFeedback<Int, String>(intents: [1], outputs: ["hello", "world"])

        let mapped: EffectFeedback<Int, Int> = feedback.mapOutputs { $0.count }

        #expect(mapped.intents == [1])
        #expect(mapped.outputs == [5, 5])
    }

    @Test("EffectFeedback mapOutputs on .none returns .none equivalent")
    func feedbackMapOutputsOnNone() {
        let feedback: EffectFeedback<Int, String> = .none

        let mapped: EffectFeedback<Int, Int> = feedback.mapOutputs { $0.count }

        #expect(mapped.intents.isEmpty)
        #expect(mapped.outputs.isEmpty)
    }
}

// MARK: - Integration Test Fixtures

private enum ChildFeature: FeatureSpec {
    struct State: Sendable, Equatable {
        var value: String = ""
        var isLoading: Bool = false
    }
    enum Intent: Sendable {
        case load
        case loaded(String)
    }
    enum Effect: Sendable, Hashable {
        case fetch
    }
    enum Output: Sendable {
        case didComplete
    }
    struct Dependencies: Sendable {}

    static var initialState: State { State() }

    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .load:
            state.isLoading = true
            return ReduceResult(effects: [.fetch])
        case .loaded(let value):
            state.value = value
            state.isLoading = false
            return ReduceResult(outputs: [.didComplete])
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        .latest("child-fetch")
    }
}

private enum ParentFeature: FeatureSpec {
    struct State: Sendable, Equatable {
        var child: ChildFeature.State = ChildFeature.initialState
        var completionCount: Int = 0
    }
    enum Intent: Sendable {
        case child(ChildFeature.Intent)
        case childCompleted
    }
    enum Effect: Sendable, Hashable {
        case child(ChildFeature.Effect)
    }
    enum Output: Sendable {
        case childDidComplete
    }
    struct Dependencies: Sendable {}

    static var initialState: State { State() }

    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .child(let childIntent):
            let childResult = ChildFeature.reduce(state: &state.child, intent: childIntent)
            let result = childResult.map(
                effect: { Effect.child($0) },
                output: { _ in Output.childDidComplete }
            )

            // Parent observes child intent and reacts
            if case .loaded = childIntent {
                state.completionCount += 1
            }

            return result

        case .childCompleted:
            state.completionCount += 1
            return .none
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .child(let childEffect):
            return ChildFeature.policy(for: childEffect)
        }
    }
}

private actor OutputCollector {
    var values: [ParentFeature.Output] = []

    func append(_ output: ParentFeature.Output) {
        values.append(output)
    }
}

// MARK: - Integration Tests

@Suite("Feature Composition Integration", .serialized)
struct FeatureCompositionIntegrationTests {

    @Test("Full round-trip: child intent → child reduce → child effect → feedback → parent state")
    func fullRoundTrip() async throws {
        let childExecutor: FeatureEffectExecutor<ChildFeature> = { effect, _ in
            switch effect {
            case .fetch:
                return EffectFeedback(intents: [.loaded("test-value")])
            }
        }

        let parentExecutor: FeatureEffectExecutor<ParentFeature> = { effect, _ in
            switch effect {
            case .child(let childEffect):
                let childFeedback = try await childExecutor(childEffect, ChildFeature.Dependencies())
                return childFeedback.map(
                    intent: { .child($0) },
                    output: { _ in ParentFeature.Output.childDidComplete }
                )
            }
        }

        let runtime = FeatureRuntime<ParentFeature>(
            dependencies: ParentFeature.Dependencies(),
            effectExecutor: parentExecutor
        )

        // Dispatch child intent through parent
        await runtime.send(.child(.load))

        // Wait for effect to complete
        await runtime.waitUntilIdle()

        let state = await runtime.currentState()

        // Child state was updated by child reducer
        #expect(state.child.value == "test-value")
        #expect(state.child.isLoading == false)

        // Parent observed the child .loaded intent and incremented
        #expect(state.completionCount == 1)
    }

    @Test("Child reduce result maps effects correctly through parent")
    func childEffectsMappedThroughParent() async throws {
        let parentExecutor: FeatureEffectExecutor<ParentFeature> = { effect, _ in
            switch effect {
            case .child(let childEffect):
                switch childEffect {
                case .fetch:
                    return EffectFeedback(intents: [.child(.loaded("done"))])
                }
            }
        }

        let runtime = FeatureRuntime<ParentFeature>(
            dependencies: ParentFeature.Dependencies(),
            effectExecutor: parentExecutor
        )

        await runtime.send(.child(.load))
        await runtime.waitUntilIdle()

        let state = await runtime.currentState()
        // Child effect was executed and fed back .loaded("done")
        #expect(state.child.value == "done")
        #expect(state.child.isLoading == false)
        // Parent observed .loaded intent and incremented
        #expect(state.completionCount == 1)
    }

    @Test("Parent can react to child intents with additional state changes")
    func parentReactsToChildIntents() async {
        let parentExecutor: FeatureEffectExecutor<ParentFeature> = { _, _ in .none }

        let runtime = FeatureRuntime<ParentFeature>(
            dependencies: ParentFeature.Dependencies(),
            effectExecutor: parentExecutor
        )

        // Directly send the loaded intent (simulating effect feedback)
        await runtime.send(.child(.loaded("value")))

        let state = await runtime.currentState()

        // Child reducer processed it
        #expect(state.child.value == "value")
        #expect(state.child.isLoading == false)

        // Parent observed and reacted
        #expect(state.completionCount == 1)
    }

    @Test("Child outputs map to parent outputs")
    func childOutputsMappedToParent() async throws {
        let parentExecutor: FeatureEffectExecutor<ParentFeature> = { _, _ in .none }

        let runtime = FeatureRuntime<ParentFeature>(
            dependencies: ParentFeature.Dependencies(),
            effectExecutor: parentExecutor
        )

        // Collect outputs using an actor to avoid Sendable capture issues
        let collector = OutputCollector()
        let outputStream = await runtime.outputStream()
        let collectTask = Task {
            for await output in outputStream {
                await collector.append(output)
            }
        }

        // .loaded triggers child output .didComplete which maps to parent .childDidComplete
        await runtime.send(.child(.loaded("value")))
        await runtime.waitUntilIdle()

        // Give output stream time to deliver
        try await Task.sleep(nanoseconds: 50_000_000)

        collectTask.cancel()

        let outputs = await collector.values
        #expect(outputs.contains(where: {
            if case .childDidComplete = $0 { return true }
            return false
        }))
    }
}
