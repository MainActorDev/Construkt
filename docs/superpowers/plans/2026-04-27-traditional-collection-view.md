# TraditionalCollectionView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `TraditionalCollectionView` component that accepts any `UICollectionViewLayout` subclass while reusing Construkt's existing `AnySection`/`AnyCell` DSL, diffable data source, and delegate forwarding.

**Architecture:** New sibling component to `CollectionView` with its own `TraditionalCollectionViewWrapperView`. Shares `AnySection`/`AnyCell`, `SectionConfig`/`CellConfig`, `AnyCollectionDiffableDataSource`, `CellConfigAdapter`, `SupplementaryController`. Duplicates ~100 lines of boilerplate (delegate forwarding, scroll observation, refresh control, empty state) rather than refactoring existing `CollectionView`.

**Tech Stack:** Swift, UIKit, UICollectionView, UICollectionViewDiffableDataSource, Swift Testing

**Spec:** `docs/superpowers/specs/2026-04-27-traditional-collection-view-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift` | Create | `TraditionalCollectionView` struct + `TraditionalCollectionViewWrapperView` class + modifier extensions |
| `Tests/ConstruktTests/TraditionalCollectionViewTests.swift` | Create | Unit + integration tests |

No existing files are modified.

---

## Existing Code Reference

These files are NOT modified but are referenced throughout the plan. Subagents should read them for context:

- **`Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift`** — The existing `CollectionView` and `CollectionViewWrapperView`. Our new component mirrors this structure but with a simpler `update(sections:)` method.
- **`Sources/Construkt/Components/CollectionView/SectionConfig.swift`** — `SectionConfig` struct with `identifier`, `cells`, `header`, `footer`, `layoutProvider`, `layoutModifiers`, `decorationProviders`. We use `identifier`, `cells`, `header`, `footer` only.
- **`Sources/Construkt/Components/CollectionView/CellConfig.swift`** — `CellConfig` struct with `id`, `model`, `contentHash`, `cell(in:at:)`, `didSelect(sender:)`, `prefetch()`, `cancelPrefetch()`.
- **`Sources/Construkt/Components/CollectionView/DataSource.swift`** — `AnyCollectionDiffableDataSource` (typealias for `UICollectionViewDiffableDataSource<SectionConfig, CellConfig>`) with `display(_:)` for smart incremental diffing, `sectionIdentifier(at:)` for O(1) lookup.
- **`Sources/Construkt/Components/CollectionView/CellControllerAdapter.swift`** — `CellConfigAdapter` bridging `didSelectItemAt`, `prefetchItemsAt`, `cancelPrefetchingForItemsAt` to `CellConfig`.
- **`Sources/Construkt/Components/CollectionView/SupplementaryController.swift`** — `SupplementaryController` with `id`, `elementKind`, `dequeue(collectionView, indexPath)`, `isHidden`.
- **`Sources/Construkt/Core/Builder/Builder.swift`** — `ModifiableView` protocol (`associatedtype Base: UIView`, `var modifiableView: Base`), `ViewModifier<Base>` struct.
- **`Sources/Construkt/Core/Builder/CollectionView/Builder+AnySection.swift`** — `AnySection`, `AnySectionResultBuilder`, `AnySectionObservable`.

**Build command:** `xcodebuild build -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

**Test command:** `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

**Note:** xcodebuild may report `** TEST FAILED **` due to a pre-existing UIKit `_UIGetCurrentFallbackView` assertion in the simulator environment. This is NOT a test failure. Check individual test results — all Swift Testing tests should pass. Tests that create UIKit objects (like `UICollectionView`) should be annotated with `@MainActor`.

---

### Task 1: TraditionalCollectionViewWrapperView — Core Class

**Files:**
- Create: `Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift`
- Create: `Tests/ConstruktTests/TraditionalCollectionViewTests.swift`

- [ ] **Step 1: Write the failing test — layout is set correctly**

Create `Tests/ConstruktTests/TraditionalCollectionViewTests.swift`:

