# Construkt Framework Hardening — Design Spec

**Date:** 2026-05-06  
**Scope:** Correctness bugs, memory management, performance, thread safety, architecture  
**Approach:** Phased — A (surgical fixes) → B (performance layer) → C (future reconciliation)

---

## Executive Summary

A deep analysis of all four Construkt subsystems (Reactive, Runtime, Builder, Navigation) identified 29 issues across 5 severity tiers. This spec defines a phased improvement plan that addresses correctness bugs first, then performance bottlenecks, with a long-term architectural evolution path.

---

## Phase A: Surgical Bug Fixes

Low-risk, isolated fixes for currently broken behavior. No API changes. Each fix is independently testable.

### A1. Connect SheetPresentationController.onDismiss to SheetController.onDismiss

**Files:** `Sources/Construkt/Navigation/SheetController.swift`, `Sources/Construkt/Navigation/SheetPresentationController.swift`

**Problem:** Tapping the dimming overlay dismisses the sheet but never fires the developer's `onDismiss` callback. `SheetPresentationController` has its own `onDismiss` that is never wired to `SheetController.onDismiss`.

**Fix:** In `SheetController`'s presentation controller setup, assign:
```swift
presentationController.onDismiss = { [weak self] in self?.onDismiss?() }
```

**Test:** Present a sheet, tap dimming view, assert `onDismiss` closure was called.

---

### A2. Fix Toast Content VC Containment

**Files:** `Sources/Construkt/Navigation/ToastManager.swift`, `Sources/Construkt/Navigation/ToastItemView.swift`

**Problem:** `setContent` is called with `parent: nil`. `addChild()` is never called, so the content VC's lifecycle methods (`viewWillAppear`, `viewDidAppear`) never fire.

**Fix:** Pass the toast's hosting view controller (or the window's root VC) as the parent. Call `parent.addChild(vc)` followed by `vc.didMove(toParent: parent)`.

**Test:** Present a toast with a VC that sets a flag in `viewDidAppear`. Assert the flag is set.

---

### A3. Fix .onRoute Modifier Overwriting Previous Targets

**Files:** `Sources/Construkt/Navigation/EventRouting.swift`

**Problem:** `.onRoute` uses a single associated-object key. A second call overwrites the first target, but the first gesture recognizer remains attached with a deallocated target.

**Fix:** Either:
- (a) Accumulate targets in an array keyed by event type, or
- (b) Remove the old gesture recognizer before adding a new one

Recommended: (b) — simpler, matches expected behavior (last writer wins cleanly).

**Test:** Apply `.onRoute` twice on the same view with different event types. Trigger both. Assert both handlers fire (option a) or only the latest fires without crash (option b).

---

### A4. Fix delay Operator Parameter Shadowing

**Files:** `Sources/Construkt/Core/Reactive/Binding+Operators.swift`

**Problem:** The `delay(_:on queue:)` operator's `AnyViewBinding` initializer closure parameter is also named `queue`, shadowing the outer scheduler queue. The delay always fires on the observer's queue.

**Fix:** Rename the inner closure parameter:
```swift
AnyViewBinding<T> { observerQueue, handler in
    source.observe(on: observerQueue) { value in
        queue.asyncAfter(deadline: .now() + interval) {
            handler(value)
        }
    }
}
```

**Test:** Create a `delay(1.0, on: backgroundQueue)` binding. Assert the delayed emission arrives on `backgroundQueue`, not the observer's queue.

---

### A5. Add Lock to flatMapLatest's innerCancellable

**Files:** `Sources/Construkt/Core/Reactive/Binding+Operators.swift`

**Problem:** `innerCancellable` is a captured `var` with no synchronization. Concurrent emissions from the source can race on read/write.

**Fix:** Add a local `NSLock` (matching the pattern used by `debounce`, `throttle`, etc.):
```swift
let innerLock = NSLock()
var innerCancellable: AnyCancellableLifecycle?

source.observe(on: queue) { value in
    innerLock.lock()
    innerCancellable?.cancel()
    innerCancellable = transform(value).observe(on: queue, handler)
    innerLock.unlock()
}
```

