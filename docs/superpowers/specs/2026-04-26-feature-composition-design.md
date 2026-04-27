# Feature Composition for Construkt Runtime

**Date:** 2026-04-26
**Status:** Approved
**Scope:** `ReduceResult.map`, `EffectFeedback.map`, and convenience methods for composing parent/child FeatureSpecs

---

## Problem

Every `FeatureSpec` in Construkt is an island. There is no mechanism for a parent feature to embed a child feature's state, intents, effects, and outputs. Real apps need parent-child feature trees (e.g., a TabBar feature containing Profile, Feed, and Search child features). Without composition primitives, developers must manually wire inter-feature communication with ad-hoc code, defeating the purpose of a structured architecture.

## Solution

Add **type-mapping methods** to `ReduceResult` and `EffectFeedback` that transform child types into parent types. This enables composition at the reducer and effect executor level without modifying `FeatureRuntime` or `FeatureStore`.

The approach is:
- **Purely additive** — new methods on existing structs, no changes to runtime internals
- **Explicit** — parent controls all wiring via `switch` + `map`
- **Type-safe** — compiler enforces correct mapping between child and parent types
- **Zero-overhead** — no dynamic dispatch, no existentials, no runtime reflection

## Architecture

### Composition Model

Parent embeds children at three levels:

1. **State:** Parent's `State` contains child's `State` as a stored property
2. **Intent:** Parent's `Intent` enum has a case wrapping child's `Intent`
3. **Effect:** Parent's `Effect` enum has a case wrapping child's `Effect`

The parent reducer delegates to the child reducer for child intents, maps the result, and can observe/react to what the child processed. Child effects execute through the parent's runtime using the parent's effect policies.

```
┌─────────────────────────────────────────────┐
│ Parent FeatureRuntime (single actor)        │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Parent Reducer                      │    │
│  │                                     │    │
│  │  case .child(childIntent):          │    │
│  │    Child.reduce(&state.child, ...)  │    │
│  │    .map(effect:output:)             │    │
│  │                                     │    │
│  │  case .parentIntent:                │    │
│  │    // parent's own logic            │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Parent Effect Executor              │    │
│  │                                     │    │
│  │  case .child(childEffect):          │    │
│  │    childExecutor(childEffect, ...)  │    │
│  │    .map(intent:output:)             │    │
│  │                                     │    │
│  │  case .parentEffect:                │    │
│  │    // parent's own effects          │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  policy(for:) delegates to child for        │
│  .child(childEffect) cases                  │
└─────────────────────────────────────────────┘
```

### Data Flow

```
Intent arrives (.child(childIntent))
  → Parent reducer switches on intent
  → Calls Child.reduce(state: &state.childSlice, intent: childIntent)
  → Gets ReduceResult<Child.Effect, Child.Output>
  → Maps to ReduceResult<Parent.Effect, Parent.Output> via .map(effect:output:)
  → Parent can append additional effects/outputs or modify state
  → Returns combined result to runtime
  → Runtime schedules effects (including mapped child effects)
  → Effect executor switches on .child(childEffect)
  → Calls child effect executor
  → Gets EffectFeedback<Child.Intent, Child.Output>
  → Maps to EffectFeedback<Parent.Intent, Parent.Output> via .map(intent:output:)
  → Runtime feeds back mapped intents (cycle continues)
```

## New API Surface

### `ReduceResult.map(effect:output:)`

Transforms a child's reduce result into parent types. This is the core composition primitive.

```swift
extension ReduceResult {
    /// Transforms effects and outputs into different types.
    /// Used to embed a child feature's reduce result into a parent.
    public func map<NewEffect: Sendable, NewOutput: Sendable>(
        effect: (Effect) -> NewEffect,
        output: (Output) -> NewOutput
    ) -> ReduceResult<NewEffect, NewOutput>
}
```

### `ReduceResult.mapEffects(_:)` and `ReduceResult.mapOutputs(_:)`

Convenience methods when only one type needs mapping.