```swift
import Testing
import UIKit
@testable import ConstruktKit

@MainActor
@Suite("TraditionalCollectionView")
struct TraditionalCollectionViewTests {

    @Test("initializes with provided layout")
    func initializesWithProvidedLayout() {
        let flowLayout = UICollectionViewFlowLayout()

        let cv = TraditionalCollectionView(layout: flowLayout) {
            AnySection(id: TestSection.tags) {
                AnyCell("tag1", id: "tag1") { _ in ContainerView() }
            }
        }

        let wrapper = cv.modifiableView
        #expect(wrapper.collectionView.collectionViewLayout === flowLayout)
    }
}

private enum TestSection: SectionConfigIdentifier {
    case tags
    case items

    var uniqueId: String { "test-\(self)" }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: Compilation failure — `TraditionalCollectionView` does not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift`:

```swift
//
//  Created by Construkt.
//
//  © 2026, https://github.com/thatswiftdev. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

// MARK: - TraditionalCollectionView

/// A declarative builder component that bridges Construkt's View architecture with
/// `UICollectionView` using any `UICollectionViewLayout` subclass.
///
/// Unlike `CollectionView` (which is hardcoded to `UICollectionViewCompositionalLayout`),
/// `TraditionalCollectionView` accepts any layout — `UICollectionViewFlowLayout`,
/// custom `UICollectionViewLayout` subclasses, etc.
///
/// Usage:
/// ```swift
/// TraditionalCollectionView(layout: UICollectionViewFlowLayout()) {
///     AnySection(id: .tags, items: tags) { tag in
///         AnyCell(tag, id: tag.id) { TagChipView(tag: $0) }
///     }
///     .onSelect { tag in print(tag.name) }
/// }
/// ```
public struct TraditionalCollectionView: ModifiableView {

    public let modifiableView: TraditionalCollectionViewWrapperView

    /// Initializes a declarative collection view with a custom layout, dynamically mapped
    /// to a reactive stream of `Section` arrays.
    ///
    /// - Parameters:
    ///   - layout: The `UICollectionViewLayout` to use. This layout is set once at init
    ///     and governs the entire collection view.
    ///   - content: A result builder closure producing a reactive binding of section configurations.
    public init(
        layout: UICollectionViewLayout,
        @AnySectionResultBuilder content: () -> AnyViewBinding<[SectionConfig]>
    ) {
        let wrapper = TraditionalCollectionViewWrapperView(layout: layout)
        self.modifiableView = wrapper

        let sectionsBinding = content()
        sectionsBinding.observe(on: .main) { [weak wrapper] sections in
            wrapper?.update(sections: sections)
        }.store(in: wrapper.cancelBag)
    }
}

// MARK: - TraditionalCollectionViewWrapperView

/// The internal `UIView` subclass responsible for hosting the actual `UICollectionView`
/// with a user-provided `UICollectionViewLayout` and maintaining the Diffable Data Source mappings.
public class TraditionalCollectionViewWrapperView: UIView, UICollectionViewDelegate {

    /// A zero-height supplementary view returned when a header/footer is hidden.
    private final class EmptySupplementaryView: UICollectionReusableView {}