**Test:** Emit rapidly from multiple threads on a `flatMapLatest` chain. Assert no crashes and final value is from the latest emission.

---

### A6. Fix SheetController Transform/Constraint Mixing

**Files:** `Sources/Construkt/Navigation/SheetController.swift`

**Problem:** During pan, position is controlled via `CGAffineTransform`. On snap, transform resets to `.identity` and a constraint constant is set. Interrupting a snap animation with a new pan causes a visual jump.

**Fix:** Use constraint-only positioning throughout:
- During pan: update `containerBottomConstraint.constant` directly, call `view.layoutIfNeeded()`
- On snap: animate the constraint constant change

**Test:** Programmatically simulate a pan gesture that interrupts a snap animation. Assert no frame discontinuity (constraint constant changes monotonically).

---

### A7. Make CancelBag Lazy Init on NSObject Thread-Safe

**Files:** `Sources/Construkt/Core/Reactive/CancelBag.swift`

**Problem:** Concurrent first-access of `someObject.cancelBag` can create two instances; one is lost with its subscriptions.

**Fix:** Use `objc_sync_enter(self)` / `objc_sync_exit(self)` around the associated object creation:
```swift
var cancelBag: CancelBag {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    if let existing = objc_getAssociatedObject(self, &key) as? CancelBag {
        return existing
    }
    let bag = CancelBag()
    objc_setAssociatedObject(self, &key, bag, .OBJC_ASSOCIATION_RETAIN)
    return bag
}
```

**Test:** Access `cancelBag` from 100 concurrent threads on the same object. Assert all return the same instance.

---

### A8. Add Pruning to CancelBag

**Files:** `Sources/Construkt/Core/Reactive/CancelBag.swift`

**Problem:** The internal array only grows. Cancelled tokens accumulate as dead weight.

**Fix:** On `store(in:)`, compact the array if it exceeds a threshold (e.g., 32 entries):
```swift
public func store(_ cancellable: AnyCancellableLifecycle) {
    lock.lock()
    cancellables.append(cancellable)
    if cancellables.count > 32 {
        cancellables.removeAll { $0.isCancelled }
    }
    lock.unlock()
}
```

Requires adding an `isCancelled` property to `AnyCancellableLifecycle` protocol (or checking via a flag on concrete types).

**Test:** Store 100 cancellables, cancel 90 of them, store one more. Assert array count is ≤ 11.

---

### A9. Fix DefaultRouter.completions Strong Key Retention

**Files:** `Sources/Construkt/Navigation/Router.swift`

**Problem:** `[UIViewController: () -> Void]` retains VCs as dictionary keys.

**Fix:** Use `NSMapTable.weakToStrongObjects()`:
```swift
private let completions = NSMapTable<UIViewController, Box<() -> Void>>.weakToStrongObjects()
```
(Requires a `Box` wrapper since `NSMapTable` needs object values.)

**Test:** Push a VC with a completion, pop it, assert the VC is deallocated (weak reference becomes nil).

---

### A10. Fix RuntimeScope Child Cleanup

**Files:** `Sources/Construkt/Core/Runtime/RuntimeScope.swift`

**Problem:** Children remain in parent's `children` dict after independent shutdown.

**Fix:** In `shutdown()`, notify the parent to remove this child:
```swift
func shutdown() {
    // ... existing shutdown logic ...
    if let parentID = parentID {
        // Parent removes child via a stored weak reference or callback
    }
}
```

Alternative: Store children as weak references (`[UUID: WeakBox<RuntimeScope>]`) and compact periodically.

**Test:** Create parent scope, create 100 child scopes, shut them all down. Assert parent's `children` dict is empty.

---

### A11. Make Output Stream Buffer Configurable

**Files:** `Sources/Construkt/Core/Runtime/FeatureRuntime.swift`, `Sources/Construkt/Core/Runtime/FeatureSpec.swift`

**Problem:** `.bufferingNewest(50)` silently drops outputs under burst conditions.

