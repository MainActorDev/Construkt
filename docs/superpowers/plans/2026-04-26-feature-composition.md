# Feature Composition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add type-mapping methods to `ReduceResult` and `EffectFeedback` that enable parent-child feature composition without modifying `FeatureRuntime` or `FeatureStore`.

**Architecture:** Pure reducer-level composition via `map` methods on existing structs. Parent FeatureSpec embeds child state as a property, child intents/effects as enum cases, and delegates to child reducer + effect executor with type mapping. Zero runtime changes.

**Tech Stack:** Swift 5.9, iOS 14+, Swift Testing framework (`@Suite`, `@Test`, `#expect`)

**Build command:** `xcodebuild build -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | tail -5`

**Test command:** `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | tail -20`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Sources/Construkt/Core/Runtime/FeatureSpec.swift` | Modify (lines 69-105) | Add 7 new methods to `ReduceResult` and `EffectFeedback` |
| `Tests/ConstruktTests/FeatureCompositionTests.swift` | Create | Unit tests for all map/merge methods + integration test |
| `README.md` | Modify | Add Feature Composition section to Runtime docs |
| `SKILL.md` | Modify | Add composition patterns and anti-patterns |

---

### Task 1: Write failing tests for `ReduceResult.map(effect:output:)`

**Files:**
- Create: `Tests/ConstruktTests/FeatureCompositionTests.swift`

- [ ] **Step 1: Create the test file with ReduceResult.map tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Test Suite|Executed|map)'`

Expected: Compilation error — `ReduceResult` has no member `map`

- [ ] **Step 3: Commit the failing test**

```bash
git add Tests/ConstruktTests/FeatureCompositionTests.swift
git commit -m "test: add failing tests for ReduceResult.map(effect:output:)"
```

---

### Task 2: Implement `ReduceResult.map(effect:output:)`

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/FeatureSpec.swift` (after line 86, before `EffectFeedback`)

- [ ] **Step 1: Add the map method to ReduceResult**

Add the following extension after the closing brace of `ReduceResult` (after line 86 in `FeatureSpec.swift`):

```swift
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
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Test Suite|Executed|FeatureComposition)'`

Expected: All 5 `ReduceResult.map` tests pass. BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Construkt/Core/Runtime/FeatureSpec.swift
git commit -m "feat: add ReduceResult.map(effect:output:) for feature composition"
```

---

### Task 3: Write failing tests for `ReduceResult.mapEffects` and `ReduceResult.mapOutputs`

**Files:**
- Modify: `Tests/ConstruktTests/FeatureCompositionTests.swift`

- [ ] **Step 1: Add tests for mapEffects and mapOutputs**

Append inside the `FeatureCompositionTests` struct, after the existing tests:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|mapEffects|mapOutputs)'`

Expected: Compilation error — `ReduceResult` has no member `mapEffects` / `mapOutputs`

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/ConstruktTests/FeatureCompositionTests.swift
git commit -m "test: add failing tests for ReduceResult.mapEffects and mapOutputs"
```

---

### Task 4: Implement `ReduceResult.mapEffects` and `ReduceResult.mapOutputs`

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/FeatureSpec.swift` (inside the `ReduceResult` composition extension)

- [ ] **Step 1: Add mapEffects and mapOutputs to the existing extension**

Add inside the `extension ReduceResult` block (after the `map` method):

```swift
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
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Executed|FeatureComposition)'`

Expected: All 9 tests pass (5 map + 4 mapEffects/mapOutputs). BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Construkt/Core/Runtime/FeatureSpec.swift
git commit -m "feat: add ReduceResult.mapEffects and mapOutputs convenience methods"
```

---

### Task 5: Write failing tests for `ReduceResult.merged(with:)`

**Files:**
- Modify: `Tests/ConstruktTests/FeatureCompositionTests.swift`

- [ ] **Step 1: Add tests for merged**

Append inside the `FeatureCompositionTests` struct:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|merged)'`

Expected: Compilation error — `ReduceResult` has no member `merged`

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/ConstruktTests/FeatureCompositionTests.swift
git commit -m "test: add failing tests for ReduceResult.merged(with:)"
```

---

### Task 6: Implement `ReduceResult.merged(with:)`

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/FeatureSpec.swift` (inside the `ReduceResult` composition extension)

- [ ] **Step 1: Add merged to the existing extension**

Add inside the `extension ReduceResult` block (after `mapOutputs`):

```swift
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
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Executed|FeatureComposition)'`

Expected: All 13 tests pass (5 map + 4 mapEffects/mapOutputs + 4 merged). BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Construkt/Core/Runtime/FeatureSpec.swift
git commit -m "feat: add ReduceResult.merged(with:) for combining reduce results"
```

---

### Task 7: Write failing tests for `EffectFeedback.map(intent:output:)`

**Files:**
- Modify: `Tests/ConstruktTests/FeatureCompositionTests.swift`

- [ ] **Step 1: Add tests for EffectFeedback.map**

Append inside the `FeatureCompositionTests` struct:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|EffectFeedback.*map)'`

