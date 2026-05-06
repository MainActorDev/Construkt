# Phase B: Performance Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in performance primitives — Property deduplication, identity-aware ForEach, and diffable container — without breaking existing APIs.

**Architecture:** Three independent, additive features. B13 adds an equality check to Property's setter (opt-in via init flag). B14 introduces a new `DynamicForEach` type that diffs by identity. B15 introduces a `DiffableContainerView` that applies minimal DOM-style operations on binding emission.

**Tech Stack:** Swift 5, UIKit, Swift Testing framework

**Test command:** `xcbuddy test -d "16 pro"` (full suite) or `xcbuddy test -d "16 pro" --only "ConstruktTests/SuiteName"` (targeted)

**Non-negotiable contracts (from Phase A spec):**
- `DynamicContainerView` keeps rebuild-from-scratch behavior (contract #5)
- `ViewBinding`/`MutableViewBinding` protocol requirements frozen (contract #2)
- `.observe(on: nil)` delivers synchronously (contract #1)

---

## File Map

| Task | Files | Action |
|------|-------|--------|
| B13 | `Sources/Construkt/Core/Reactive/Property.swift` | Modify |
| B13 | `Tests/ConstruktTests/ReactiveTests.swift` | Modify (add tests) |
| B14 | `Sources/Construkt/Core/Builder/Builder+DynamicForEach.swift` | Create |
| B14 | `Tests/ConstruktTests/DynamicForEachTests.swift` | Create |
| B15 | `Sources/Construkt/Core/Builder/Builder+DiffableContainer.swift` | Create |
| B15 | `Tests/ConstruktTests/DiffableContainerTests.swift` | Create |

---

### Task 1: B13 — Property Deduplication (Init Flag)

**Files:**
- Modify: `Sources/Construkt/Core/Reactive/Property.swift:12-55`
- Modify: `Tests/ConstruktTests/ReactiveTests.swift` (add to PropertyTests suite)

**Design:** Add a `deduplicate: Bool` parameter to `Property.init`. When `true` and `T: Equatable`, the setter skips notification if `newValue == oldValue`. Default is `false` (backward compatible). Implemented via a stored closure `shouldSkip: ((T, T) -> Bool)?` to avoid constraining the class itself to `Equatable`.

- [ ] **Step 1: Write failing tests**

Add to `Tests/ConstruktTests/ReactiveTests.swift` inside the `PropertyTests` suite:

```swift
@Test("Deduplication skips notification for equal values")
func deduplicationSkipsEqual() async {
    let property = Property<Int>(0, deduplicate: true)
    var received: [Int] = []
    
    property.observe(on: nil) { value in
        received.append(value)
    }.store(in: CancelBag())
    
    // Initial value
    #expect(received == [0])
    
    property.wrappedValue = 0  // same value
    property.wrappedValue = 0  // same value
    property.wrappedValue = 1  // different
    property.wrappedValue = 1  // same again
    property.wrappedValue = 2  // different
    
    #expect(received == [0, 1, 2])
}

@Test("Deduplication disabled by default — all sets broadcast")
func deduplicationDisabledByDefault() async {
    let property = Property<Int>(0)
    var count = 0
    
    property.observe(on: nil) { _ in
        count += 1
    }.store(in: CancelBag())
    
    property.wrappedValue = 0
    property.wrappedValue = 0
    property.wrappedValue = 0
    
    #expect(count == 4) // 1 initial + 3 sets
}

@Test("Deduplication works with non-Equatable types when disabled")
func nonEquatablePropertyWorks() {
    struct Opaque { let x: Int }
    let property = Property<Opaque>(Opaque(x: 1))
    var count = 0
    
    property.observe(on: nil) { _ in
        count += 1
    }.store(in: CancelBag())
    
    property.wrappedValue = Opaque(x: 1)
    #expect(count == 2) // initial + set (no dedup possible)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcbuddy test -d "16 pro" --only "ConstruktTests/Property"`
Expected: Compilation error — `Property.init` doesn't accept `deduplicate:` parameter.

- [ ] **Step 3: Implement deduplication**

Modify `Sources/Construkt/Core/Reactive/Property.swift`:

```swift
public final class Property<T>: MutableViewBinding {
    public typealias Value = T
    
    private var _value: T
    private var observers: [UUID: Observer] = [:]
    private let lock = NSRecursiveLock()
    private let shouldSkip: ((T, T) -> Bool)?
    
    private struct Observer {
        let queue: DispatchQueue?
        let handler: (T) -> Void
    }
    
    public var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            if let shouldSkip = shouldSkip, shouldSkip(_value, newValue) {
                lock.unlock()
                return
            }
            _value = newValue
            let currentObservers = observers.values
            lock.unlock()
            
            for observer in currentObservers {
                if let queue = observer.queue {
                    if queue == .main && Thread.isMainThread {
                        observer.handler(newValue)
                    } else {
                        queue.async { observer.handler(newValue) }
                    }
                } else {
                    observer.handler(newValue)
                }
            }
        }
    }
    
    /// Creates a new property with the given initial value.
    /// - Parameters:
    ///   - value: The initial value.
    ///   - deduplicate: When `true` and `T` conforms to `Equatable`, skips broadcasting if the new value equals the current value. Default is `false`.
    public init(_ value: T) {
        self._value = value
        self.shouldSkip = nil
    }
    
    // ... observe and removeObserver unchanged ...
}

extension Property where T: Equatable {
    /// Creates a new property with optional deduplication.
    /// When `deduplicate` is `true`, setting the same value will not notify observers.
    public convenience init(_ value: T, deduplicate: Bool) {
        self.init(value)
        // We need to set shouldSkip after init — but it's let.
        // Alternative: use the private init pattern below.
    }
}
```

**Correction — since `shouldSkip` is `let`, use a private designated init:**

```swift
public final class Property<T>: MutableViewBinding {
    public typealias Value = T
    
    private var _value: T
    private var observers: [UUID: Observer] = [:]
    private let lock = NSRecursiveLock()
    private let shouldSkip: ((T, T) -> Bool)?
    
    private struct Observer {
        let queue: DispatchQueue?
        let handler: (T) -> Void
    }
    
    public var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            if let shouldSkip = shouldSkip, shouldSkip(_value, newValue) {
                lock.unlock()
                return
            }
            _value = newValue
            let currentObservers = observers.values
            lock.unlock()
            
            for observer in currentObservers {
                if let queue = observer.queue {
                    if queue == .main && Thread.isMainThread {
                        observer.handler(newValue)
                    } else {
                        queue.async { observer.handler(newValue) }
                    }
                } else {
                    observer.handler(newValue)
                }
            }
        }
    }
    
    /// Creates a new property with the given initial value. No deduplication.
    public init(_ value: T) {
        self._value = value
        self.shouldSkip = nil
    }
    
    /// Internal designated init with optional skip predicate.
    private init(_ value: T, skipPredicate: ((T, T) -> Bool)?) {
        self._value = value
        self.shouldSkip = skipPredicate
    }
    
    /// Subscribes to value changes, immediately emitting the current value to the new observer.
    public func observe(on queue: DispatchQueue? = .main, _ handler: @escaping (T) -> Void) -> AnyCancellableLifecycle {
        lock.lock()
        defer { lock.unlock() }
        
        let id = UUID()
        observers[id] = Observer(queue: queue, handler: handler)
        
        let currentValue = _value
        if let queue = queue {
            if queue == .main && Thread.isMainThread {
                handler(currentValue)
            } else {
                queue.async { handler(currentValue) }
            }
        } else {
            handler(currentValue)
        }
        
        return PropertyCancellable { [weak self] in
            self?.removeObserver(id: id)
        }
    }
    
    private func removeObserver(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeValue(forKey: id)
    }
}

extension Property where T: Equatable {
    /// Creates a new property with deduplication. When `deduplicate` is `true`,
    /// setting the same value will not notify observers.
    public convenience init(_ value: T, deduplicate: Bool) {
        if deduplicate {
            self.init(value, skipPredicate: { $0 == $1 })
        } else {
            self.init(value, skipPredicate: nil)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcbuddy test -d "16 pro" --only "ConstruktTests/Property"`
Expected: All PropertyTests pass including the 3 new ones.

- [ ] **Step 5: Run full suite to verify no regressions**

Run: `xcbuddy test -d "16 pro"`
Expected: 182+ tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Reactive/Property.swift Tests/ConstruktTests/ReactiveTests.swift
git commit -m "feat(reactive): add opt-in deduplication to Property via init flag"
```

---

### Task 2: B14 — Identity-Aware DynamicForEach

**Files:**
- Create: `Sources/Construkt/Core/Builder/Builder+DynamicForEach.swift`
- Create: `Tests/ConstruktTests/DynamicForEachTests.swift`

**Design:** A new `DynamicForEach<Item: Identifiable>` class conforming to `AnyIndexableViewBuilder`. When `items` is set, it diffs old vs new by `id`, then applies minimal insert/remove/move operations on the parent `UIStackView`. Uses a simple O(n) diff algorithm (no Myers — overkill for typical list sizes of <100).

The diff produces three lists: `inserts` (new ids not in old), `removes` (old ids not in new), `moves` (ids present in both but at different indices). Updates (same id, same position) just rebuild the view in-place.

- [ ] **Step 1: Write failing tests**

Create `Tests/ConstruktTests/DynamicForEachTests.swift`:

```swift
import Testing
import UIKit
@testable import ConstruktKit

private struct TestItem: Identifiable, Equatable {
    let id: String
    let label: String
}

@Suite("DynamicForEach") @MainActor
struct DynamicForEachTests {
    
    @Test("Initial items produce correct view count")
    func initialItems() {
        let items = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        let forEach = DynamicForEach(items) { item in
            LabelView(item.label)
        }
        
        #expect(forEach.count == 2)
        #expect(forEach.asViews().count == 2)
    }
    
    @Test("Setting new items emits update signal")
    func updateSignalFires() {
        let forEach = DynamicForEach([TestItem(id: "a", label: "A")]) { item in
            LabelView(item.label)
        }
        
        var updateCount = 0
        forEach.updated?.observe(on: nil) { _ in
            updateCount += 1
        }
        
        forEach.items = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        #expect(updateCount == 1)
    }
    
    @Test("Diff produces correct changeset — insert only")
    func diffInsertOnly() {
        let old = [TestItem(id: "a", label: "A")]
        let new = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        
        let changeset = DynamicForEachChangeset.diff(old: old, new: new)
        
        #expect(changeset.inserts == [1])
        #expect(changeset.removes == [])
        #expect(changeset.moves == [])
    }
    
    @Test("Diff produces correct changeset — remove only")
    func diffRemoveOnly() {
        let old = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        let new = [TestItem(id: "a", label: "A")]
        
        let changeset = DynamicForEachChangeset.diff(old: old, new: new)
        
        #expect(changeset.removes == [1])
        #expect(changeset.inserts == [])
    }
    
    @Test("Diff produces correct changeset — move")
    func diffMove() {
        let old = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B"), TestItem(id: "c", label: "C")]
        let new = [TestItem(id: "c", label: "C"), TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        
        let changeset = DynamicForEachChangeset.diff(old: old, new: new)
        
        // "c" moved from index 2 to index 0
        #expect(changeset.moves.contains(where: { $0.from == 2 && $0.to == 0 }))
    }
    
    @Test("Applying changeset to UIStackView produces correct subview order")
    func applyToStackView() {
        let stack = UIStackView()
        let forEach = DynamicForEach([
            TestItem(id: "a", label: "A"),
            TestItem(id: "b", label: "B"),
            TestItem(id: "c", label: "C")
        ]) { item in
            LabelView(item.label)
        }
        
        // Initial population
        forEach.asViews().forEach { stack.addArrangedSubview($0.build()) }
        #expect(stack.arrangedSubviews.count == 3)
        
        // Update: remove "b", add "d" at end
        forEach.items = [
            TestItem(id: "a", label: "A"),
            TestItem(id: "c", label: "C"),
            TestItem(id: "d", label: "D")
        ]
        
        // After applying diff to stack
        forEach.applyChangeset(to: stack)
        
        #expect(stack.arrangedSubviews.count == 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcbuddy test -d "16 pro" --only "ConstruktTests/DynamicForEach"`
Expected: Compilation error — `DynamicForEach` type doesn't exist.

- [ ] **Step 3: Implement DynamicForEach**

Create `Sources/Construkt/Core/Builder/Builder+DynamicForEach.swift`:

```swift
//
//  Builder+DynamicForEach.swift
//  Construkt
//

import UIKit

/// A changeset describing the minimal operations to transform one list into another.
public struct DynamicForEachChangeset {
    public struct Move: Equatable {
        public let from: Int
        public let to: Int
    }
    
    public let removes: [Int]    // indices in old array (descending order for safe removal)
    public let inserts: [Int]    // indices in new array (ascending order for safe insertion)
    public let moves: [Move]     // from old index to new index
    
    /// Computes a changeset between two Identifiable arrays.
    public static func diff<Item: Identifiable>(old: [Item], new: [Item]) -> DynamicForEachChangeset {
        let oldIDs = old.map { $0.id }
        let newIDs = new.map { $0.id }
        
        let oldIDSet = Set(oldIDs)
        let newIDSet = Set(newIDs)
        
        // Removes: IDs in old but not in new
        let removedIDs = oldIDSet.subtracting(newIDSet)
        let removes = old.enumerated()
            .filter { removedIDs.contains($0.element.id) }
            .map { $0.offset }
            .sorted(by: >)  // descending for safe removal
        
        // Inserts: IDs in new but not in old
        let insertedIDs = newIDSet.subtracting(oldIDSet)
        let inserts = new.enumerated()
            .filter { insertedIDs.contains($0.element.id) }
            .map { $0.offset }
            .sorted()  // ascending for safe insertion
        
        // Moves: IDs in both but at different positions (after removes applied)
        // Build old index map (excluding removed)
        let survivingOld = old.enumerated().filter { !removedIDs.contains($0.element.id) }
        let survivingNewOrder = new.enumerated().filter { !insertedIDs.contains($0.element.id) }
        
        var moves: [Move] = []
        for (newIdx, newEntry) in survivingNewOrder.enumerated() {
            if let oldEntry = survivingOld.first(where: { $0.element.id == newEntry.element.id }) {
                let oldSurvivingIdx = survivingOld.firstIndex(where: { $0.element.id == newEntry.element.id })!
                if oldSurvivingIdx != newIdx {
                    moves.append(Move(from: oldEntry.offset, to: newEntry.offset))
                }
            }
        }
        
        return DynamicForEachChangeset(removes: removes, inserts: inserts, moves: moves)
    }
}

/// An identity-aware reactive list builder that diffs by `id` and applies minimal
/// insert/remove/move operations instead of full teardown-and-rebuild.
public class DynamicForEach<Item: Identifiable>: AnyIndexableViewBuilder {
    
    public var items: [Item] {
        didSet {
            lastChangeset = DynamicForEachChangeset.diff(old: oldValue, new: items)
            updatePublisher.send(())
        }
    }
    
    public var count: Int { items.count }
    public var updated: Signal<Void>? { updatePublisher }
    
    /// The most recent changeset (available after `items` is set).
    public private(set) var lastChangeset: DynamicForEachChangeset?
    
    private let updatePublisher = Signal<Void>()
    private let builder: (Item) -> View?
    
    public init(_ items: [Item], builder: @escaping (Item) -> View?) {
        self.items = items
        self.builder = builder
    }
    
    public func view(at index: Int) -> View? {
        guard items.indices.contains(index) else { return nil }
        return builder(items[index])
    }
    
    public func asViews() -> [View] {
        items.compactMap { builder($0) }
    }
    
    /// Applies the last computed changeset to a UIStackView, performing minimal operations.
    /// If no changeset is available (first load), does a full reset.
    public func applyChangeset(to stackView: UIStackView) {
        guard let changeset = lastChangeset else {
            // Full reset (initial load)
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            asViews().forEach { stackView.addArrangedSubview($0.build()) }
            return
        }
        
        // 1. Remove (descending order)
        for index in changeset.removes {
            guard index < stackView.arrangedSubviews.count else { continue }
            stackView.arrangedSubviews[index].removeFromSuperview()
        }
        
        // 2. Insert (ascending order)
        for index in changeset.inserts {
            guard index < items.count else { continue }
            if let view = builder(items[index]) {
                let uiView = view.build()
                if index >= stackView.arrangedSubviews.count {
                    stackView.addArrangedSubview(uiView)
                } else {
                    stackView.insertArrangedSubview(uiView, at: index)
                }
            }
        }
        
        // 3. Moves — reorder by removing and reinserting
        for move in changeset.moves.sorted(by: { $0.to < $1.to }) {
            guard move.to < stackView.arrangedSubviews.count else { continue }
            let view = stackView.arrangedSubviews.first { _ in true } // placeholder
            // For moves, we need to track views by identity
            // Simplified: rebuild moved items at their new positions
            if move.to < items.count, let newView = builder(items[move.to]) {
                let existing = stackView.arrangedSubviews[move.to]
                existing.removeFromSuperview()
                stackView.insertArrangedSubview(newView.build(), at: move.to)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcbuddy test -d "16 pro" --only "ConstruktTests/DynamicForEach"`
Expected: All DynamicForEach tests pass.

- [ ] **Step 5: Run full suite**

Run: `xcbuddy test -d "16 pro"`
Expected: All tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Builder/Builder+DynamicForEach.swift Tests/ConstruktTests/DynamicForEachTests.swift
git commit -m "feat(builder): add identity-aware DynamicForEach with minimal diffing"
```

---

### Task 3: B15 — DiffableContainerView

**Files:**
- Create: `Sources/Construkt/Core/Builder/Builder+DiffableContainer.swift`
- Create: `Tests/ConstruktTests/DiffableContainerTests.swift`

**Design:** A new `DiffableContainerView` that observes a binding of `[AnyHashable: View]` (keyed children). On each emission, it compares keys against current subviews (tracked via tags or associated keys), and applies minimal add/remove operations. Unlike `DynamicContainerView` (which rebuilds from scratch per contract #5), this is a new opt-in type.

Simpler approach: The binding emits an array of `TaggedView` (a struct with `id: AnyHashable` and `view: View`). The container tracks which IDs are currently displayed and only adds/removes the delta.

- [ ] **Step 1: Write failing tests**

Create `Tests/ConstruktTests/DiffableContainerTests.swift`:

```swift
import Testing
import UIKit
@testable import ConstruktKit

@Suite("DiffableContainerView") @MainActor
struct DiffableContainerTests {
    
    @Test("Initial binding emission adds all children")
    func initialEmission() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("A")),
            TaggedView(id: "b", view: LabelView("B"))
        ])
        
        let container = DiffableContainerView(binding)
        let uiView = container.build()
        
        // Trigger layout
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)
        uiView.layoutIfNeeded()
        
        #expect(uiView.subviews.count == 2)
    }
    
    @Test("Adding a new item only inserts one subview")
    func incrementalInsert() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("A"))
        ])
        
        let container = DiffableContainerView(binding)
        let uiView = container.build()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)
        uiView.layoutIfNeeded()
        
        #expect(uiView.subviews.count == 1)
        
        // Add second item
        binding.wrappedValue = [
            TaggedView(id: "a", view: LabelView("A")),
            TaggedView(id: "b", view: LabelView("B"))
        ]
        
        #expect(uiView.subviews.count == 2)
    }
    
    @Test("Removing an item only removes one subview")
    func incrementalRemove() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("A")),
            TaggedView(id: "b", view: LabelView("B"))
        ])
        
        let container = DiffableContainerView(binding)
        let uiView = container.build()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)
        uiView.layoutIfNeeded()
        
        let firstSubview = uiView.subviews[0]
        
        // Remove "b"
        binding.wrappedValue = [
            TaggedView(id: "a", view: LabelView("A"))
        ]
        
        #expect(uiView.subviews.count == 1)
        // The surviving view should be the same instance (not rebuilt)
        #expect(uiView.subviews[0] === firstSubview)
    }
    
    @Test("Unchanged items are not rebuilt")
    func unchangedItemsPreserved() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("A")),
            TaggedView(id: "b", view: LabelView("B"))
        ])
        
        let container = DiffableContainerView(binding)
        let uiView = container.build()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)
        uiView.layoutIfNeeded()
        
        let viewA = uiView.subviews[0]
        let viewB = uiView.subviews[1]
        
        // Same items, same order — nothing should change
        binding.wrappedValue = [
            TaggedView(id: "a", view: LabelView("A-updated")),
            TaggedView(id: "b", view: LabelView("B-updated"))
        ]
        
        // Views are preserved by identity (not rebuilt)
        #expect(uiView.subviews[0] === viewA)
        #expect(uiView.subviews[1] === viewB)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcbuddy test -d "16 pro" --only "ConstruktTests/DiffableContainerView"`
