# Custom CollectionView Layout Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Construkt's `CollectionView` to support custom layout algorithms (tag clouds, flow layouts, etc.) beyond the built-in `.list()`, `.grid()`, and `.carousel()` factories.

**Architecture:** Three independent options are presented, each self-contained. Option B (custom group within compositional layout) is the recommended starting point — it requires no architectural changes and covers the primary use case (tag/chip cloud). Options A and C are additive and can be implemented later if exotic layout needs arise.

**Tech Stack:** Swift 5, UIKit (`UICollectionViewCompositionalLayout`, `NSCollectionLayoutGroup.custom`), Construkt's `CollectionLayoutSectionBuilder`, `@LayoutBuilder`, `SectionConfig`

---

## Option B: Per-Section Flow Layout via Custom Group (Recommended)

### Summary

Add a `.flow()` factory to `CollectionLayoutSectionBuilder` that uses `NSCollectionLayoutGroup.custom(layoutSize:itemProvider:)` to compute a wrapping/flow layout within a single compositional section. Items wrap to the next line when they exceed the available width.

### Pros
- **Zero architectural changes** — stays within existing `.layout{}` on `AnySection`
- Selection, binding, diffable data source, decoration items, supplementary views all work as-is
- Per-section composability preserved (mix flow sections with list/grid/carousel sections)
- iOS 13+ compatible (`NSCollectionLayoutGroup.custom` is iOS 13)
- Smallest implementation scope of all three options
- No self-sizing circular dependency issues

### Cons
- Requires **pre-measured item sizes** — the user must know item widths before layout
- Cannot handle truly exotic layouts (circular, physics-based, waterfall)
- Flow algorithm runs synchronously in the layout provider — many items could be slow (unlikely in practice for tag clouds)

### File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `Sources/Construkt/Extensions/NSCollectionLayout.swift` | Add `.flow()` factory to `CollectionLayoutSectionBuilder` |
| Create | `Sources/Construkt/Components/CollectionView/FlowLayoutCalculator.swift` | Pure function that computes `[NSCollectionLayoutGroupCustomItem]` frames from item sizes + container width |
| Create | `Tests/ConstruktTests/FlowLayoutCalculatorTests.swift` | Unit tests for the flow algorithm |
| Create | `Tests/ConstruktTests/FlowLayoutIntegrationTests.swift` | Integration tests for `.flow()` on `AnySection` |

---

### Task 1: Flow Layout Calculator — Pure Algorithm

**Files:**
- Create: `Sources/Construkt/Components/CollectionView/FlowLayoutCalculator.swift`
- Test: `Tests/ConstruktTests/FlowLayoutCalculatorTests.swift`

- [ ] **Step 1: Write the failing test for basic single-row flow**

```swift
// Tests/ConstruktTests/FlowLayoutCalculatorTests.swift
import Testing
@testable import ConstruktKit
import CoreGraphics

@Suite("FlowLayoutCalculator")
struct FlowLayoutCalculatorTests {

    @Test("single row when all items fit")
    func singleRow() {
        let sizes: [CGSize] = [
            CGSize(width: 60, height: 30),
            CGSize(width: 80, height: 30),
            CGSize(width: 100, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 300,
            horizontalSpacing: 8,
            lineSpacing: 8
        )

        #expect(frames.count == 3)
        // First item at origin
        #expect(frames[0].origin.x == 0)
        #expect(frames[0].origin.y == 0)
        #expect(frames[0].size == sizes[0])
        // Second item after first + spacing
        #expect(frames[1].origin.x == 68) // 60 + 8
        #expect(frames[1].origin.y == 0)
        // Third item after second + spacing
        #expect(frames[2].origin.x == 156) // 68 + 80 + 8
        #expect(frames[2].origin.y == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FlowLayoutCalculatorTests`
Expected: FAIL — `FlowLayoutCalculator` not found

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/Construkt/Components/CollectionView/FlowLayoutCalculator.swift
import UIKit

/// Computes wrapping flow-layout frames for variable-width items within a fixed container width.
/// Used by `CollectionLayoutSectionBuilder.flow()` to feed `NSCollectionLayoutGroup.custom`.
public enum FlowLayoutCalculator {