Expected: Compilation error — `EffectFeedback` has no member `map`

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/ConstruktTests/FeatureCompositionTests.swift
git commit -m "test: add failing tests for EffectFeedback.map(intent:output:)"
```

---

### Task 8: Implement `EffectFeedback.map(intent:output:)`

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/FeatureSpec.swift` (after `EffectFeedback` struct, before `RuntimeConfiguration`)

- [ ] **Step 1: Add the map method to EffectFeedback**

Add the following extension after the closing brace of `EffectFeedback` (after line 105 in the original file, but the line number will have shifted due to earlier additions):

```swift
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
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Executed|FeatureComposition)'`

Expected: All 18 tests pass (13 ReduceResult + 5 EffectFeedback.map). BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Construkt/Core/Runtime/FeatureSpec.swift
git commit -m "feat: add EffectFeedback.map(intent:output:) for feature composition"
```

---

### Task 9: Write failing tests for `EffectFeedback.mapIntents` and `EffectFeedback.mapOutputs`

**Files:**
- Modify: `Tests/ConstruktTests/FeatureCompositionTests.swift`

- [ ] **Step 1: Add tests for mapIntents and mapOutputs**

Append inside the `FeatureCompositionTests` struct:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|mapIntents|mapOutputs)'`

Expected: Compilation error — `EffectFeedback` has no member `mapIntents` / `mapOutputs`

- [ ] **Step 3: Commit the failing tests**

```bash
git add Tests/ConstruktTests/FeatureCompositionTests.swift
git commit -m "test: add failing tests for EffectFeedback.mapIntents and mapOutputs"
```

---

### Task 10: Implement `EffectFeedback.mapIntents` and `EffectFeedback.mapOutputs`

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/FeatureSpec.swift` (inside the `EffectFeedback` composition extension)

- [ ] **Step 1: Add mapIntents and mapOutputs to the existing extension**

Add inside the `extension EffectFeedback` block (after the `map` method):

```swift
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
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Executed|FeatureComposition)'`

Expected: All 22 tests pass (13 ReduceResult + 9 EffectFeedback). BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Construkt/Core/Runtime/FeatureSpec.swift
git commit -m "feat: add EffectFeedback.mapIntents and mapOutputs convenience methods"
```

---

### Task 11: Write and run integration test for parent-child composition

**Files:**
- Modify: `Tests/ConstruktTests/FeatureCompositionTests.swift`

This test validates the full round-trip: dispatch child intent through parent → child reduce → child effect → child feedback → parent state update. It uses real `FeatureRuntime` and `FeatureStore`.

- [ ] **Step 1: Add test helper types and integration test**

Append at the end of the file (outside the `FeatureCompositionTests` struct):

```swift
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
            initialState: ParentFeature.initialState,
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
            initialState: ParentFeature.initialState,
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
            initialState: ParentFeature.initialState,
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
            initialState: ParentFeature.initialState,
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
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | grep -E '(error:|BUILD|Executed|FeatureComposition)'`

Expected: All 26 tests pass (22 unit + 4 integration). BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Tests/ConstruktTests/FeatureCompositionTests.swift
git commit -m "test: add integration tests for parent-child feature composition"
```

---

### Task 12: Update README.md with Feature Composition documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find the Runtime section in README.md**

Search for the "## Runtime" or "### Feature Runtime" section heading. The new Feature Composition section should be added after the existing Runtime documentation (after the EffectPolicy/RuntimeJournal sections, before Navigation).

- [ ] **Step 2: Add Feature Composition section**

Add the following section after the existing Runtime documentation:

```markdown
### Feature Composition

Construkt supports composing parent and child features using type-mapping methods on `ReduceResult` and `EffectFeedback`. The parent feature embeds the child's state, intents, and effects, then delegates to the child's reducer and effect executor.

#### Defining Parent and Child

```swift
// Child feature
enum ProfileFeature: FeatureSpec {
    struct State: Sendable, Equatable {
        var username: String = ""
        var isLoading: Bool = false
    }
    enum Intent: Sendable {
        case loadProfile
        case profileLoaded(String)
    }
    enum Effect: Sendable, Hashable {
        case fetchProfile
    }
    enum Output: Sendable {
        case didLogOut
    }
    struct Dependencies: Sendable {
        let api: ProfileAPI
    }

    static var initialState: State { State() }

    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .loadProfile:
            state.isLoading = true
            return ReduceResult(effects: [.fetchProfile])
        case .profileLoaded(let name):
            state.username = name
            state.isLoading = false
            return .none
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        .latest("fetchProfile")
    }
}