    public private(set) lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: providedLayout)
        cv.backgroundColor = .clear
        cv.clipsToBounds = false
        cv.delegate = self
        cv.register(
            EmptySupplementaryView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "FallbackEmptyHeader"
        )
        cv.register(
            EmptySupplementaryView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: "FallbackEmptyFooter"
        )
        return cv
    }()

    private let providedLayout: UICollectionViewLayout

    private lazy var dataSource: AnyCollectionDiffableDataSource = {
        let ds = AnyCollectionDiffableDataSource(
            collectionView: collectionView,
            cellProvider: { (collectionView, index, item) in
                return item.cell(in: collectionView, at: index)
            }
        )

        ds.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader ||
                  kind == UICollectionView.elementKindSectionFooter else {
                return nil
            }

            func dequeueFallback() -> UICollectionReusableView {
                if kind == UICollectionView.elementKindSectionHeader {
                    return collectionView.dequeueReusableSupplementaryView(
                        ofKind: kind, withReuseIdentifier: "FallbackEmptyHeader", for: indexPath
                    )
                } else {
                    return collectionView.dequeueReusableSupplementaryView(
                        ofKind: kind, withReuseIdentifier: "FallbackEmptyFooter", for: indexPath
                    )
                }
            }

            guard let self = self,
                  let identifier = self.dataSource.sectionIdentifier(at: indexPath.section),
                  let section = self.currentSectionMap[identifier]
            else {
                return dequeueFallback()
            }

            if kind == UICollectionView.elementKindSectionHeader,
               let header = section.header,
               !header.isHidden {
                return header.dequeue(collectionView, indexPath)
            }

            if kind == UICollectionView.elementKindSectionFooter,
               let footer = section.footer,
               !footer.isHidden {
                return footer.dequeue(collectionView, indexPath)
            }

            return dequeueFallback()
        }

        return ds
    }()

    private lazy var adapter: CellConfigAdapter = {
        return CellConfigAdapter(dataSource: dataSource)
    }()

    /// Cached section map for O(1) lookups by section identifier.
    private var currentSectionMap: [String: SectionConfig] = [:]

    public init(layout: UICollectionViewLayout) {
        self.providedLayout = layout
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setup() {
        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    /// Provides responder hierarchy access to the internal representation of a section.
    public func sectionController(for sectionIndex: Int) -> SectionConfig? {
        guard let identifier = dataSource.sectionIdentifier(at: sectionIndex) else { return nil }
        return currentSectionMap[identifier]
    }

    func update(sections: [SectionConfig]) {
        currentSectionMap = Dictionary(
            uniqueKeysWithValues: sections.map { ($0.identifier.uniqueId, $0) }
        )
        dataSource.display(sections)
    }

    // MARK: - Delegate Forwarding

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        adapter.collectionView(collectionView, didSelectItemAt: indexPath)
    }

    public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        adapter.collectionView(collectionView, prefetchItemsAt: indexPaths)
    }

    public func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        adapter.collectionView(collectionView, cancelPrefetchingForItemsAt: indexPaths)
    }

    // MARK: - Empty State

    public var emptyStateProvider: (() -> UIView)?
    private var emptyStateView: UIView?

    internal func updateEmptyState(show: Bool) {
        if show {
            if emptyStateView == nil {
                guard let provider = emptyStateProvider else { return }
                let view = provider()
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
                NSLayoutConstraint.activate([
                    view.centerXAnchor.constraint(equalTo: centerXAnchor),
                    view.centerYAnchor.constraint(equalTo: centerYAnchor),
                    view.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
                    view.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
                    view.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 20),
                    view.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
                ])
                emptyStateView = view
            }
            emptyStateView?.isHidden = false
            collectionView.isHidden = true
        } else {
            emptyStateView?.isHidden = true
            collectionView.isHidden = false
        }
    }

    // MARK: - Refresh Control

    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return refreshControl
    }()

    private var onRefresh: (() -> Void)?

    internal func setupRefreshControl(action: @escaping () -> Void) {
        self.onRefresh = action
        collectionView.refreshControl = refreshControl
    }

    @objc private func handleRefresh() {
        onRefresh?()
    }

    internal func setRefreshing(_ isRefreshing: Bool) {
        if isRefreshing {
            if window != nil {
                if !(collectionView.refreshControl?.isRefreshing ?? false) {
                    collectionView.refreshControl?.beginRefreshing()
                }
            }
        } else {
            if collectionView.refreshControl?.isRefreshing ?? false {
                collectionView.refreshControl?.endRefreshing()
            }
        }
    }

    // MARK: - Scroll Observation

    public var onScroll: ((UIScrollView) -> Void)?
    public var onWillBeginDragging: ((UIScrollView) -> Void)?
    public var onDidEndDragging: ((UIScrollView, Bool) -> Void)?
    public var onDidEndDecelerating: ((UIScrollView) -> Void)?

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onWillBeginDragging?(scrollView)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        onDidEndDragging?(scrollView, decelerate)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        onDidEndDecelerating?(scrollView)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: `initializesWithProvidedLayout` passes. All existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift Tests/ConstruktTests/TraditionalCollectionViewTests.swift
git commit -m "feat: add TraditionalCollectionView with custom UICollectionViewLayout support"
```

---

### Task 2: UICollectionViewDelegateFlowLayout — Header/Footer Sizing

**Files:**
- Modify: `Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift`
- Modify: `Tests/ConstruktTests/TraditionalCollectionViewTests.swift`

- [ ] **Step 1: Write the failing test — flow layout header sizing**

Add to `TraditionalCollectionViewTests.swift`:

```swift
@Test("flow layout returns header size when header exists")
func flowLayoutHeaderSizing() {
    let flowLayout = UICollectionViewFlowLayout()

    let cv = TraditionalCollectionView(layout: flowLayout) {
        AnySection(id: TestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
        .header {
            Header {
                ContainerView()
            }
        }
    }

    let wrapper = cv.modifiableView

    // Trigger update so currentSectionMap is populated
    // The init observes on .main, but we're already on main in @MainActor test,
    // so we need to manually trigger an update for synchronous testing.
    let bag = CancelBag()
    var sections: [SectionConfig] = []
    AnySection(id: TestSection.tags) {
        AnyCell("tag1", id: "tag1") { _ in ContainerView() }
    }
    .header {
        Header {
            ContainerView()
        }
    }
    .asAnySectionObservable()
    .observe(on: nil) { s in sections = s }
    .store(in: bag)

    wrapper.update(sections: sections)

    // Flow layout delegate should return non-zero header size
    let size = wrapper.collectionView(
        wrapper.collectionView,
        layout: flowLayout,
        referenceSizeForHeaderInSection: 0
    )
    #expect(size.height > 0)
}

@Test("flow layout returns zero header size when no header")
func flowLayoutNoHeaderSizing() {
    let flowLayout = UICollectionViewFlowLayout()

    let cv = TraditionalCollectionView(layout: flowLayout) {
        AnySection(id: TestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
    }

    let wrapper = cv.modifiableView

    let bag = CancelBag()
    var sections: [SectionConfig] = []
    AnySection(id: TestSection.tags) {
        AnyCell("tag1", id: "tag1") { _ in ContainerView() }
    }
    .asAnySectionObservable()
    .observe(on: nil) { s in sections = s }
    .store(in: bag)

    wrapper.update(sections: sections)

    let size = wrapper.collectionView(
        wrapper.collectionView,
        layout: flowLayout,
        referenceSizeForHeaderInSection: 0
    )
    #expect(size == .zero)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: Compilation failure — `TraditionalCollectionViewWrapperView` does not have `collectionView(_:layout:referenceSizeForHeaderInSection:)`.

- [ ] **Step 3: Add UICollectionViewDelegateFlowLayout conformance**

Add to `TraditionalCollectionViewWrapperView` in `Builder+TraditionalCollectionView.swift`. Change the class declaration to also conform to `UICollectionViewDelegateFlowLayout`:

Change:
```swift
public class TraditionalCollectionViewWrapperView: UIView, UICollectionViewDelegate {
```
To:
```swift
public class TraditionalCollectionViewWrapperView: UIView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
```

Then add the following methods inside the class, after the `// MARK: - Delegate Forwarding` section:

```swift
    // MARK: - Flow Layout Delegate

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        guard collectionViewLayout is UICollectionViewFlowLayout else { return .zero }
        guard let identifier = dataSource.sectionIdentifier(at: section),
              let sectionConfig = currentSectionMap[identifier],
              let header = sectionConfig.header,
              !header.isHidden else {
            return .zero
        }
        return CGSize(width: collectionView.bounds.width, height: 44)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int
    ) -> CGSize {
        guard collectionViewLayout is UICollectionViewFlowLayout else { return .zero }
        guard let identifier = dataSource.sectionIdentifier(at: section),
              let sectionConfig = currentSectionMap[identifier],
              let footer = sectionConfig.footer,
              !footer.isHidden else {
            return .zero
        }
        return CGSize(width: collectionView.bounds.width, height: 44)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: Both new tests pass. All existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift Tests/ConstruktTests/TraditionalCollectionViewTests.swift
git commit -m "feat: add UICollectionViewDelegateFlowLayout for header/footer sizing"
```

---

### Task 3: Modifier Extensions — contentInset, onRefresh, scroll observation

**Files:**
- Modify: `Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift`
- Modify: `Tests/ConstruktTests/TraditionalCollectionViewTests.swift`

- [ ] **Step 1: Write the failing test — contentInset modifier**

Add to `TraditionalCollectionViewTests.swift`:

```swift
@Test("contentInset modifier sets collection view inset")
func contentInsetModifier() {
    let flowLayout = UICollectionViewFlowLayout()

    let cv = TraditionalCollectionView(layout: flowLayout) {
        AnySection(id: TestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
    }
    .contentInset(top: 10, left: 20, bottom: 30, right: 40)

    let wrapper = cv.modifiableView
    let inset = wrapper.collectionView.contentInset
    #expect(inset.top == 10)
    #expect(inset.left == 20)
    #expect(inset.bottom == 30)
    #expect(inset.right == 40)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: Compilation failure — `contentInset` is not available on `TraditionalCollectionView` because the `ModifiableView` extension is constrained to `where Base: CollectionViewWrapperView`.

- [ ] **Step 3: Add modifier extensions**

Add the following at the bottom of `Builder+TraditionalCollectionView.swift`:

```swift
// MARK: - TraditionalCollectionView Modifiers

public extension TraditionalCollectionView {
    /// Dynamically swaps the internal collection view display for a custom empty state `View` when the
    /// bounding binding resolves to `true`.
    func emptyState<B: ViewBinding>(
        when binding: B,
        @ViewResultBuilder _ content: @escaping () -> ViewConvertable
    ) -> TraditionalCollectionView where B.Value == Bool {
        let views = content().asViews()
        let view = VStackView(views)
            .alignment(.center)
            .build()
        modifiableView.emptyStateProvider = { view }

        binding
            .distinctUntilChanged()
            .observe(on: .main) { [weak modifiableView] show in
                modifiableView?.updateEmptyState(show: show)
            }
            .store(in: modifiableView.cancelBag)

        return self
    }
}

public extension ModifiableView where Base: TraditionalCollectionViewWrapperView {

    /// Adjusts the internal scroll view's content inset.
    @discardableResult
    func contentInset(
        top: CGFloat = 0,
        left: CGFloat = 0,
        bottom: CGFloat = 0,
        right: CGFloat = 0
    ) -> ViewModifier<Base> {
        modifiableView.collectionView.contentInset = .init(top: top, left: left, bottom: bottom, right: right)
        return ViewModifier(modifiableView)
    }

    /// Installs a `UIRefreshControl` directly into the collection view, binding its active state
    /// to a specific boolean binding.
    @discardableResult
    func onRefresh<B: ViewBinding>(_ binding: B, action: @escaping () -> Void) -> ViewModifier<Base> where B.Value == Bool {
        modifiableView.setupRefreshControl(action: action)

        binding.observe(on: .main) { [weak modifiableView] isRefreshing in
            modifiableView?.setRefreshing(isRefreshing)
        }.store(in: modifiableView.cancelBag)

        return ViewModifier(modifiableView)
    }

    /// Forwarded `UIScrollViewDelegate` scroll event.
    @discardableResult
    func onScroll(_ handler: @escaping (UIScrollView) -> Void) -> ViewModifier<Base> {
        modifiableView.onScroll = handler
        return ViewModifier(modifiableView)
    }

    /// Forwarded `UIScrollViewDelegate` scroll view delegate will begin dragging.
    @discardableResult
    func onWillBeginDragging(_ handler: @escaping (UIScrollView) -> Void) -> ViewModifier<Base> {
        modifiableView.onWillBeginDragging = handler
        return ViewModifier(modifiableView)
    }

    /// Forwarded `UIScrollViewDelegate` did end dragging.
    @discardableResult
    func onDidEndDragging(_ handler: @escaping (UIScrollView, Bool) -> Void) -> ViewModifier<Base> {
        modifiableView.onDidEndDragging = handler
        return ViewModifier(modifiableView)
    }

    /// Forwarded `UIScrollViewDelegate` did end decelerating.
    @discardableResult
    func onDidEndDecelerating(_ handler: @escaping (UIScrollView) -> Void) -> ViewModifier<Base> {
        modifiableView.onDidEndDecelerating = handler
        return ViewModifier(modifiableView)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: `contentInsetModifier` passes. All existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift Tests/ConstruktTests/TraditionalCollectionViewTests.swift
git commit -m "feat: add modifier extensions for TraditionalCollectionView"
```

---

### Task 4: Integration Test — Full DSL Pipeline

**Files:**
- Modify: `Tests/ConstruktTests/TraditionalCollectionViewTests.swift`

- [ ] **Step 1: Write the integration test — sections populate data source**

Add to `TraditionalCollectionViewTests.swift`:

```swift
@Test("update populates data source with sections and cells")
func updatePopulatesDataSource() {
    let flowLayout = UICollectionViewFlowLayout()

    let wrapper = TraditionalCollectionViewWrapperView(layout: flowLayout)

    let bag = CancelBag()
    var sections: [SectionConfig] = []

    AnySection(id: TestSection.tags) {
        AnyCell("tag1", id: "t1") { _ in ContainerView() }
        AnyCell("tag2", id: "t2") { _ in ContainerView() }
    }
    .asAnySectionObservable()
    .observe(on: nil) { s in sections = s }
    .store(in: bag)

    wrapper.update(sections: sections)

    let snapshot = wrapper.collectionView.dataSource as! AnyCollectionDiffableDataSource
    let snap = snapshot.snapshot()
    #expect(snap.numberOfSections == 1)
    #expect(snap.numberOfItems(inSection: snap.sectionIdentifiers[0]) == 2)
}

@Test("multiple sections are all present in data source")
func multipleSectionsPresent() {
    let flowLayout = UICollectionViewFlowLayout()

    let wrapper = TraditionalCollectionViewWrapperView(layout: flowLayout)

    let bag = CancelBag()
    var sections1: [SectionConfig] = []
    var sections2: [SectionConfig] = []

    AnySection(id: TestSection.tags) {
        AnyCell("tag1", id: "t1") { _ in ContainerView() }
    }
    .asAnySectionObservable()
    .observe(on: nil) { s in sections1 = s }
    .store(in: bag)

    AnySection(id: TestSection.items) {
        AnyCell("item1", id: "i1") { _ in ContainerView() }
        AnyCell("item2", id: "i2") { _ in ContainerView() }
        AnyCell("item3", id: "i3") { _ in ContainerView() }
    }
    .asAnySectionObservable()
    .observe(on: nil) { s in sections2 = s }
    .store(in: bag)

    wrapper.update(sections: sections1 + sections2)

    let snapshot = wrapper.collectionView.dataSource as! AnyCollectionDiffableDataSource
    let snap = snapshot.snapshot()
    #expect(snap.numberOfSections == 2)
    #expect(snap.numberOfItems(inSection: snap.sectionIdentifiers[0]) == 1)
    #expect(snap.numberOfItems(inSection: snap.sectionIdentifiers[1]) == 3)
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: Both new tests pass. All existing tests still pass.

Note: These tests should pass immediately since the implementation from Task 1 already includes `update(sections:)` calling `dataSource.display(sections)`. This task validates the integration works end-to-end.

- [ ] **Step 3: Commit**

```bash
git add Tests/ConstruktTests/TraditionalCollectionViewTests.swift
git commit -m "test: add integration tests for TraditionalCollectionView data source pipeline"
```

---

### Task 5: Selection Forwarding Test

**Files:**
- Modify: `Tests/ConstruktTests/TraditionalCollectionViewTests.swift`

- [ ] **Step 1: Write the test — selection forwarding through adapter**

Add to `TraditionalCollectionViewTests.swift`:

```swift
@Test("sectionController returns correct section for index")
func sectionControllerLookup() {
    let flowLayout = UICollectionViewFlowLayout()

    let wrapper = TraditionalCollectionViewWrapperView(layout: flowLayout)

    let bag = CancelBag()
    var sections: [SectionConfig] = []

    AnySection(id: TestSection.tags) {
        AnyCell("tag1", id: "t1") { _ in ContainerView() }
    }
    .asAnySectionObservable()
    .observe(on: nil) { s in sections = s }
    .store(in: bag)

    wrapper.update(sections: sections)

    let section = wrapper.sectionController(for: 0)
    #expect(section != nil)
    #expect(section?.identifier.uniqueId == TestSection.tags.uniqueId)
    #expect(wrapper.sectionController(for: 1) == nil)
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `xcodebuild test -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: Test passes. All existing tests still pass.

- [ ] **Step 3: Commit**

```bash
git add Tests/ConstruktTests/TraditionalCollectionViewTests.swift
git commit -m "test: add sectionController lookup test for TraditionalCollectionView"
```

---

### Task 6: Documentation — README and SKILL Updates

**Files:**
- Modify: `README.md`
- Modify: `SKILL.md`

- [ ] **Step 1: Read current README.md and SKILL.md**

Read both files to understand the current structure and find the right insertion points.

- [ ] **Step 2: Add TraditionalCollectionView section to README.md**

Find the CollectionView section in README.md and add a new subsection after it. The exact insertion point depends on the current README structure — look for the existing `CollectionView` documentation section and add the new section immediately after it.

Add:

```markdown
### TraditionalCollectionView

For layouts that `UICollectionViewCompositionalLayout` cannot express (flow/tag-cloud, circular, physics-based), use `TraditionalCollectionView` with any `UICollectionViewLayout` subclass:

```swift
let flowLayout = UICollectionViewFlowLayout()
flowLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize

TraditionalCollectionView(layout: flowLayout) {
    AnySection(id: .tags, items: tags) { tag in
        AnyCell(tag, id: tag.id) { TagChipView(tag: $0) }
    }
    .header { Header { TagSectionHeader() } }
    .onSelect { tag in print(tag.name) }
    .shimmer(count: 6, when: isLoading) { ShimmerPlaceholder() }
}
.onRefresh(isRefreshing) { viewModel.refresh() }
.contentInset(top: 16)
.emptyState(when: isEmpty) { EmptyTagsView() }
```

`TraditionalCollectionView` shares the same `AnySection`/`AnyCell` DSL, diffable data source, selection handling, shimmer, and scroll observation as `CollectionView`. The key difference is that layout is provided at init rather than per-section via `.layout{}`.

**Supported modifiers:** `.onSelect`, `.onRoute`, `.header()`, `.footer()`, `.headerHidden(when:)`, `.footerHidden(when:)`, `.shimmer()`, `.contentInset()`, `.onRefresh()`, `.onScroll()`, `.emptyState(when:)`.

**Not applicable** (silently ignored): `.layout{}`, `.decorationItems()`, `.backgroundDecoration()` — these are compositional-layout-specific.
```

- [ ] **Step 3: Add TraditionalCollectionView to SKILL.md**

Find the components table in SKILL.md and add a row for `TraditionalCollectionView`. The exact insertion point depends on the current SKILL structure.

Add a row to the components table:

```markdown
| `TraditionalCollectionView` | Collection view with custom `UICollectionViewLayout` subclass support |
```

- [ ] **Step 4: Build to verify no issues**

Run: `xcodebuild build -scheme Construkt -destination 'id=5B41B0E2-926A-47D0-95D6-7177657C485F'`

Expected: BUILD SUCCEEDED (docs changes don't affect build, but verify nothing was accidentally broken).

- [ ] **Step 5: Commit**

```bash
git add README.md SKILL.md
git commit -m "docs: add TraditionalCollectionView documentation"
```
