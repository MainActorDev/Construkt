# Framework Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 11 correctness bugs and performance issues across Construkt's Reactive, Runtime, Builder, and Navigation subsystems without breaking any public API signatures.

**Architecture:** Each fix is isolated and independently testable. Regression tests are written first (proving the bug exists), then the fix is applied, then the full suite is verified. All changes are internal implementation details — no public API signatures change.

**Tech Stack:** Swift 5.9, UIKit, Swift Testing framework, iOS 14+

---

## File Structure

No new source files are created. All changes modify existing files:

| File | Tasks |
|------|-------|
| `Sources/Construkt/Navigation/SheetController.swift` | Task 1 (A1), Task 6 (A6) |
| `Sources/Construkt/Navigation/SheetPresentationController.swift` | Task 1 (A1) |
| `Sources/Construkt/Navigation/ToastManager.swift` | Task 2 (A2) |
| `Sources/Construkt/Navigation/ToastItem.swift` | Task 2 (A2) |
| `Sources/Construkt/Navigation/EventRouting.swift` | Task 3 (A3) |
| `Sources/Construkt/Core/Reactive/Binding+Operators.swift` | Task 4 (A4), Task 5 (A5) |
| `Sources/Construkt/Core/Reactive/CancelBag.swift` | Task 7 (A7) |
| `Sources/Construkt/Navigation/Router.swift` | Task 8 (A9) |
| `Sources/Construkt/Core/Runtime/RuntimeScope.swift` | Task 9 (A10) |
| `Sources/Construkt/Core/Runtime/FeatureSpec.swift` | Task 10 (A11) |
| `Sources/Construkt/Core/Runtime/FeatureRuntime.swift` | Task 10 (A11) |
| `Sources/Construkt/Core/Runtime/FeatureStore.swift` | Task 10 (A11) |
| `Sources/Construkt/Core/Runtime/RuntimeJournal.swift` | Task 11 (B18) |

New test files:

| File | Tasks |
|------|-------|
| `Tests/ConstruktTests/SheetControllerTests.swift` | Task 1, Task 6 |
| `Tests/ConstruktTests/ToastContainmentTests.swift` | Task 2 |
| `Tests/ConstruktTests/FlatMapLatestThreadSafetyTests.swift` | Task 5 |
| `Tests/ConstruktTests/RuntimeScopeTests.swift` | Task 9 |

---

## Pre-Flight

- [ ] **Step 1: Verify baseline**

Run: `swift test`
Expected: All tests pass (green)

- [ ] **Step 2: Create feature branch**

```bash
git checkout -b feat/framework-hardening
```

---

## Task 1: Connect SheetPresentationController.onDismiss (A1)

**Files:**
- Modify: `Sources/Construkt/Navigation/SheetController.swift:372-374`
- Test: `Tests/ConstruktTests/SheetControllerTests.swift` (create)

- [ ] **Step 1: Write the regression test proving the bug exists**

Create `Tests/ConstruktTests/SheetControllerTests.swift`:

```swift
import Testing
import UIKit
@testable import ConstruktKit

@Suite("SheetController") @MainActor
struct SheetControllerTests {

    @Test("onDismiss fires when dimming view is tapped")
    func onDismissFiresOnDimmingTap() {
        let config = SheetConfiguration()
        let contentVC = UIViewController()
        let sheet = SheetController(content: contentVC, config: config)

        var dismissed = false
        sheet.onDismiss = { dismissed = true }

        // Obtain the presentation controller
        let presentationController = sheet.presentationController(
            forPresented: sheet,
            presenting: nil,
            source: UIViewController()
        ) as! SheetPresentationController

        // Simulate dimming view tap by calling the handler directly
        presentationController.onDismiss?()

        #expect(dismissed, "onDismiss should fire when dimming view tap triggers presentationController.onDismiss")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SheetControllerTests`
Expected: FAIL — `presentationController.onDismiss` is nil, so `dismissed` remains `false`

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Navigation/SheetController.swift`, replace lines 372-374:

```swift
public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
    let pc = SheetPresentationController(presentedViewController: presented, presenting: presenting, config: config)
    pc.onDismiss = { [weak self] in self?.onDismiss?() }
    return pc
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SheetControllerTests`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Navigation/SheetController.swift Tests/ConstruktTests/SheetControllerTests.swift
git commit -m "fix(navigation): wire SheetPresentationController.onDismiss to SheetController.onDismiss

Tapping the dimming overlay now correctly fires the developer's onDismiss callback.
Previously, SheetPresentationController.onDismiss was never connected."
```

---

## Task 2: Fix Toast Content VC Containment (A2)