    /// Returns an array of `CGRect` frames, one per item, laid out left-to-right with line wrapping.
    ///
    /// - Parameters:
    ///   - itemSizes: The pre-measured size of each item.
    ///   - containerWidth: The available width for laying out items.
    ///   - horizontalSpacing: Horizontal gap between items on the same line.
    ///   - lineSpacing: Vertical gap between lines.
    /// - Returns: An array of frames in the same order as `itemSizes`.
    public static func computeFrames(
        itemSizes: [CGSize],
        containerWidth: CGFloat,
        horizontalSpacing: CGFloat,
        lineSpacing: CGFloat
    ) -> [CGRect] {
        guard !itemSizes.isEmpty else { return [] }

        var frames: [CGRect] = []
        frames.reserveCapacity(itemSizes.count)

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in itemSizes {
            let itemWidth = min(size.width, containerWidth)

            // Wrap to next line if item doesn't fit (unless line is empty)
            if currentX > 0 && currentX + horizontalSpacing + itemWidth > containerWidth {
                currentY += lineHeight + lineSpacing
                currentX = 0
                lineHeight = 0
            }

            let x = currentX
            let frame = CGRect(x: x, y: currentY, width: itemWidth, height: size.height)
            frames.append(frame)

            currentX = x + itemWidth + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        return frames
    }

    /// The total height of the laid-out content (max Y + last line height).
    public static func totalHeight(for frames: [CGRect]) -> CGFloat {
        guard let last = frames.last else { return 0 }
        return last.maxY
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FlowLayoutCalculatorTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Construkt/Components/CollectionView/FlowLayoutCalculator.swift Tests/ConstruktTests/FlowLayoutCalculatorTests.swift
git commit -m "feat: add FlowLayoutCalculator for wrapping flow layout frames"
```

---

### Task 2: Flow Layout Calculator — Multi-Row and Edge Cases

**Files:**
- Modify: `Tests/ConstruktTests/FlowLayoutCalculatorTests.swift`

- [ ] **Step 1: Write failing tests for wrapping, mixed heights, empty input, and oversized items**

```swift
// Append to FlowLayoutCalculatorTests.swift

    @Test("wraps to second row when items exceed container width")
    func wrapsToSecondRow() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 250,
            horizontalSpacing: 8,
            lineSpacing: 12
        )

        #expect(frames.count == 4)
        // Row 1: items 0, 1 (100 + 8 + 100 = 208 <= 250)
        #expect(frames[0].origin == CGPoint(x: 0, y: 0))
        #expect(frames[1].origin == CGPoint(x: 108, y: 0))
        // Row 2: items 2, 3 (100 + 8 + 100 = 208 <= 250)
        #expect(frames[2].origin == CGPoint(x: 0, y: 42)) // 30 + 12
        #expect(frames[3].origin == CGPoint(x: 108, y: 42))
    }

    @Test("mixed heights uses tallest item per row")
    func mixedHeights() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 20),
            CGSize(width: 100, height: 40),
            CGSize(width: 100, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 250,
            horizontalSpacing: 8,
            lineSpacing: 8
        )

        // Row 1: items 0, 1 — line height = 40
        #expect(frames[0].origin.y == 0)
        #expect(frames[1].origin.y == 0)
        // Row 2: item 2 starts at y = 40 + 8 = 48
        #expect(frames[2].origin.y == 48)
    }

    @Test("empty input returns empty frames")
    func emptyInput() {
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: [],
            containerWidth: 300,
            horizontalSpacing: 8,
            lineSpacing: 8
        )
        #expect(frames.isEmpty)
        #expect(FlowLayoutCalculator.totalHeight(for: frames) == 0)
    }

    @Test("oversized item is clamped to container width")
    func oversizedItem() {
        let sizes: [CGSize] = [
            CGSize(width: 500, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 300,
            horizontalSpacing: 8,
            lineSpacing: 8
        )

        #expect(frames.count == 1)
        #expect(frames[0].size.width == 300)
        #expect(frames[0].origin.x == 0)
    }

    @Test("totalHeight returns correct value")
    func totalHeightCalculation() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 40)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 250,
            horizontalSpacing: 8,
            lineSpacing: 10
        )
        // Row 1: height 30, Row 2: height 40, gap 10
        // Total = 30 + 10 + 40 = 80
        #expect(FlowLayoutCalculator.totalHeight(for: frames) == 80)
    }