```swift
extension ReduceResult {
    /// Maps only the effects, preserving output type.
    public func mapEffects<NewEffect: Sendable>(
        _ transform: (Effect) -> NewEffect
    ) -> ReduceResult<NewEffect, Output>

    /// Maps only the outputs, preserving effect type.
    public func mapOutputs<NewOutput: Sendable>(
        _ transform: (Output) -> NewOutput
    ) -> ReduceResult<Effect, NewOutput>
}
```

### `ReduceResult.merged(with:)`

Combines two reduce results (e.g., child result + parent's additional effects).

```swift
extension ReduceResult {
    /// Merges effects and outputs from another result into this one.
    public func merged(with other: ReduceResult<Effect, Output>) -> ReduceResult<Effect, Output>
}
```

### `EffectFeedback.map(intent:output:)`

Transforms a child's effect feedback into parent types.

```swift
extension EffectFeedback {
    /// Transforms intents and outputs into different types.
    /// Used to embed a child feature's effect feedback into a parent.
    public func map<NewIntent: Sendable, NewOutput: Sendable>(
        intent: (Intent) -> NewIntent,
        output: (Output) -> NewOutput
    ) -> EffectFeedback<NewIntent, NewOutput>
}
```

### `EffectFeedback.mapIntents(_:)` and `EffectFeedback.mapOutputs(_:)`

Convenience methods when only one type needs mapping.

```swift
extension EffectFeedback {
    /// Maps only the intents, preserving output type.
    public func mapIntents<NewIntent: Sendable>(
        _ transform: (Intent) -> NewIntent
    ) -> EffectFeedback<NewIntent, Output>

    /// Maps only the outputs, preserving intent type.
    public func mapOutputs<NewOutput: Sendable>(
        _ transform: (Output) -> NewOutput
    ) -> EffectFeedback<Intent, NewOutput>
}
```

## Usage Example

### Defining Parent and Child Features

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
        case logOut
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
        case .logOut:
            state = State()
            return ReduceResult(outputs: [.didLogOut])
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .fetchProfile: return .latest(key: "fetchProfile")
        }
    }
}

// Parent feature
enum AppFeature: FeatureSpec {
    struct State: Sendable, Equatable {
        var profile: ProfileFeature.State = ProfileFeature.initialState
        var sessionCount: Int = 0
    }
    enum Intent: Sendable {
        case profile(ProfileFeature.Intent)
        case incrementSession
    }
    enum Effect: Sendable, Hashable {
        case profile(ProfileFeature.Effect)
        case trackSession
    }
    enum Output: Sendable {
        case profile(ProfileFeature.Output)
    }
    struct Dependencies: Sendable {
        let profileDeps: ProfileFeature.Dependencies
        let analytics: AnalyticsService
    }

    static var initialState: State { State() }

    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .profile(let childIntent):
            // 1. Delegate to child reducer
            let childResult = ProfileFeature.reduce(
                state: &state.profile,
                intent: childIntent
            )

            // 2. Map child types to parent types
            var result = childResult.map(
                effect: { Effect.profile($0) },
                output: { Output.profile($0) }
            )

            // 3. Parent observes child intent and reacts
            if case .logOut = childIntent {
                state.sessionCount = 0
                result.effects.append(.trackSession)
            }

            return result

        case .incrementSession:
            state.sessionCount += 1
            return .none
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .profile(let childEffect):
            return ProfileFeature.policy(for: childEffect)
        case .trackSession:
            return .concurrent
        }
    }

    static func staleStrategy(for effect: Effect) -> StaleEffectStrategy {
        switch effect {
        case .profile(let childEffect):
            return ProfileFeature.staleStrategy(for: childEffect)
        case .trackSession:
            return .drop
        }
    }

    static func mapEffectError(_ error: any Error, effect: Effect) -> Intent? {
        switch effect {
        case .profile(let childEffect):
            return ProfileFeature.mapEffectError(error, effect: childEffect)
                .map { Intent.profile($0) }
        case .trackSession:
            return nil
        }
    }
}
```

### Effect Executor Composition

```swift
let profileExecutor: FeatureEffectExecutor<ProfileFeature> = { effect, deps in
    switch effect {
    case .fetchProfile:
        let name = try await deps.api.fetchProfile()
        return EffectFeedback(intents: [.profileLoaded(name)])
    }
}

