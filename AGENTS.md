# AGENTS.md — Construkt

## Project Overview

Construkt is a Swift Package providing a **declarative UIKit framework** (SwiftUI-like syntax) and a **runtime-first state machine architecture** for iOS apps. It has zero external dependencies.

- **Library target:** `ConstruktKit` (sources in `Sources/Construkt/`)
- **Test target:** `ConstruktTests` (in `Tests/ConstruktTests/`)
- **Swift tools version:** 5.9 | **Platform:** iOS 14+ | **Language:** Swift 5

## Build & Test

```bash
swift build   # Build the package
swift test    # Run all tests
```

There is no CI pipeline, Makefile, linter, or formatter configured.

## Source Architecture

```
Sources/Construkt/
  Core/
    Builder/        # Declarative UI: ResultBuilder, modifiers, constraints, stacks, screens, collection views
    Reactive/       # Reactive primitives: Property, Signal, Binding, CancelBag
    Runtime/        # State machines: FeatureSpec, FeatureStore, FeatureRuntime, EffectPolicy
    Extensions/
  Components/       # Reusable UI: CollectionView, ShimmerView, custom Views
  Extensions/
  Navigation/       # Routing: ConstruktRouteHandler, Coordinator, Router, SheetController, ToastManager
```

### Key Subsystems

- **Builder** — `ViewBuilder` protocol + `@resultBuilder` generating `UIView` hierarchies declaratively. Modifiers chain on views (`.backgroundColor`, `.cornerRadius`, `.margins`, etc.).
- **Reactive** — `@Variable` (wraps `Property<T>`) for observable state, `Signal<T>` for events, `$` prefix for bindings. `CancelBag` manages subscription lifetimes.
- **Runtime** — `FeatureSpec` defines `State`, `Action`, `Effect`. `reduce(state:action:)` is pure/synchronous. `effectExecutor` handles async side effects. `EffectPolicy` controls concurrency (`.cancelInFlight`, `.throttle`, etc.). `FeatureStore` holds state; `FeatureRuntime` wires it together.
- **Navigation** — `ConstruktRouteHandler` (preferred) or `ConstruktCoordinator`. Uses UIKit responder chain for event routing. `Router` manages the navigation stack.

## Coding Conventions

### Do

- Use Construkt's declarative syntax for all UI — chain modifiers, use `VStack`, `HStack`, `ZStack`, `Spacer`.
- Use `@Variable` for mutable state, `$` prefix to create bindings.
- Keep `reduce` pure and synchronous; all async work goes in `effectExecutor`.
- Use `ConstruktRouteHandler` for navigation unless coordinator pattern is explicitly needed.
- Isolate complex expressions into local `let` variables inside `@resultBuilder` blocks — this makes compiler errors meaningful.
- Run `swift test` after any change.

### Do Not

- **Never** import SwiftUI or use SwiftUI types — this is a pure UIKit framework.
- **Never** write manual Auto Layout constraints — use Construkt's constraint modifiers.
- **Never** implement `UICollectionViewDataSource` manually — use Construkt's declarative collection view API.
- **Never** put async logic inside `reduce`.

### Modifier Naming (differs from SwiftUI)

| Construkt              | SwiftUI equivalent |
|------------------------|--------------------|
| `.backgroundColor(_:)` | `.background(_:)`  |
| `.alpha(_:)`           | `.opacity(_:)`     |
| `.margins(_:)`         | `.padding(_:)`     |
| `.cornerRadius(_:)`    | `.clipShape(_:)`   |

### ResultBuilder Debugging

Compiler errors inside `@resultBuilder` blocks are often misleading. When you hit a confusing error:
1. Extract subexpressions into local `let` constants.
2. Build incrementally to isolate the real issue.
3. Check modifier names — SwiftUI naming is a common mistake.

## Tests

13 test files in `Tests/ConstruktTests/` covering: bindings, builder components, constraints, event routing, feature runtime, feature store, geometry reader, lifecycle, padding, reactive primitives, router lifecycle, and toast manager.

## Reference Documentation

- `README.md` — Comprehensive framework guide covering all subsystems with examples.
- `SKILL.md` — AI-agent-specific guide for writing Construkt UI code, with patterns and anti-patterns.