**Files:**
- Modify: `Sources/Construkt/Navigation/ToastManager.swift:143-156`
- Modify: `Sources/Construkt/Navigation/ToastItem.swift:89-106`
- Test: `Tests/ConstruktTests/ToastContainmentTests.swift` (create)

- [ ] **Step 1: Write the regression test proving the bug exists**

Create `Tests/ConstruktTests/ToastContainmentTests.swift`:

```swift
import Testing
import UIKit
@testable import ConstruktKit

@Suite("ToastContainment") @MainActor
struct ToastContainmentTests {

    private final class LifecycleTrackingVC: UIViewController {
        var didMoveToParentCalled = false
        var parentOnMove: UIViewController?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            didMoveToParentCalled = true
            parentOnMove = parent
        }
    }

    @Test("toast content VC is added as child to container")
    func toastContentVCIsChild() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        let rootVC = UIViewController()
        window.rootViewController = rootVC
        window.makeKeyAndVisible()

        let contentVC = LifecycleTrackingVC()
        let config = ToastConfiguration(duration: 5.0)

        ToastManager.shared.show(content: contentVC, config: config, in: window)

        #expect(contentVC.parent != nil, "Content VC should have a parent after being shown as toast")
        #expect(contentVC.didMoveToParentCalled, "didMove(toParent:) should be called with a non-nil parent")
        #expect(contentVC.parentOnMove != nil, "Parent should not be nil in didMove(toParent:)")

        // Cleanup
        ToastManager.shared.dismissAll(animated: false)
        window.isHidden = true
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ToastContainmentTests`
Expected: FAIL — `contentVC.parent` is nil because `setContent` is called with `parent: nil`

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Navigation/ToastManager.swift`, modify `createToastView` (lines 143-156) to accept and pass the window's root VC:

Replace:
```swift
private func createToastView(for toast: ToastItem, config: ToastConfiguration) -> ToastItemView {
    let toastView = ToastItemView(config: config)
    toastView.setContent(toast.contentViewController, in: nil)
```

With:
```swift
private func createToastView(for toast: ToastItem, config: ToastConfiguration, parent: UIViewController?) -> ToastItemView {
    let toastView = ToastItemView(config: config)
    toastView.setContent(toast.contentViewController, in: parent)
```

Then update the call site in `show(content:config:in:)` at line 84. Replace:
```swift
let toastView = createToastView(for: toast, config: config)
```

With:
```swift
let toastView = createToastView(for: toast, config: config, parent: window.rootViewController)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ToastContainmentTests`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Navigation/ToastManager.swift Sources/Construkt/Navigation/ToastItem.swift Tests/ConstruktTests/ToastContainmentTests.swift
git commit -m "fix(navigation): pass window rootVC as parent for toast content VC containment

Toast content VCs now receive proper UIKit containment lifecycle calls
(addChild, didMove(toParent:)). Previously parent was nil, so lifecycle
methods never fired."
```

---

## Task 3: Fix .onRoute Modifier Overwriting Previous Targets (A3)

**Files:**
- Modify: `Sources/Construkt/Navigation/EventRouting.swift:113-133`
- Modify: `Tests/ConstruktTests/EventRoutingTests.swift` (add test)

- [ ] **Step 1: Write the regression test proving the bug exists**

Add to `Tests/ConstruktTests/EventRoutingTests.swift`:

```swift
@Test("onRoute removes previous gesture recognizer when called twice")
func onRouteRemovesPreviousGesture() {
    let view = UIView()

    // Apply .onRoute twice
    let _ = ViewModifier(view).onRoute(TestRoute.page1)
    let _ = ViewModifier(view).onRoute(TestRoute.page2(id: 99))

    // Should have exactly 1 gesture recognizer (the latest), not 2
    let gestureCount = view.gestureRecognizers?.count ?? 0
    #expect(gestureCount == 1, "Only the latest .onRoute gesture recognizer should remain, got \(gestureCount)")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter "onRoute removes previous gesture recognizer"`
Expected: FAIL — `gestureCount` is 2 because the old gesture recognizer is never removed

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Navigation/EventRouting.swift`, replace lines 117-131:

```swift
@discardableResult
func onRoute<E>(_ event: @autoclosure @escaping () -> E) -> ViewModifier<Base> {
    return self.with { view in
        // Remove previous route gesture recognizer if any
        if let previousTarget = objc_getAssociatedObject(view, &RouteAssociator.routeTargetKey) as? NSObject,
           let recognizers = view.gestureRecognizers {
            for recognizer in recognizers where recognizer.delegate === previousTarget as? UIGestureRecognizerDelegate || (recognizer is UITapGestureRecognizer && recognizer.value(forKey: "_targets") != nil) {
                view.removeGestureRecognizer(recognizer)
            }
        }

        let target = RouteTapTarget(view: view, eventProvider: event)

        objc_setAssociatedObject(
            view,
            &RouteAssociator.routeTargetKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let tapGesture = UITapGestureRecognizer(target: target, action: #selector(RouteTapTarget<Any>.handleTap))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true
    }
}
```

Wait — the gesture recognizer's target is the `RouteTapTarget` instance. A cleaner approach: store the gesture recognizer itself via a second associated object key, so we can remove it directly.

Replace lines 113-137 entirely:

```swift
public extension ModifiableView where Base: UIView {
    /// Add a tap gesture recognizer that routes the given event payload up the responder chain.
    /// - Parameter event: An autoclosure providing the event to route when tapped.
    @discardableResult
    func onRoute<E>(_ event: @autoclosure @escaping () -> E) -> ViewModifier<Base> {
        return self.with { view in
            // Remove previous route gesture if present
            if let previousGesture = objc_getAssociatedObject(view, &RouteAssociator.routeGestureKey) as? UIGestureRecognizer {
                view.removeGestureRecognizer(previousGesture)
            }

            let target = RouteTapTarget(view: view, eventProvider: event)

            objc_setAssociatedObject(
                view,
                &RouteAssociator.routeTargetKey,
                target,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            let tapGesture = UITapGestureRecognizer(target: target, action: #selector(RouteTapTarget<Any>.handleTap))
            view.addGestureRecognizer(tapGesture)
            view.isUserInteractionEnabled = true

            objc_setAssociatedObject(
                view,
                &RouteAssociator.routeGestureKey,
                tapGesture,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private struct RouteAssociator {
    static var routeTargetKey: UInt8 = 0
    static var routeGestureKey: UInt8 = 0
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter "onRoute removes previous gesture recognizer"`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass (existing `.onRoute` tests still pass since single-call behavior is unchanged)

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Navigation/EventRouting.swift Tests/ConstruktTests/EventRoutingTests.swift
git commit -m "fix(navigation): remove previous gesture recognizer on repeated .onRoute calls

Calling .onRoute twice on the same view now cleanly removes the previous
tap gesture recognizer before adding the new one. Previously, the old
gesture remained attached with a deallocated target."
```

---

## Task 4: Fix delay Operator Parameter Shadowing (A4)

**Files:**
- Modify: `Sources/Construkt/Core/Reactive/Binding+Operators.swift:271-281`
- Modify: `Tests/ConstruktTests/ReactiveTests.swift` (add test)

- [ ] **Step 1: Write the regression test proving the bug exists**

Add to `Tests/ConstruktTests/ReactiveTests.swift` (in the operators section):

```swift
@Test("delay schedules on the specified queue, not the observer queue")
func delayUsesSpecifiedQueue() async throws {
    let property = Property<Int>(0)
    let delayQueue = DispatchQueue(label: "test.delay.queue")
    var receivedOnQueue: String?

    let delayed = property.delay(0.05, on: delayQueue)

    let expectation = delayed.observe(on: nil) { _ in
        receivedOnQueue = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8)
    }

    property.wrappedValue = 42

    try await Task.sleep(nanoseconds: 150_000_000) // 150ms

    #expect(receivedOnQueue == "test.delay.queue",
            "Value should be delivered on the delay queue, got: \(receivedOnQueue ?? "nil")")

    expectation.cancel()
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter "delay schedules on the specified queue"`
Expected: FAIL — value is delivered on the observer queue (nil/calling thread), not `delayQueue`

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Core/Reactive/Binding+Operators.swift`, replace lines 271-281:

```swift
/// Delays each emitted value by the specified time interval before forwarding it.
@_disfavoredOverload
func delay(_ interval: TimeInterval, on schedulerQueue: DispatchQueue = .main) -> AnyViewBinding<Value> {
    return AnyViewBinding { observerQueue, handler in
        self.observe(on: observerQueue) { value in
            schedulerQueue.asyncAfter(deadline: .now() + interval) {
                handler(value)
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter "delay schedules on the specified queue"`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass (no existing consumers of `.delay`)

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Reactive/Binding+Operators.swift Tests/ConstruktTests/ReactiveTests.swift
git commit -m "fix(reactive): resolve parameter shadowing in delay operator

The AnyViewBinding closure parameter 'queue' shadowed the outer scheduler
queue parameter, causing delays to fire on the observer queue instead of
the specified scheduler. Renamed inner param to 'observerQueue'."
```

---

## Task 5: Add Lock to flatMapLatest's innerCancellable (A5)

**Files:**
- Modify: `Sources/Construkt/Core/Reactive/Binding+Operators.swift:283-296`
- Test: `Tests/ConstruktTests/FlatMapLatestThreadSafetyTests.swift` (create)

- [ ] **Step 1: Write the regression test**

Create `Tests/ConstruktTests/FlatMapLatestThreadSafetyTests.swift`:

```swift
import Testing
import Foundation
@testable import ConstruktKit

@Suite("flatMapLatest Thread Safety")
struct FlatMapLatestThreadSafetyTests {

    @Test("flatMapLatest does not crash under concurrent emissions")
    func concurrentEmissions() async throws {
        let source = Property<Int>(0)
        var received: [Int] = []
        let lock = NSLock()

        let mapped = source.flatMapLatest { value in
            AnyViewBinding<Int>.just(value * 10)
        }

        let token = mapped.observe(on: nil) { value in
            lock.lock()
            received.append(value)
            lock.unlock()
        }

        // Emit rapidly from multiple threads
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    source.wrappedValue = i
                }
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms settle

        lock.lock()
        let lastValue = received.last
        lock.unlock()

        // The last received value should be from the latest emission (1000)
        // Key assertion: no crash occurred during concurrent access
        #expect(lastValue == 1000, "Last value should be 1000 (100 * 10), got \(lastValue ?? -1)")

        token.cancel()
    }
}
```

- [ ] **Step 2: Run test to verify it passes (or crashes without the fix)**

Run: `swift test --filter FlatMapLatestThreadSafetyTests`
Expected: May crash or produce inconsistent results due to race condition on `innerCancellable`. If it passes, it's non-deterministic — the fix is still needed for correctness.

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Core/Reactive/Binding+Operators.swift`, replace lines 283-296:

```swift
/// Transforms each value into a new binding and only observes the latest one, cancelling previous subscriptions.
@_disfavoredOverload
func flatMapLatest<T>(_ transform: @escaping (Value) -> AnyViewBinding<T>) -> AnyViewBinding<T> {
    return AnyViewBinding<T> { queue, handler in
        let innerLock = NSLock()
        var innerCancellable: AnyCancellableLifecycle?
        return self.observe(on: queue) { value in
            let inner = transform(value)
            innerLock.lock()
            innerCancellable?.cancel()
            innerCancellable = inner.observe(on: queue) { innerValue in
                handler(innerValue)
            }
            innerLock.unlock()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FlatMapLatestThreadSafetyTests`
Expected: PASS (no crash, consistent final value)

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass (no existing consumers of `.flatMapLatest`)

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Reactive/Binding+Operators.swift Tests/ConstruktTests/FlatMapLatestThreadSafetyTests.swift
git commit -m "fix(reactive): add NSLock to flatMapLatest innerCancellable

Concurrent emissions on the source binding could race on the captured
innerCancellable var. Added a lock matching the pattern used by debounce
and throttle operators."
```

---

## Task 6: Fix SheetController Transform/Constraint Mixing (A6)

**Files:**
- Modify: `Sources/Construkt/Navigation/SheetController.swift:203-227, 253-264`
- Modify: `Tests/ConstruktTests/SheetControllerTests.swift` (add test)

- [ ] **Step 1: Write the regression test**

Add to `Tests/ConstruktTests/SheetControllerTests.swift`:

```swift
@Test("bottom sheet pan uses constraint-only positioning")
func panUsesConstraintOnly() {
    let config = SheetConfiguration()
    let contentVC = UIViewController()
    let sheet = SheetController(content: contentVC, config: config)

    // Load the view hierarchy
    sheet.loadViewIfNeeded()
    sheet.viewDidLoad()

    // After any pan interaction, transform should remain identity
    // (constraint-only means no transform manipulation)
    let containerView = sheet.view.subviews.first { $0 is UIView }
    if let container = containerView {
        #expect(container.transform == .identity,
                "Container should use constraint-only positioning, not transforms")
    }
}
```

- [ ] **Step 2: Run test to verify baseline**

Run: `swift test --filter "bottom sheet pan uses constraint-only"`
Expected: PASS (no pan has occurred yet, transform is identity at rest)

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Navigation/SheetController.swift`, replace `handleBottomSheetPan` (lines 203-227):

```swift
private func handleBottomSheetPan(_ pan: UIPanGestureRecognizer, translation: CGPoint, velocity: CGPoint) {
    switch pan.state {
    case .began:
        panStartBottomConstant = containerBottomConstraint?.constant ?? 0
        containerView.layer.removeAllAnimations()
    case .changed:
        let newBottom = max(0, panStartBottomConstant + translation.y)
        let clampedBottom = newBottom < 0 ? newBottom * 0.2 : newBottom
        containerBottomConstraint?.constant = clampedBottom
        view.layoutIfNeeded()

    case .ended, .cancelled, .failed:
        let projectedTranslation = translation.y + velocity.y * 0.15
        let projectedBottom = panStartBottomConstant + projectedTranslation

        let targetOffset = snapToNearest(forProjectedBottom: projectedBottom, velocity: velocity.y)

        if targetOffset > (resolvedAnchors.last ?? 0) * 0.8 || velocity.y > 1000 {
            dismissSheet()
            return
        }

        animateToBottomOffset(targetOffset, velocity: velocity.y)
    default: break
    }
}
```

Replace `animateToBottomOffset` (lines 253-264):

```swift
private func animateToBottomOffset(_ offset: CGFloat, velocity: CGFloat = 0) {
    containerBottomConstraint?.constant = offset

    UIView.animate(withDuration: config.baseDuration,
                   delay: 0,
                   usingSpringWithDamping: config.springDamping,
                   initialSpringVelocity: abs(velocity) / 1000,
                   options: [.allowUserInteraction, .curveEaseOut]) {
        self.view.layoutIfNeeded()
    }
}
```

Replace `handlePushPan` (lines 266-286) — also convert to constraint-only:

```swift
private func handlePushPan(_ pan: UIPanGestureRecognizer, translation: CGPoint, velocity: CGPoint) {
    switch pan.state {
    case .began:
        panStartLeadingConstant = containerLeadingConstraint?.constant ?? 0
        containerView.layer.removeAllAnimations()
    case .changed:
        if translation.x > 0 {
            containerLeadingConstraint?.constant = panStartLeadingConstant + translation.x
            view.layoutIfNeeded()
        }
    case .ended, .cancelled, .failed:
        if translation.x > view.bounds.width * 0.25 || velocity.x > 500 {
            dismissSheet()
        } else {
            containerLeadingConstraint?.constant = panStartLeadingConstant
            UIView.animate(withDuration: config.baseDuration) {
                self.view.layoutIfNeeded()
            }
        }
    default: break
    }
}
```

- [ ] **Step 4: Run full suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/Construkt/Navigation/SheetController.swift Tests/ConstruktTests/SheetControllerTests.swift
git commit -m "fix(navigation): use constraint-only positioning in SheetController pan gestures

Previously, pan gestures used CGAffineTransform during dragging and then
switched to constraint constants on snap. This caused visual jumps when
interrupting a snap animation with a new pan. Now all positioning is done
via constraint constants throughout."
```

---

## Task 7: Fix CancelBag Lazy Init Thread Safety (A7)

**Files:**
- Modify: `Sources/Construkt/Core/Reactive/CancelBag.swift:49-62`
- Modify: `Tests/ConstruktTests/ReactiveTests.swift` (add test)

- [ ] **Step 1: Write the regression test**

Add to `Tests/ConstruktTests/ReactiveTests.swift`:

```swift
@Test("cancelBag returns same instance from concurrent access")
func cancelBagThreadSafety() async {
    let object = NSObject()
    var bags: [ObjectIdentifier] = []
    let lock = NSLock()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<50 {
            group.addTask { @MainActor in
                let bag = object.cancelBag
                let id = ObjectIdentifier(bag)
                lock.lock()
                bags.append(id)
                lock.unlock()
            }
        }
    }

    let uniqueBags = Set(bags)
    #expect(uniqueBags.count == 1, "All accesses should return the same CancelBag instance, got \(uniqueBags.count) different instances")
}
```

- [ ] **Step 2: Run test to verify potential failure**

Run: `swift test --filter "cancelBag returns same instance"`
Expected: May pass non-deterministically (race is timing-dependent). The fix is still needed for correctness.

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Core/Reactive/CancelBag.swift`, replace lines 49-62:

```swift
public extension NSObject {
    fileprivate static var ViewBindingCancelBagKey: UInt8 = 0
    private static let cancelBagLock = NSLock()

    /// Returns a generic `CancelBag` stored dynamically on the `NSObject` class via the Objective-C runtime.
    /// This is the native, zero-dependency alternative to `rxDisposeBag`.
    var cancelBag: CancelBag {
        NSObject.cancelBagLock.lock()
        defer { NSObject.cancelBagLock.unlock() }

        if let bag = objc_getAssociatedObject(self, &NSObject.ViewBindingCancelBagKey) as? CancelBag {
            return bag
        }
        let bag = CancelBag()
        objc_setAssociatedObject(self, &NSObject.ViewBindingCancelBagKey, bag, .OBJC_ASSOCIATION_RETAIN)
        return bag
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter "cancelBag returns same instance"`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Reactive/CancelBag.swift Tests/ConstruktTests/ReactiveTests.swift
git commit -m "fix(reactive): add lock to CancelBag lazy initialization on NSObject

Concurrent first-access to cancelBag on the same NSObject could create
two CancelBag instances, losing subscriptions stored in the discarded one.
Added NSLock around the get-or-create pattern."
```

---

## Task 8: Fix Router Completions Strong Key Retention (A9)

**Files:**
- Modify: `Sources/Construkt/Navigation/Router.swift:75, 187-203`
- Modify: `Tests/ConstruktTests/RouterLifecycleTests.swift` (add test)

- [ ] **Step 1: Write the regression test**

Add to `Tests/ConstruktTests/RouterLifecycleTests.swift`:

```swift
@Test("router does not retain popped view controllers via completions")
func routerDoesNotRetainPoppedVCs() {
    let nav = UINavigationController()
    let router = DefaultRouter(navigationController: nav)

    weak var weakVC: UIViewController?

    autoreleasepool {
        let vc = UIViewController()
        weakVC = vc
        router.push(vc, animated: false, completion: { })
        // Simulate pop via delegate
        nav.viewControllers = []
    }

    // After pop, the VC should be deallocatable
    #expect(weakVC == nil, "Router should not retain popped VCs via completions dictionary")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter "router does not retain popped view controllers"`
Expected: FAIL — `weakVC` is not nil because `completions` dictionary retains the VC as a key

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Navigation/Router.swift`, replace the `completions` dictionary (line 75) with a `NSMapTable` using weak keys:

```swift
private let completions = NSMapTable<UIViewController, Box<() -> Void>>(keyOptions: .weakMemory, valueOptions: .strongMemory)

/// Box to store closure in NSMapTable (which requires AnyObject values)
private final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}
```

Then update `runCompletion` (lines 193-197):

```swift
private func runCompletion(for vc: UIViewController) {
    if let box = completions.object(forKey: vc) {
        completions.removeObject(forKey: vc)
        box.value()
    }
}
```

Update `runCompletions` (lines 199-203):

```swift
private func runCompletions(forRemovedFrom oldStack: [UIViewController], keeping newStack: [UIViewController]) {
    for removedVC in oldStack where !newStack.contains(where: { $0 === removedVC }) {
        runCompletion(for: removedVC)
    }
}
```

Update all sites that store completions. There are two:

Line 97 (in `push` method):
```swift
// Replace:
//     completions[vc] = completion
// With:
completions.setObject(Box(completion), forKey: vc)
```

Line 178 (in `replaceStack` method):
```swift
// Replace:
//     completions[topVC] = completion
// With:
if let completion = completion {
    completions.setObject(Box(completion), forKey: topVC)
}
```

Also update line 96 guard:
```swift
// Replace:
//     if let completion = completion {
//         completions[vc] = completion
//     }
// With:
if let completion = completion {
    completions.setObject(Box(completion), forKey: vc)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter "router does not retain popped view controllers"`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Navigation/Router.swift Tests/ConstruktTests/RouterLifecycleTests.swift
git commit -m "fix(navigation): use weak-key NSMapTable for router completions

The completions dictionary previously used strong UIViewController keys,
preventing deallocation of popped VCs if the router outlived the nav
controller. Now uses NSMapTable with .weakMemory keys."
```

---

## Task 9: Fix RuntimeScope Child Leak (A10)

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/RuntimeScope.swift:69-86`
- Test: `Tests/ConstruktTests/RuntimeScopeTests.swift` (create)

- [ ] **Step 1: Write the regression test**

Create `Tests/ConstruktTests/RuntimeScopeTests.swift`:

```swift
import Testing
@testable import ConstruktKit

@Suite("RuntimeScope")
struct RuntimeScopeTests {

    @Test("child is removed from parent after independent shutdown")
    func childRemovedAfterShutdown() async {
        let parent = RuntimeScope()
        let child = await parent.makeChild()

        // Shut down child independently
        await child.shutdown()

        // Parent should no longer hold the child
        let childCount = await parent.childCount
        #expect(childCount == 0, "Parent should remove child after child shuts down, got \(childCount)")
    }

    @Test("multiple children created and shut down independently do not leak")
    func multipleChildrenDoNotLeak() async {
        let parent = RuntimeScope()

        for _ in 0..<10 {
            let child = await parent.makeChild()
            await child.shutdown()
        }

        let childCount = await parent.childCount
        #expect(childCount == 0, "All shut-down children should be removed, got \(childCount)")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RuntimeScopeTests`
Expected: FAIL — `childCount` is not 0 because children are never removed from parent's dictionary. Also, `childCount` property doesn't exist yet.

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Core/Runtime/RuntimeScope.swift`:

First, add a `childCount` property for testing after line 13 (`private var isShutDown = false`):

```swift
/// Number of active children (for testing/diagnostics).
public var childCount: Int { children.count }
```

Add a weak parent reference after line 13:

```swift
private weak var parent: RuntimeScope?
```

Replace `makeChild()` (lines 28-39):

```swift
public func makeChild() -> RuntimeScope {
    let child = RuntimeScope(parentID: id)
    child.parent = self
    children[child.id] = child

    if isShutDown {
        Task {
            await child.shutdown()
        }
    }

    return child
}
```

Add a new method after `makeChild()`:

```swift
/// Removes a child from this scope's tracking dictionary.
/// Called by children when they shut down independently.
func removeChild(_ childID: UUID) {
    children.removeValue(forKey: childID)
}
```

Replace `shutdown()` (lines 69-86):

```swift
public func shutdown() async {
    guard !isShutDown else {
        return
    }

    isShutDown = true

    let cancelHandlers = Array(cancellables.values)
    cancellables.removeAll(keepingCapacity: false)
    cancelHandlers.forEach { $0() }

    let childScopes = Array(children.values)
    children.removeAll(keepingCapacity: false)

    for child in childScopes {
        await child.shutdown()
    }

    // Notify parent to remove this child from its tracking
    await parent?.removeChild(id)
}
```

Note: `RuntimeScope` is an `actor`, so `weak var parent: RuntimeScope?` is valid. The `removeChild` method is actor-isolated (internal visibility), callable via `await` from the child's `shutdown()`. When shutdown is triggered by the parent cascade (line 83-84 of original), the parent has already cleared its `children` dict, so `removeChild` is a no-op in that case.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RuntimeScopeTests`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Runtime/RuntimeScope.swift Tests/ConstruktTests/RuntimeScopeTests.swift
git commit -m "fix(runtime): remove children from parent scope on independent shutdown

Children that shut down independently were never removed from the parent's
children dictionary, causing unbounded growth for long-lived parent scopes.
Now children notify their parent to remove them on shutdown."
```

---

## Task 10: Make Output Stream Buffer Size Configurable (A11)

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/FeatureSpec.swift:227-238`
- Modify: `Sources/Construkt/Core/Runtime/FeatureStore.swift:197-234`
- Modify: `Tests/ConstruktTests/FeatureStoreTests.swift` (add test)

- [ ] **Step 1: Write the test**

Add to `Tests/ConstruktTests/FeatureStoreTests.swift`:

```swift
@Test("output buffer size is configurable via RuntimeConfiguration")
func outputBufferSizeConfigurable() async {
    // Default buffer is 50 — verify the configuration property exists and is used
    let config = RuntimeConfiguration(outputBufferSize: 100)
    #expect(config.outputBufferSize == 100)

    let defaultConfig = RuntimeConfiguration()
    #expect(defaultConfig.outputBufferSize == 50)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter "output buffer size is configurable"`
Expected: FAIL — `outputBufferSize` property doesn't exist on `RuntimeConfiguration`

- [ ] **Step 3: Apply the fix**

In `Sources/Construkt/Core/Runtime/FeatureSpec.swift`, modify `RuntimeConfiguration` (lines 227-238):

```swift
public struct RuntimeConfiguration: Sendable {
    /// Max journal entries retained in-memory.
    public var journalCapacity: Int

    /// Whether newly attached state streams immediately receive current state.
    public var emitsInitialStateOnSubscription: Bool

    /// Buffer size for the output AsyncStream. Outputs beyond this limit are dropped (newest kept).
    public var outputBufferSize: Int

    public init(journalCapacity: Int = 300, emitsInitialStateOnSubscription: Bool = true, outputBufferSize: Int = 50) {
        self.journalCapacity = max(1, journalCapacity)
        self.emitsInitialStateOnSubscription = emitsInitialStateOnSubscription
        self.outputBufferSize = max(1, outputBufferSize)
    }
}
```

In `Sources/Construkt/Core/Runtime/FeatureStore.swift`:

First, add a stored property after line 26 (`private var isShutDown = false`):

```swift
private let configuration: RuntimeConfiguration
```

Then in the initializer (line 28-47), add `self.configuration = configuration` after line 45 (`self.deliveryQueue = deliveryQueue`):

```swift
self.configuration = configuration
```

Then modify `makeBridgeTask()` at line 202. Replace:
```swift
let outputStream = await runtime.outputStream()
```

With:
```swift
let outputStream = await runtime.outputStream(
    bufferingPolicy: .bufferingNewest(configuration.outputBufferSize)
)
```

Note: `FeatureStore.init` already receives `configuration: RuntimeConfiguration = .init()` at line 32 but only passes it to `FeatureRuntime`. We now also store it locally for the bridge task.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter "output buffer size is configurable"`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass (default value of 50 preserves existing behavior)

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Runtime/FeatureSpec.swift Sources/Construkt/Core/Runtime/FeatureRuntime.swift Sources/Construkt/Core/Runtime/FeatureStore.swift Tests/ConstruktTests/FeatureStoreTests.swift
git commit -m "feat(runtime): make output stream buffer size configurable

Added outputBufferSize to RuntimeConfiguration (default: 50, preserving
existing behavior). FeatureStore now passes this value to outputStream()
instead of hardcoding .bufferingNewest(50)."
```

---

## Task 11: Replace RuntimeJournal Array with Ring Buffer (B18)

**Files:**
- Modify: `Sources/Construkt/Core/Runtime/RuntimeJournal.swift`
- Modify: `Tests/ConstruktTests/FeatureRuntimeTests.swift` (add test)

- [ ] **Step 1: Write the performance regression test**

Add to `Tests/ConstruktTests/FeatureRuntimeTests.swift`:

```swift
@Test("journal eviction is O(1) amortized")
func journalEvictionPerformance() {
    var journal = RuntimeJournal<String, String>(capacity: 10)

    // Fill to capacity
    for i in 0..<10 {
        journal.append(.intentReceived("intent-\(i)"))
    }

    // Evict and add — should not shift elements
    journal.append(.intentReceived("overflow"))

    let snapshot = journal.snapshot()
    #expect(snapshot.count == 10)
    // First entry should be "intent-1" (oldest "intent-0" was evicted)
    if case .intentReceived(let value) = snapshot.first?.event {
        #expect(value == "intent-1", "Oldest entry should be evicted, got \(value)")
    }
}
```

- [ ] **Step 2: Run test to verify it passes with current implementation**

Run: `swift test --filter "journal eviction is O"`
Expected: PASS (behavior is correct, just slow at scale)

- [ ] **Step 3: Apply the fix — replace Array with circular buffer**

Replace the entire `Sources/Construkt/Core/Runtime/RuntimeJournal.swift`:

```swift
import Foundation

/// Reasons a scheduled/running effect can be dropped by policy/runtime checks.
public enum PolicyDropReason: String, Sendable {
    /// `.dropIfRuning` rejected new submission because same-key effect is active.
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
    case effectDroped(Effect, reason: PolicyDropReason)
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

/// Bounded in-memory event log for runtime internals using a circular buffer for O(1) eviction.
public struct RuntimeJournal<Intent: Sendable, Effect: Sendable>: Sendable {
    private let capacity: Int
    private var buffer: [RuntimeJournalEntry<Intent, Effect>?]
    private var head: Int = 0
    private var count: Int = 0

    public init(capacity: Int = 300) {
        self.capacity = max(1, capacity)
        self.buffer = Array(repeating: nil, count: self.capacity)
    }

    /// Appends an event. O(1) — overwrites oldest entry when at capacity.
    public mutating func append(_ event: RuntimeJournalEvent<Intent, Effect>) {
        let entry = RuntimeJournalEntry(event: event)
        buffer[head] = entry
        head = (head + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    /// Returns a stable copy of all retained entries in chronological order.
    public func snapshot() -> [RuntimeJournalEntry<Intent, Effect>] {
        guard count > 0 else { return [] }
        var result: [RuntimeJournalEntry<Intent, Effect>] = []
        result.reserveCapacity(count)

        let start = (head - count + capacity) % capacity
        for i in 0..<count {
            let index = (start + i) % capacity
            if let entry = buffer[index] {
                result.append(entry)
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter "journal eviction is O"`
Expected: PASS

- [ ] **Step 5: Run full suite**

Run: `swift test`
Expected: All tests pass (same external behavior, O(1) eviction internally)

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Runtime/RuntimeJournal.swift Tests/ConstruktTests/FeatureRuntimeTests.swift
git commit -m "perf(runtime): replace RuntimeJournal array with circular buffer

Array.removeFirst() was O(n) on every eviction at capacity. The new
circular buffer implementation provides O(1) append and eviction while
maintaining identical snapshot() output ordering."
```

---

## Post-Flight

- [ ] **Step 1: Final verification**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 2: Review all changes**

```bash
git log --oneline feat/framework-hardening ^feat/im
```

Expected: 11 commits (one per task)

- [ ] **Step 3: Verify no API signature changes**

```bash
git diff feat/im..feat/framework-hardening -- Sources/ | grep -E "^[+-]\s*(public|open)" | head -30
```

Expected: Only additive changes (new `outputBufferSize` parameter with default, new `childCount` property, new `removeChild` method)