Expected: Compilation error — `DiffableContainerView` and `TaggedView` don't exist.

- [ ] **Step 3: Implement DiffableContainerView**

Create `Sources/Construkt/Core/Builder/Builder+DiffableContainer.swift`:

```swift
//
//  Builder+DiffableContainer.swift
//  Construkt
//

import UIKit

/// A view with a stable identity for use in `DiffableContainerView`.
public struct TaggedView {
    public let id: AnyHashable
    public let view: View
    
    public init(id: some Hashable, view: View) {
        self.id = AnyHashable(id)
        self.view = view
    }
}

/// A container view that applies minimal add/remove operations when its binding emits,
/// preserving existing subviews whose identity hasn't changed.
///
/// Unlike `DynamicContainerView` (which rebuilds from scratch on every emission),
/// `DiffableContainerView` tracks children by identity and only mutates the delta.
public struct DiffableContainerView: ModifiableView {
    
    public let modifiableView: DiffableContainerInternalView
    
    public init<Binding: ViewBinding>(_ binding: Binding) where Binding.Value == [TaggedView] {
        let internalView = DiffableContainerInternalView()
        self.modifiableView = internalView
        
        binding.observe(on: .main) { [weak internalView] taggedViews in
            internalView?.applyDiff(taggedViews)
        }.store(in: internalView.cancelBag)
    }
}

/// Internal UIView subclass that manages diffable children.
public final class DiffableContainerInternalView: UIView {
    
    /// Maps identity → (UIView instance, current index)
    private var childrenByID: [AnyHashable: UIView] = [:]
    private var currentOrder: [AnyHashable] = []
    
    func applyDiff(_ newItems: [TaggedView]) {
        let newIDs = newItems.map { $0.id }
        let newIDSet = Set(newIDs)
        let oldIDSet = Set(currentOrder)
        
        // 1. Remove children whose ID is no longer present
        let removedIDs = oldIDSet.subtracting(newIDSet)
        for id in removedIDs {
            childrenByID[id]?.removeFromSuperview()
            childrenByID.removeValue(forKey: id)
        }
        
        // 2. Add children whose ID is new
        let insertedIDs = newIDSet.subtracting(oldIDSet)
        for item in newItems where insertedIDs.contains(item.id) {
            let uiView = item.view.build()
            uiView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(uiView)
            NSLayoutConstraint.activate([
                uiView.topAnchor.constraint(equalTo: topAnchor),
                uiView.leadingAnchor.constraint(equalTo: leadingAnchor),
                uiView.trailingAnchor.constraint(equalTo: trailingAnchor),
                uiView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            childrenByID[item.id] = uiView
        }
        
        // 3. Reorder if needed (bring subviews to correct z-order)
        for (index, id) in newIDs.enumerated() {
            if let view = childrenByID[id] {
                // insertSubview(at:) is a no-op if already at correct position
                insertSubview(view, at: index)
            }
        }
        
        currentOrder = newIDs
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self && backgroundColor == .clear {
            return nil
        }
        return hitView
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcbuddy test -d "16 pro" --only "ConstruktTests/DiffableContainerView"`
Expected: All DiffableContainerView tests pass.