let appExecutor: FeatureEffectExecutor<AppFeature> = { effect, deps in
    switch effect {
    case .profile(let childEffect):
        let childFeedback = try await profileExecutor(childEffect, deps.profileDeps)
        return childFeedback.map(
            intent: { .profile($0) },
            output: { .profile($0) }
        )
    case .trackSession:
        await deps.analytics.trackSession()
        return .none
    }
}
```

### Creating the Store

```swift
let store = FeatureStore<AppFeature>(
    dependencies: AppFeature.Dependencies(
        profileDeps: ProfileFeature.Dependencies(api: liveAPI),
        analytics: liveAnalytics
    ),
    effectExecutor: appExecutor
)

// Dispatch child intent through parent
store.dispatch(.profile(.loadProfile))

// Observe child state through parent
store.state.map(\.profile.username).observe { name in
    print("Username: \(name)")
}
```

## Scope

### In Scope
- `ReduceResult.map(effect:output:)` — core composition primitive
- `ReduceResult.mapEffects(_:)` — convenience for effect-only mapping
- `ReduceResult.mapOutputs(_:)` — convenience for output-only mapping
- `ReduceResult.merged(with:)` — combine two reduce results
- `EffectFeedback.map(intent:output:)` — core composition primitive
- `EffectFeedback.mapIntents(_:)` — convenience for intent-only mapping
- `EffectFeedback.mapOutputs(_:)` — convenience for output-only mapping
- Unit tests for all new methods
- Documentation updates to README.md and SKILL.md

### Out of Scope (deferred)
- `Scope` type or automatic reducer composition
- `ifLet` for optional child state
- `forEach` for collection child state
- Changes to `FeatureRuntime` or `FeatureStore`
- `ChildFeature` helper struct
- Dependency injection container
- Middleware pipeline

## Testing Strategy

### Unit Tests

1. **`ReduceResult.map` tests:**
   - Maps effects correctly
   - Maps outputs correctly
   - Maps both simultaneously
   - Preserves empty arrays
   - Works with `.none` result

2. **`ReduceResult.mapEffects` / `mapOutputs` tests:**
   - Maps only the targeted type
   - Preserves the other type unchanged

3. **`ReduceResult.merged` tests:**
   - Merges effects from both results
   - Merges outputs from both results
   - Merging with `.none` returns original
   - Merging `.none` with result returns result

4. **`EffectFeedback.map` tests:**
   - Maps intents correctly
   - Maps outputs correctly
   - Maps both simultaneously
   - Preserves empty arrays
   - Works with `.none` feedback

5. **`EffectFeedback.mapIntents` / `mapOutputs` tests:**
   - Maps only the targeted type
   - Preserves the other type unchanged

6. **Integration test: Parent-child composition:**
   - Parent reducer delegates to child reducer
   - Child effects execute through parent runtime
   - Child effect feedback maps back to parent intents
   - Parent observes child intents and reacts
   - Full round-trip: dispatch child intent → child reduce → child effect → child feedback → parent state update

## File Changes

| File | Change |
|------|--------|
| `Sources/Construkt/Core/Runtime/FeatureSpec.swift` | Add `map`, `mapEffects`, `mapOutputs`, `merged` to `ReduceResult`; add `map`, `mapIntents`, `mapOutputs` to `EffectFeedback` |
| `Tests/ConstruktTests/FeatureCompositionTests.swift` | New test file with unit + integration tests |
| `README.md` | Add Feature Composition section to Runtime documentation |
| `SKILL.md` | Add composition patterns and anti-patterns |

## Constraints

- iOS 14+ minimum — no iOS 16+ only APIs
- Zero external dependencies
- Swift 5.9 tools version
- All `FeatureSpec` methods remain `static`
- No changes to `FeatureRuntime` or `FeatureStore`
- All new types must be `Sendable`