```

- [ ] **Step 2: Run tests to verify they pass (implementation already handles these cases)**

Run: `swift test --filter FlowLayoutCalculatorTests`
Expected: All PASS (the algorithm from Task 1 already handles wrapping, mixed heights, empty, and oversized)

- [ ] **Step 3: Commit**

```bash
git add Tests/ConstruktTests/FlowLayoutCalculatorTests.swift
git commit -m "test: add edge case tests for FlowLayoutCalculator"
```

---

### Task 3: Add `.flow()` Factory to `CollectionLayoutSectionBuilder`

**Files:**
- Modify: `Sources/Construkt/Extensions/NSCollectionLayout.swift`

- [ ] **Step 1: Write the `.flow()` factory method**

Add after the `.carousel()` factory (after line 86 in `NSCollectionLayout.swift`):

```swift
    /// Creates a wrapping flow layout where items have variable widths and wrap to the next line.
    ///
    /// This is ideal for tag clouds, chip groups, or any layout where items have different widths
    /// and should flow left-to-right with line wrapping.
    ///
    /// - Parameters:
    ///   - itemSizes: Pre-measured sizes for each item. The count must match the number of items in the section.
    ///   - horizontalSpacing: Horizontal gap between items on the same line. Default 8.
    ///   - lineSpacing: Vertical gap between lines. Default 8.
    /// - Returns: A configured `CollectionLayoutSectionBuilder`.
    public static func flow(
        itemSizes: [CGSize],
        horizontalSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8
    ) -> CollectionLayoutSectionBuilder {
        // Use estimated height — UIKit will derive actual height from custom item frames.
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )

        let group = NSCollectionLayoutGroup.custom(layoutSize: groupSize) { environment in
            let containerWidth = environment.container.effectiveContentSize.width
            let frames = FlowLayoutCalculator.computeFrames(
                itemSizes: itemSizes,
                containerWidth: containerWidth,
                horizontalSpacing: horizontalSpacing,
                lineSpacing: lineSpacing
            )
            return frames.map { NSCollectionLayoutGroupCustomItem(frame: $0) }
        }

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0
        return CollectionLayoutSectionBuilder(section: section)
    }
```

- [ ] **Step 2: Make the `CollectionLayoutSectionBuilder.init` internal → keep as-is (already `internal`)**

Verify that `init(section:)` is `internal` (line 30). It is — no change needed.

- [ ] **Step 3: Build to verify compilation**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Construkt/Extensions/NSCollectionLayout.swift
git commit -m "feat: add .flow() factory to CollectionLayoutSectionBuilder for wrapping layouts"
```

---

### Task 4: Integration Test — `.flow()` on `AnySection`

**Files:**
- Create: `Tests/ConstruktTests/FlowLayoutIntegrationTests.swift`

- [ ] **Step 1: Write integration test verifying `.flow()` sets layoutProvider on SectionConfig**

```swift
// Tests/ConstruktTests/FlowLayoutIntegrationTests.swift
import Testing
@testable import ConstruktKit
import UIKit

@Suite("Flow Layout Integration")
struct FlowLayoutIntegrationTests {

    @Test("flow layout sets layoutProvider on SectionConfig")
    func flowLayoutSetsProvider() {
        let bag = CancelBag()
        var emissions: [[SectionConfig]] = []

        let sizes = [
            CGSize(width: 60, height: 30),
            CGSize(width: 80, height: 30),
            CGSize(width: 100, height: 30)
        ]

        AnySection(id: FlowTestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
            AnyCell("tag2", id: "tag2") { _ in ContainerView() }
            AnyCell("tag3", id: "tag3") { _ in ContainerView() }
        }
        .layout {
            CollectionLayoutSectionBuilder.flow(
                itemSizes: sizes,
                horizontalSpacing: 8,
                lineSpacing: 8
            )
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].count == 1)

        let section = emissions[0][0]
        #expect(section.layoutProvider != nil)

        // Verify the layout provider returns a valid NSCollectionLayoutSection
        let layoutSection = section.layoutProvider?(section.identifier.uniqueId)
        #expect(layoutSection != nil)
    }

    @Test("flow layout composes with other section modifiers")
    func flowLayoutComposesWithModifiers() {
        let bag = CancelBag()
        var emissions: [[SectionConfig]] = []

        let sizes = [CGSize(width: 60, height: 30)]

        AnySection(id: FlowTestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
        .layout {
            CollectionLayoutSectionBuilder.flow(itemSizes: sizes)
                .insets(top: 16, leading: 16, bottom: 16, trailing: 16)
                .supplementaryHeader(height: .estimated(44))
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        let section = emissions[0][0]
        let layoutSection = section.layoutProvider?(section.identifier.uniqueId)
        #expect(layoutSection != nil)
        #expect(layoutSection!.contentInsets.top == 16)
        #expect(layoutSection!.boundarySupplementaryItems.count == 1)
    }
}

private enum FlowTestSection: SectionConfigIdentifier {
    case tags
    var uniqueId: String { "flow-test-\(self)" }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter FlowLayoutIntegrationTests`
