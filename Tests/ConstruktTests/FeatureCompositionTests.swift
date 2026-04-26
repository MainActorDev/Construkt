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
}
