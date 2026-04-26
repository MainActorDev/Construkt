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
}