Expected: All PASS

- [ ] **Step 3: Run full test suite to verify no regressions**

Run: `swift test`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Tests/ConstruktTests/FlowLayoutIntegrationTests.swift
git commit -m "test: add integration tests for .flow() layout on AnySection"
```

---

## Option A: Nested CollectionView with Custom Layout

### Summary

Add a `.customLayout(_:)` modifier on `CollectionView` that allows injecting any `UICollectionViewLayout` subclass. The custom-layout `CollectionView` is then nested inside an `AnyCell` of an outer compositional `CollectionView`.

### Pros
- Supports **any** `UICollectionViewLayout` subclass (flow, waterfall, circular, physics-based)
- Small API surface — one new modifier
- Each nested CV is fully independent (selection, binding, data source)

### Cons
- **Cell recreation problem** — when outer diffable data source reloads the hosting cell, the inner `CollectionView` is destroyed and recreated (new UICollectionView, new data source, new layout). Selection state lost, visual flash.
- **Self-sizing circular dependency** — inner CV needs width from outer cell to compute height; outer cell needs height from inner CV. Requires multi-pass layout, `preferredLayoutAttributesFitting` override, invalidation loop prevention.
- Higher cognitive load for users (nested CV mental model)
- Fragile — requires stable `id` + reactive bindings for inner data to avoid unnecessary reloads

### File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift` | Add `.customLayout(_:)` modifier on `CollectionView`, bypass compositional layout creation in `update(sections:)` |
| Create | `Tests/ConstruktTests/CustomLayoutCollectionViewTests.swift` | Tests for custom layout injection |

---

### Task 5: Add `.customLayout(_:)` Modifier on `CollectionView`

**Files:**
- Modify: `Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift`
- Test: `Tests/ConstruktTests/CustomLayoutCollectionViewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/ConstruktTests/CustomLayoutCollectionViewTests.swift
import Testing
@testable import ConstruktKit
import UIKit

@Suite("CollectionView Custom Layout")
struct CustomLayoutCollectionViewTests {

    @Test("customLayout sets the provided layout on the collection view")
    func customLayoutSetsLayout() {
        let customLayout = UICollectionViewFlowLayout()
        customLayout.scrollDirection = .horizontal

        let cv = CollectionView {
            AnySection(id: CustomLayoutTestSection.main) {
                AnyCell("item", id: "item1") { _ in ContainerView() }
            }
            .layout {
                CollectionLayoutSectionBuilder.list(itemHeight: .estimated(44))
            }
        }
        .customLayout(customLayout)

        let wrapper = cv.modifiableView
        #expect(wrapper.collectionView.collectionViewLayout === customLayout)
    }
}

private enum CustomLayoutTestSection: SectionConfigIdentifier {
    case main
    var uniqueId: String { "custom-layout-\(self)" }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CustomLayoutCollectionViewTests`
Expected: FAIL — `customLayout` method not found

- [ ] **Step 3: Add `customLayout` property and modifier**

In `Builder+CollectionView.swift`, add a stored property to `CollectionViewWrapperView` and a modifier on `CollectionView`:

Add to `CollectionViewWrapperView` (after `hasInitializedLayout` around line 139):

```swift
    /// When set, this layout is used instead of creating a UICollectionViewCompositionalLayout.
    var customLayout: UICollectionViewLayout?
```

Modify `update(sections:)` — add a branch at line 175 to check for custom layout:

```swift
    func update(sections: [SectionConfig]) {
        currentSectionMap = Dictionary(
            uniqueKeysWithValues: sections.map { ($0.identifier.uniqueId, $0) }
        )

        let activeLayout: UICollectionViewLayout
        if !hasInitializedLayout {
            if let custom = customLayout {
                // Use the user-provided custom layout directly.
                // Section-level layoutProviders are ignored — the custom layout governs everything.
                collectionView.setCollectionViewLayout(custom, animated: false)
                hasInitializedLayout = true
                activeLayout = custom
            } else {
                // Existing compositional layout creation code (unchanged)...
```

Add the modifier extension (after the existing `CollectionView` extensions, around line 369):

```swift
extension CollectionView {
    /// Replaces the default `UICollectionViewCompositionalLayout` with a custom layout.
    ///
    /// When a custom layout is set, per-section `.layout {}` modifiers are ignored —
    /// the custom layout governs the entire collection view.
    ///
    /// This is useful for nesting a `CollectionView` with a non-compositional layout
    /// (e.g., `UICollectionViewFlowLayout` or a custom subclass) inside an `AnyCell`.
    ///
    /// - Parameter layout: A `UICollectionViewLayout` subclass instance.
    /// - Returns: The modified `CollectionView`.
    public func customLayout(_ layout: UICollectionViewLayout) -> CollectionView {
        modifiableView.customLayout = layout
        // Set the layout immediately so it's available before the first update
        modifiableView.collectionView.setCollectionViewLayout(layout, animated: false)
        return self
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CustomLayoutCollectionViewTests`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `swift test`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift Tests/ConstruktTests/CustomLayoutCollectionViewTests.swift
git commit -m "feat: add .customLayout() modifier for custom UICollectionViewLayout subclasses"
```

---

### Task 6: Test Custom Layout Skips Compositional Layout Creation

**Files:**
- Modify: `Tests/ConstruktTests/CustomLayoutCollectionViewTests.swift`

- [ ] **Step 1: Add test verifying compositional layout is NOT created when custom layout is set**

```swift
    @Test("customLayout prevents compositional layout creation")
    func customLayoutPreventsCompositionalLayout() {
        let flowLayout = UICollectionViewFlowLayout()

        let cv = CollectionView {
            AnySection(id: CustomLayoutTestSection.main) {
                AnyCell("item", id: "item1") { _ in ContainerView() }
            }
        }
        .customLayout(flowLayout)

        let wrapper = cv.modifiableView
        // The layout should be the flow layout, not a UICollectionViewCompositionalLayout
        #expect(wrapper.collectionView.collectionViewLayout is UICollectionViewFlowLayout)
        #expect(!(wrapper.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout))
    }
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --filter CustomLayoutCollectionViewTests`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Tests/ConstruktTests/CustomLayoutCollectionViewTests.swift
git commit -m "test: verify custom layout prevents compositional layout creation"
```

---

## Option C: Protocol-Based Custom Layout Bridge

### Summary

Define a `ConstruktCollectionLayout` protocol that bridges Construkt's section/cell metadata to any `UICollectionViewLayout` subclass. The protocol provides a structured way to pass item count, section identifiers, and sizing information to custom layouts, while Construkt handles data source management.

### Pros
- Supports **any** layout algorithm with structured metadata access
- Clean separation — layout protocol defines what metadata the layout needs, Construkt provides it
- Single `CollectionView` (no nesting) — avoids cell recreation and self-sizing issues
- Layout can be swapped at runtime

### Cons
- **Per-section layout control is lost** — the custom layout governs the entire collection view (no mixing compositional sections with custom sections)
- Most implementation work of all three options
- Protocol design must be carefully considered to avoid over-engineering
- Users must implement `UICollectionViewLayout` subclass conforming to the protocol — higher barrier to entry
- Decoration items, supplementary views, and empty section hiding from the compositional path don't automatically apply

### File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Sources/Construkt/Components/CollectionView/ConstruktCollectionLayout.swift` | Protocol definition + metadata types |
| Modify | `Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift` | Add `.customLayout(_:)` accepting protocol-conforming layout, wire metadata updates |
| Create | `Sources/Construkt/Components/CollectionView/FlowCollectionViewLayout.swift` | Built-in flow layout implementing the protocol (tag cloud reference implementation) |
| Create | `Tests/ConstruktTests/ConstruktCollectionLayoutTests.swift` | Protocol conformance and metadata tests |
| Create | `Tests/ConstruktTests/FlowCollectionViewLayoutTests.swift` | Flow layout algorithm tests |

---

### Task 7: Define `ConstruktCollectionLayout` Protocol