**Fix:** Add `outputBufferSize` to `RuntimeConfiguration` (default 50, allow higher). Document the trade-off. For critical outputs, consider a separate unbounded channel or `.bufferingOldest` with backpressure.

**Test:** Produce 100 outputs in rapid succession. With buffer=50, assert exactly 50 are received. With buffer=200, assert all 100 are received.

---

### A12. Document Retain Cycle Risk + Debug Warning

**Files:** `Sources/Construkt/Core/Reactive/Property.swift`, `Sources/Construkt/Core/Reactive/Signal.swift`

**Problem:** No compile-time or runtime guidance about `[weak self]` in observation handlers.

**Fix:**
1. Add doc comments on `observe()` methods warning about strong capture
2. In DEBUG builds, optionally log a warning if an observer closure appears to retain the observed property's owner (heuristic: check if the handler's capture list includes the property itself)

**Test:** Documentation review. Debug warning fires when a known-bad pattern is used in tests.

---

## Phase B: Performance Layer

Opt-in improvements that reduce unnecessary work without breaking existing APIs.

### B13/B16. Built-in Deduplication for Property

**Files:** `Sources/Construkt/Core/Reactive/Property.swift`

**Problem:** Every `wrappedValue` set broadcasts to all observers, even if the value hasn't changed.

**Fix:** For `Equatable` types, add a conditional extension that skips notification when `newValue == oldValue`:
```swift
extension Property where T: Equatable {
    public var deduplicatedValue: T {
        get { wrappedValue }
        set {
            guard newValue != wrappedValue else { return }
            wrappedValue = newValue
        }
    }
}
```

Or make deduplication the default behavior via a configuration flag on `Property.init(_, deduplicate: Bool = true)`.

**Trade-off:** Breaking change if code relies on notification-on-every-set. Recommend opt-in initially.

---

### B14. Identity-Aware ForEach

**Files:** `Sources/Construkt/Core/Builder/Builder+ForEach.swift`

**Problem:** `ForEach` is purely static — rebuilds all views on any data change.

**Fix:** Introduce `DynamicForEach<Item: Identifiable>` that:
1. Stores the previous item list
2. On update, diffs by `id`
3. Inserts/removes/moves only changed items in the parent stack

**Trade-off:** Requires `Identifiable` conformance. New type alongside existing `ForEach`.

---

### B15. DiffableContainer

**Files:** New file: `Sources/Construkt/Core/Builder/Builder+DiffableContainer.swift`

**Problem:** `DynamicContainerView` does full teardown + rebuild on every emission.

**Fix:** A new container that:
1. Assigns stable identities to children (via tag or position)
2. On binding emission, compares new children against current
3. Applies minimal add/remove/reorder operations

**Trade-off:** New API. Only helps with top-level child changes, not deep subtree mutations.

---

### B17. Lazy Modifier Application

**Files:** `Sources/Construkt/Core/Builder/Builder.swift`

**Problem:** Each modifier allocates a `ViewModifier<Base>` and applies immediately. Deep chains create many intermediates.

**Fix:** Collect modifiers as a `[UIView -> Void]` array, apply all at once in `build()`. The `ViewModifier` struct becomes a lightweight recipe rather than an eager mutator.

**Trade-off:** Changes timing of side effects. Code that reads view properties between modifiers would break. Recommend as opt-in or for a v2 API.

---

### B18. Ring Buffer for RuntimeJournal

**Files:** `Sources/Construkt/Core/Runtime/RuntimeJournal.swift`

**Problem:** `Array.removeFirst()` is O(n).

**Fix:** Replace with a circular buffer:
```swift
private var buffer: [RuntimeJournalEntry<Intent, Effect>?]
private var head: Int = 0
private var count: Int = 0

mutating func append(_ event: ...) {
    let entry = RuntimeJournalEntry(timestamp: Date(), event: event)
    buffer[(head + count) % capacity] = entry
    if count == capacity { head = (head + 1) % capacity }
    else { count += 1 }
}
```