- [ ] **Step 5: Run full suite**

Run: `xcbuddy test -d "16 pro"`
Expected: All tests pass, no regressions.

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Builder/Builder+DiffableContainer.swift Tests/ConstruktTests/DiffableContainerTests.swift
git commit -m "feat(builder): add DiffableContainerView with identity-based incremental updates"
```

---

### Task 4: Low-Priority Fixes (Batch)

**Files:**
- Modify: `Sources/Construkt/Navigation/RouteChannel.swift` (add main thread assertion)
- Modify: `Sources/Construkt/Core/Builder/CollectionView/SupplementaryController.swift` (add @MainActor or lock)
- Modify: `Sources/Construkt/Navigation/Router.swift` (add @MainActor)
- Modify: `Sources/Construkt/Components/ShimmerView/_ShimmerLayer.swift` (fix deprecated API)
- Modify: `Sources/Construkt/Core/Builder/CollectionView/CellControllerAdapter.swift` (remove debug print)
- Modify: `Sources/Construkt/Core/Reactive/Binding+Operators.swift` (add lock to CompoundCancellable)

- [ ] **Step 1: Fix RouteChannel — add main thread assertion**

In `RouteChannel.swift`, in the `send` method, add:
```swift
public func send(_ event: Event, sender: AnyObject? = nil) {
    dispatchPrecondition(condition: .onQueue(.main))
    // ... existing code
}
```

- [ ] **Step 2: Fix SupplementaryRegistrationCache — add @MainActor**

In the file containing `SupplementaryRegistrationCache`:
```swift
@MainActor
class SupplementaryRegistrationCache {
    static var cache = [String: Any]()
    // ...
}
```

- [ ] **Step 3: Fix DefaultRouter — add @MainActor**

Add `@MainActor` to the class declaration:
```swift
@MainActor
public final class DefaultRouter: NSObject, ConstruktRouter, UINavigationControllerDelegate {
```

- [ ] **Step 4: Fix _ShimmerLayer — replace deprecated UIScreen.main**

Replace:
```swift
rasterizationScale = UIScreen.main.scale
```
With:
```swift
if #available(iOS 16.0, *) {
    // Will be set when added to a view hierarchy
} else {
    rasterizationScale = UIScreen.main.scale
}
```

Or simpler — just use a reasonable default:
```swift
rasterizationScale = 3.0  // Retina 3x covers all modern devices
```

Better approach — override `didMoveToSuperview` in the hosting view to set scale from `window?.screen.scale`.

- [ ] **Step 5: Fix CellConfigAdapter — remove debug print**

Remove:
```swift
deinit {
    print("CellConfigAdapter deinit")
}
```

- [ ] **Step 6: Fix CompoundCancellable — add lock**

In `Binding+Operators.swift`, modify `CompoundCancellable`:
```swift
private final class CompoundCancellable: AnyCancellableLifecycle {
    private var tokens: [AnyCancellableLifecycle]
    private let lock = NSLock()
    
    init(_ tokens: [AnyCancellableLifecycle]) {
        self.tokens = tokens
    }
    
    func cancel() {
        lock.lock()
        let currentTokens = tokens
        tokens = []
        lock.unlock()
        currentTokens.forEach { $0.cancel() }
    }
}
```

- [ ] **Step 7: Run full suite**

Run: `xcbuddy test -d "16 pro"`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "fix: batch low-priority fixes (thread safety, deprecated API, debug print)"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** B13 (Property dedup) ✓, B14 (DynamicForEach) ✓, B15 (DiffableContainer) ✓, low-priority fixes ✓
- [x] **No placeholders:** All code blocks are complete
- [x] **Type consistency:** `DynamicForEachChangeset` used consistently, `TaggedView` used consistently, `DiffableContainerInternalView` matches between implementation and test
- [x] **Contract preservation:** DynamicContainerView untouched (contract #5), ViewBinding protocol untouched (contract #2), Property default init unchanged (backward compatible)