**Files:**
- Create: `Sources/Construkt/Components/CollectionView/ConstruktCollectionLayout.swift`
- Test: `Tests/ConstruktTests/ConstruktCollectionLayoutTests.swift`

- [ ] **Step 1: Write the failing test for protocol conformance**

```swift
// Tests/ConstruktTests/ConstruktCollectionLayoutTests.swift
import Testing
@testable import ConstruktKit
import UIKit

@Suite("ConstruktCollectionLayout Protocol")
struct ConstruktCollectionLayoutTests {

    @Test("protocol provides section metadata to layout")
    func protocolProvidesSectionMetadata() {
        let layout = MockConstruktLayout()
        let metadata = CollectionLayoutMetadata(
            sections: [
                CollectionLayoutMetadata.Section(
                    identifier: "section-0",
                    itemCount: 3
                ),
                CollectionLayoutMetadata.Section(
                    identifier: "section-1",
                    itemCount: 5
                )
            ]
        )

        layout.updateMetadata(metadata)

        #expect(layout.lastMetadata?.sections.count == 2)
        #expect(layout.lastMetadata?.sections[0].identifier == "section-0")
        #expect(layout.lastMetadata?.sections[0].itemCount == 3)
        #expect(layout.lastMetadata?.sections[1].identifier == "section-1")
        #expect(layout.lastMetadata?.sections[1].itemCount == 5)
    }
}

private final class MockConstruktLayout: UICollectionViewLayout, ConstruktCollectionLayout {
    var lastMetadata: CollectionLayoutMetadata?

    func updateMetadata(_ metadata: CollectionLayoutMetadata) {
        lastMetadata = metadata
        invalidateLayout()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConstruktCollectionLayoutTests`
Expected: FAIL — `ConstruktCollectionLayout` not found

- [ ] **Step 3: Write the protocol and metadata types**

```swift
// Sources/Construkt/Components/CollectionView/ConstruktCollectionLayout.swift
import UIKit

/// Metadata about the collection view's sections and items, provided by Construkt
/// to custom layout implementations.
public struct CollectionLayoutMetadata {

    /// Metadata for a single section.
    public struct Section {
        /// The section's unique identifier (from `SectionConfigIdentifier.uniqueId`).
        public let identifier: String
        /// The number of items in this section.
        public let itemCount: Int

        public init(identifier: String, itemCount: Int) {
            self.identifier = identifier
            self.itemCount = itemCount
        }
    }

    /// Ordered array of section metadata, matching the collection view's section order.
    public let sections: [Section]

    public init(sections: [Section]) {
        self.sections = sections
    }
}

/// A protocol for custom `UICollectionViewLayout` subclasses that receive
/// structured metadata from Construkt's data source.
///
/// Conforming layouts receive `CollectionLayoutMetadata` whenever the data source
/// updates, allowing them to compute layout attributes based on section/item counts
/// and identifiers.
///
/// Usage:
/// ```swift
/// class MyCustomLayout: UICollectionViewLayout, ConstruktCollectionLayout {
///     private var metadata: CollectionLayoutMetadata?
///
///     func updateMetadata(_ metadata: CollectionLayoutMetadata) {
///         self.metadata = metadata
///         invalidateLayout()
///     }
///
///     // ... implement prepare(), layoutAttributesForElements(in:), etc.
/// }
/// ```
public protocol ConstruktCollectionLayout: UICollectionViewLayout {
    /// Called by Construkt when the data source updates with new section/item information.
    /// Implementations should store the metadata and call `invalidateLayout()`.
    func updateMetadata(_ metadata: CollectionLayoutMetadata)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ConstruktCollectionLayoutTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Construkt/Components/CollectionView/ConstruktCollectionLayout.swift Tests/ConstruktTests/ConstruktCollectionLayoutTests.swift
git commit -m "feat: add ConstruktCollectionLayout protocol and CollectionLayoutMetadata"
```

---

### Task 8: Wire Metadata Updates into `CollectionViewWrapperView`

**Files:**
- Modify: `Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift`

- [ ] **Step 1: Add metadata update call in `update(sections:)`**

After `dataSource.display(sections)` (line 249), add:

```swift
        // If using a ConstruktCollectionLayout, push metadata to the layout
        if let construktLayout = collectionView.collectionViewLayout as? ConstruktCollectionLayout {
            let metadata = CollectionLayoutMetadata(
                sections: sections.map { section in
                    CollectionLayoutMetadata.Section(
                        identifier: section.identifier.uniqueId,
                        itemCount: section.cells.count
                    )
                }
            )
            construktLayout.updateMetadata(metadata)
        }
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run full test suite**

Run: `swift test`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/Construkt/Core/Builder/CollectionView/Builder+CollectionView.swift
git commit -m "feat: wire CollectionLayoutMetadata updates to ConstruktCollectionLayout"
```

---

### Task 9: Built-in `FlowCollectionViewLayout` Reference Implementation

**Files:**
- Create: `Sources/Construkt/Components/CollectionView/FlowCollectionViewLayout.swift`
- Create: `Tests/ConstruktTests/FlowCollectionViewLayoutTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/ConstruktTests/FlowCollectionViewLayoutTests.swift
import Testing
@testable import ConstruktKit
import UIKit

@Suite("FlowCollectionViewLayout")
struct FlowCollectionViewLayoutTests {