// Parent embeds child
enum AppFeature: FeatureSpec {
    struct State: Sendable, Equatable {
        var profile: ProfileFeature.State = ProfileFeature.initialState  // embed child state
        var sessionCount: Int = 0
    }
    enum Intent: Sendable {
        case profile(ProfileFeature.Intent)  // wrap child intents
        case incrementSession
    }
    enum Effect: Sendable, Hashable {
        case profile(ProfileFeature.Effect)  // wrap child effects
    }
    enum Output: Sendable {
        case profile(ProfileFeature.Output)  // wrap child outputs
    }
    // ...
}
```

#### Reducer Composition

In the parent reducer, delegate to the child reducer and map the result:

```swift
static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
    switch intent {
    case .profile(let childIntent):
        // 1. Delegate to child
        let childResult = ProfileFeature.reduce(state: &state.profile, intent: childIntent)

        // 2. Map child types to parent types
        var result = childResult.map(
            effect: { Effect.profile($0) },
            output: { Output.profile($0) }
        )

        // 3. Parent can observe and react
        if case .profileLoaded = childIntent {
            state.sessionCount += 1
        }

        return result

    case .incrementSession:
        state.sessionCount += 1
        return .none
    }
}
```

#### Effect Executor Composition

Compose effect executors by delegating child effects and mapping feedback:

```swift
let appExecutor: FeatureEffectExecutor<AppFeature> = { effect, deps in
    switch effect {
    case .profile(let childEffect):
        let childFeedback = try await profileExecutor(childEffect, deps.profileDeps)
        return childFeedback.map(
            intent: { .profile($0) },
            output: { .profile($0) }
        )
    case .trackSession:
        // parent's own effect
        return .none
    }
}
```

#### Policy Delegation

Delegate effect policies to the child feature:

```swift
static func policy(for effect: Effect) -> EffectPolicy {
    switch effect {
    case .profile(let childEffect):
        return ProfileFeature.policy(for: childEffect)
    case .trackSession:
        return .concurrent
    }
}
```

#### Composition API Reference

| Method | Purpose |
|--------|---------|
| `ReduceResult.map(effect:output:)` | Transform child reduce result to parent types |
| `ReduceResult.mapEffects(_:)` | Map only effects, preserve output type |
| `ReduceResult.mapOutputs(_:)` | Map only outputs, preserve effect type |
| `ReduceResult.merged(with:)` | Combine two reduce results |
| `EffectFeedback.map(intent:output:)` | Transform child effect feedback to parent types |
| `EffectFeedback.mapIntents(_:)` | Map only intents, preserve output type |
| `EffectFeedback.mapOutputs(_:)` | Map only outputs, preserve intent type |
```

- [ ] **Step 3: Run build to verify no issues**

Run: `xcodebuild build -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add feature composition section to README"
```

---

### Task 13: Update SKILL.md with composition patterns

**Files:**
- Modify: `SKILL.md`

- [ ] **Step 1: Find the Runtime section in SKILL.md**

Search for the Runtime-related section. Add composition patterns after existing Runtime guidance.

- [ ] **Step 2: Add composition patterns and anti-patterns**

Add the following section:

```markdown
### Feature Composition

**Pattern: Parent-child reducer delegation**
```swift
case .child(let childIntent):
    let childResult = ChildFeature.reduce(state: &state.child, intent: childIntent)
    return childResult.map(
        effect: { Effect.child($0) },
        output: { Output.child($0) }
    )
```

**Pattern: Effect executor delegation**
```swift
case .child(let childEffect):
    let childFeedback = try await childExecutor(childEffect, deps.childDeps)
    return childFeedback.map(intent: { .child($0) }, output: { .child($0) })
```

**Pattern: Policy delegation**
```swift
case .child(let childEffect):
    return ChildFeature.policy(for: childEffect)
```

**Anti-pattern: Forgetting to map child types**
```swift
// WRONG: Returns ReduceResult<ChildEffect, ChildOutput> — type mismatch
case .child(let childIntent):
    return ChildFeature.reduce(state: &state.child, intent: childIntent)

// RIGHT: Map to parent types
case .child(let childIntent):
    return ChildFeature.reduce(state: &state.child, intent: childIntent)
        .map(effect: { .child($0) }, output: { .child($0) })
```

**Anti-pattern: Creating separate FeatureStore for child**
```swift
// WRONG: Child runs in its own runtime — no composition
let childStore = FeatureStore<ChildFeature>(...)
let parentStore = FeatureStore<ParentFeature>(...)

// RIGHT: Single parent store, child state embedded
let store = FeatureStore<ParentFeature>(...)
store.dispatch(.child(.loadProfile))
store.state.map(\.child.username)  // observe child state through parent
```
```

- [ ] **Step 3: Commit**

```bash
git add SKILL.md
git commit -m "docs: add feature composition patterns to SKILL.md"
```

---

### Task 14: Run full test suite and verify everything passes

**Files:** None (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | tail -30`

Expected: All tests pass (existing 111 + new 26 = 137 total). BUILD SUCCEEDED. TEST SUCCEEDED.

- [ ] **Step 2: Verify the new file exists and source compiles cleanly**

Run: `xcodebuild build -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED with zero warnings related to new code.

- [ ] **Step 3: Verify git status is clean**

Run: `git status`

Expected: Clean working tree, all changes committed.