**Trade-off:** None — pure internal optimization, no API change.

---

## Phase C: Full Reconciliation (Future)

### C23. Virtual View Tree with Diffing

**Problem:** The framework's fundamental model is "build once, replace entirely." This creates a performance ceiling for complex, frequently-updating UIs.

**Approach:** Introduce an intermediate `ViewNode` tree:
1. DSL produces `ViewNode` descriptors (lightweight value types) instead of `UIView` directly
2. On state change, a new `ViewNode` tree is produced
3. A reconciler diffs old vs. new tree by identity + type
4. Only the differences are applied to the real UIKit hierarchy (insert, remove, update properties)

**Scope:** This is a major architectural evolution. It would:
- Require a view identity concept (similar to SwiftUI's `id`)
- Need a diffing algorithm (Myers diff or similar)
- Change the `View` protocol semantics (from "produces a UIView" to "produces a ViewNode")
- Require a migration path for existing code

**Recommendation:** Defer until Phase A and B are complete and validated. Phase B's `DiffableContainer` and `DynamicForEach` serve as stepping stones toward this architecture.

---

## Implementation Order (Revised)

```
Phase A — Safe fixes (zero/low regression risk):
  A1 (sheet onDismiss)     — additive wiring
  A2 (toast containment)   — additive containment
  A4 (delay shadowing)     — 0 consumers
  A5 (flatMapLatest lock)  — 0 consumers
  A3 (.onRoute cleanup)    — 2 test sites, fix is for uncovered edge case
  B18 (journal ring buffer) — internal-only

Phase A — Medium risk (need regression tests first):
  A6 (sheet constraint-only) — gesture behavior change, manual QA needed
  A7 (cancelBag thread safety) — additive sync on NSObject extension
  A9 (router weak keys)    — dictionary type change, 1 consumer
  A10 (scope child cleanup) — actor-internal
  A11 (output buffer config) — runtime bridge change

Phase B — Opt-in performance:
  B13 (Property dedup flag) — opt-in, not default
  B14 (DynamicForEach)      — new type, no existing code affected
  B15 (DiffableContainer)   — new type, no existing code affected

Deferred:
  A8 (CancelBag pruning)   — protocol change, high surface area
  A12 (retain cycle docs)  — education item
  B17 (lazy modifiers)     — removed, too risky

Phase C (future):
  Design RFC → Prototype → Migration guide → Implementation
```

---

## Additional Fixes (Low Priority, Do Anytime)

| Item | Fix |
|------|-----|
| `RouteChannel.shared` deadlock risk | Replace `DispatchQueue.main.sync` with async pattern or require main-thread access |
| `SupplementaryRegistrationCache` thread safety | Add `@MainActor` or `NSLock` |
| `DefaultRouter` not `@MainActor` | Add `@MainActor` annotation |
| `_ShimmerLayer` deprecated API | Replace `UIScreen.main.scale` with `window?.screen.scale ?? UIScreen.main.scale` |
| `CellConfigAdapter` debug print | Remove `print("CellConfigAdapter deinit")` |
| `CompoundCancellable` thread safety | Add `NSLock` around token iteration in `cancel()` |
| Stale epoch `.drop` documentation | Document that long-running effects with `.drop` strategy will be rejected if any intent fires during execution |

---

## Regression Strategy

### Usage Audit Results

A full codebase audit determined actual usage of each affected API:

| API | Call Sites | In Sources | In Tests | In Demo | Regression Risk |
|-----|-----------|-----------|---------|---------|-----------------|
| `.delay(` | 0 | 0 | 0 | 0 | **None** |
| `.flatMapLatest(` | 0 | 0 | 0 | 0 | **None** |
| `ForEach(` | 0 (def only) | 0 | 0 | 0 | **None** |
| `SheetController` | 1 | 1 | 0 | 0 | Low |
| `.onRoute(` | 4 | 0 | 2 | 2 | Moderate |
| `showToast`/`ToastManager` | ~10 | 5 | 8 | 2 | Moderate |
| `DynamicContainerView` | 4 | 2 | 0 | 2 | Moderate |
| `.distinctUntilChanged()` | 6 | 4 | 1 | 1 | **High** |
| `cancelBag` | ~40 | ~28 | ~2 | ~3 | **High** (volume) |
| `outputStream`/`outputs` | 5 | 3 | 2 | 0 | **High** (critical path) |

### Concreteness Assessment

**Confirmed bugs (100% reproducible, no usage needed to trigger):**
- A1: Sheet onDismiss — any app using `SheetController.onDismiss` + dimming tap
- A2: Toast containment — any toast VC relying on lifecycle methods
- A4: `delay` shadowing — the parameter is provably dead code (read the source)
- A6: Sheet transform/constraint — fast gesture interruption causes visible jump

**Confirmed bugs (require specific usage pattern):**
- A3: `.onRoute` overwrite — only if called twice on same view (2 test sites use it once each, safe)
- A5: `flatMapLatest` race — only under concurrent emission (0 consumers exist)

**Defensive improvements (may never manifest in practice):**
- A7: CancelBag lazy init — all 40 usages are from main thread
- A8: CancelBag pruning — growth is bounded by view lifecycle
- A9: Router strong keys — only if router outlives nav controller
- A10: RuntimeScope child leak — only for long-lived parent scopes
- A11: Output buffer — only under burst of >50 outputs
- A12: Retain cycle docs — education, not a code fix

### Revised Risk Classification

Based on the audit, items are reclassified:

**Safe to fix (zero or trivial regression risk):**
- A1 (additive wiring, 1 call site)
- A2 (additive containment, tested path)
- A4 (0 consumers — nobody uses `.delay`)
- A5 (0 consumers — nobody uses `.flatMapLatest`)
- B18 (internal-only, no API change)

**Low risk (few consumers, existing tests cover the path):**
- A3 (2 test sites, both use `.onRoute` once — fix is about the double-call case)
- A6 (1 call site in Router, gesture behavior change needs manual QA)

**Medium risk (moderate consumer count, needs new tests first):**
- A7 (touches NSObject extension used by ~40 sites, but change is additive sync)
- A9 (1 internal consumer, but changes dictionary type)
- A10 (actor-internal, no public API change)
- A11 (changes stream buffer, affects runtime bridge)

**High risk (defer or make opt-in):**
- A8 (requires protocol change to `AnyCancellableLifecycle` — touches 40+ sites)
- B13/B16 (Property dedup — 6 sites already manually deduplicate; making it default could cause double-dedup or break notification-on-every-set expectations)
- B17 (lazy modifiers — changes timing of all modifier side effects, ~28 cancelBag sites affected)

### Regression Prevention Protocol

For each fix, in order:

1. **Run baseline:** `swift test` must pass before any changes
2. **Write regression test first:** Prove the current (broken) behavior exists, then fix it
3. **Verify no call-site breakage:** For items with consumers, grep for usage and verify each site is unaffected
4. **Run full suite after each fix:** `swift test` must pass after every individual commit
5. **Manual QA for gesture/animation items (A6):** Automated tests cannot fully validate visual continuity

### Items Removed or Deferred

| Item | Decision | Reason |
|------|----------|--------|
| A8 (CancelBag pruning) | **Deferred to Phase B** | Requires `AnyCancellableLifecycle` protocol change; high surface area |
| A12 (retain cycle docs) | **Deferred** | Education, not a code fix; do alongside Phase B |
| B13/B16 (Property dedup) | **Opt-in only** | Must not change default behavior; add `Property(_, deduplicate: true)` flag |
| B17 (lazy modifiers) | **Removed** | Regression risk too high for benefit; belongs in Phase C |

---

## Success Criteria

- All existing tests pass after each fix (`swift test` green)
- New regression test added for each Phase A item before the fix is applied
- No API breaking changes in Phase A
- Phase B items are opt-in or additive (no default behavior changes)
- `swift build` and `swift test` green at every commit
- Items with >0 consumers verified at each call site post-fix