    @Test("layout conforms to ConstruktCollectionLayout")
    func conformsToProtocol() {
        let layout = FlowCollectionViewLayout()
        #expect(layout is ConstruktCollectionLayout)
    }

    @Test("layout accepts item size provider")
    func acceptsItemSizeProvider() {
        let layout = FlowCollectionViewLayout { _, _ in
            CGSize(width: 60, height: 30)
        }
        #expect(layout.horizontalSpacing == 8) // default
        #expect(layout.lineSpacing == 8) // default
    }

    @Test("layout properties are configurable")
    func configurableProperties() {
        let layout = FlowCollectionViewLayout { _, _ in
            CGSize(width: 60, height: 30)
        }
        layout.horizontalSpacing = 12
        layout.lineSpacing = 16
        layout.sectionInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        #expect(layout.horizontalSpacing == 12)
        #expect(layout.lineSpacing == 16)
        #expect(layout.sectionInsets.top == 8)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FlowCollectionViewLayoutTests`
Expected: FAIL — `FlowCollectionViewLayout` not found

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Construkt/Components/CollectionView/FlowCollectionViewLayout.swift
import UIKit

/// A `UICollectionViewLayout` subclass that arranges items in a wrapping flow layout
/// (left-to-right, top-to-bottom). Conforms to `ConstruktCollectionLayout` for
/// automatic metadata updates from Construkt's data source.
///
/// Usage with Construkt:
/// ```swift
/// let flowLayout = FlowCollectionViewLayout { indexPath, metadata in
///     // Return the size for the item at this index path
///     return CGSize(width: computedWidth, height: 32)
/// }
/// flowLayout.horizontalSpacing = 8
/// flowLayout.lineSpacing = 12
///
/// CollectionView { ... }
///     .customLayout(flowLayout)
/// ```
public final class FlowCollectionViewLayout: UICollectionViewLayout, ConstruktCollectionLayout {

    // MARK: - Public Configuration

    /// Closure that returns the size for an item at a given index path.
    /// The second parameter provides the current layout metadata.
    public var itemSizeProvider: (IndexPath, CollectionLayoutMetadata?) -> CGSize

    /// Horizontal gap between items on the same line.
    public var horizontalSpacing: CGFloat = 8

    /// Vertical gap between lines.
    public var lineSpacing: CGFloat = 8

    /// Insets around each section's content.
    public var sectionInsets: NSDirectionalEdgeInsets = .zero

    /// Vertical spacing between sections.
    public var interSectionSpacing: CGFloat = 0

    // MARK: - Internal State

    private var metadata: CollectionLayoutMetadata?
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private var contentWidth: CGFloat = 0

    // MARK: - Init

    public init(itemSizeProvider: @escaping (IndexPath, CollectionLayoutMetadata?) -> CGSize = { _, _ in CGSize(width: 50, height: 30) }) {
        self.itemSizeProvider = itemSizeProvider
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - ConstruktCollectionLayout

    public func updateMetadata(_ metadata: CollectionLayoutMetadata) {
        self.metadata = metadata
        invalidateLayout()
    }

    // MARK: - UICollectionViewLayout Overrides

    public override var collectionViewContentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }

    public override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }

        cachedAttributes.removeAll()
        contentWidth = collectionView.bounds.width
        contentHeight = 0

        let numberOfSections = collectionView.numberOfSections
        var globalY: CGFloat = 0

        for section in 0..<numberOfSections {
            let itemCount = collectionView.numberOfItems(inSection: section)
            guard itemCount > 0 else { continue }

            if section > 0 {
                globalY += interSectionSpacing
            }

            let sectionLeading = sectionInsets.leading
            let sectionTrailing = sectionInsets.trailing
            let availableWidth = contentWidth - sectionLeading - sectionTrailing

            globalY += sectionInsets.top

            var currentX: CGFloat = sectionLeading
            var lineHeight: CGFloat = 0

            for item in 0..<itemCount {
                let indexPath = IndexPath(item: item, section: section)
                let itemSize = itemSizeProvider(indexPath, metadata)
                let itemWidth = min(itemSize.width, availableWidth)

                // Wrap to next line
                if currentX > sectionLeading && currentX + horizontalSpacing + itemWidth > contentWidth - sectionTrailing {
                    globalY += lineHeight + lineSpacing
                    currentX = sectionLeading
                    lineHeight = 0
                }

                let x = currentX
                let frame = CGRect(x: x, y: globalY, width: itemWidth, height: itemSize.height)

                let attrs = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attrs.frame = frame
                cachedAttributes.append(attrs)

                currentX = x + itemWidth + horizontalSpacing
                lineHeight = max(lineHeight, itemSize.height)
            }

            globalY += lineHeight + sectionInsets.bottom
        }

        contentHeight = globalY
    }

    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes.first { $0.indexPath == indexPath }
    }

    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FlowCollectionViewLayoutTests`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `swift test`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/Construkt/Components/CollectionView/FlowCollectionViewLayout.swift Tests/ConstruktTests/FlowCollectionViewLayoutTests.swift
git commit -m "feat: add FlowCollectionViewLayout as ConstruktCollectionLayout reference implementation"
```

---

## Option Comparison Matrix

| Criterion | Option A: Nested CV | Option B: Custom Group (Recommended) | Option C: Protocol Bridge |
|-----------|--------------------|------------------------------------|--------------------------|
| **Scope** | Small (1 modifier) | Small (1 factory + 1 calculator) | Medium (protocol + layout + wiring) |
| **Architectural changes** | None | None | Metadata bridge in `update(sections:)` |
| **Layout flexibility** | Any `UICollectionViewLayout` | Flow/wrapping only | Any `UICollectionViewLayout` |
| **Per-section composability** | Yes (each nested CV independent) | Yes (mix with list/grid/carousel) | No (custom layout governs entire CV) |
| **Selection/binding** | Works (independent delegate chains) | Works (unchanged) | Works (unchanged) |
| **Self-sizing** | Circular dependency risk | No issues | Layout's responsibility |
| **Cell recreation** | Problematic (inner CV destroyed) | No issues | No issues |
| **Pre-measured sizes** | Not required | Required | Depends on layout impl |
| **iOS compatibility** | iOS 14+ | iOS 13+ | iOS 14+ |
| **User complexity** | High (nested CV mental model) | Low (one factory call) | Medium (implement protocol) |
| **Exotic layouts** | Yes | No | Yes |

## Recommended Implementation Order

1. **Option B first** — covers the primary use case (tag cloud) with minimal effort and zero risk
2. **Option A second** — adds escape hatch for truly custom layouts via nesting
3. **Option C third** — only if there's demand for non-compositional layouts without nesting overhead

Options A and C share the `.customLayout()` modifier name but serve different purposes. If both are implemented, Option A's modifier should be the one on `CollectionView` (it's simpler), and Option C adds the protocol + metadata bridge on top. They are compatible — a `FlowCollectionViewLayout` (Option C) can be passed to `.customLayout()` (Option A/C shared modifier).

---

## Dependencies Between Options

- **B is fully independent** — can be implemented alone
- **A is fully independent** — can be implemented alone
- **C depends on A** — reuses the `.customLayout()` modifier from Option A, adds the protocol and metadata wiring on top
- If implementing C without A, the `.customLayout()` modifier from Task 5 must be implemented first (it's a prerequisite)

## Task Dependency Graph

```
Option B (independent):
  Task 1 → Task 2 → Task 3 → Task 4

Option A (independent):
  Task 5 → Task 6

Option C (depends on A's modifier):
  Task 5 → Task 7 → Task 8 → Task 9
```
