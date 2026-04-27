# TraditionalCollectionView Design Spec

## Goal

Add a `TraditionalCollectionView` component that accepts any `UICollectionViewLayout` subclass while reusing Construkt's existing `AnySection`/`AnyCell` DSL, diffable data source, and delegate forwarding. This enables layouts that `UICollectionViewCompositionalLayout` cannot express (flow/tag-cloud, circular, physics-based) without modifying the existing `CollectionView`.

## Motivation

The existing `CollectionView` is hardcoded to `UICollectionViewCompositionalLayout`. For use cases like tag/chip clouds (variable-width items wrapping to the next line), compositional layout is awkward — `NSCollectionLayoutGroup.custom` requires pre-measured item sizes and cannot self-size. A custom `UICollectionViewLayout` subclass handles this naturally, but the current architecture has no way to use one.

Rather than bolting custom layout support onto `CollectionView` (which would break compositional-specific features like `.decorationItems()`, `.backgroundDecoration()`, per-section `.layout{}`, and empty section hiding), we create a clean sibling component.

## Architecture

`TraditionalCollectionView` is a **sibling** to `CollectionView`, not a subclass. Both share:

- `AnySection` / `AnyCell` DSL and `@AnySectionResultBuilder`
- `SectionConfig` / `CellConfig` data types
- `AnyCollectionDiffableDataSource` for incremental diffing
- `CellConfigAdapter` for delegate forwarding (selection, prefetch)
- `SupplementaryController` for header/footer dequeuing

`TraditionalCollectionView` has its own `TraditionalCollectionViewWrapperView` because:
1. `update(sections:)` is fundamentally different — no compositional layout creation, no decoration registration, no empty section hiding via layout manipulation
2. The `UICollectionView` is initialized with the user-provided layout, not a placeholder
3. Supplementary view sizing needs `UICollectionViewDelegateFlowLayout` support

The ~100 lines of shared boilerplate (delegate forwarding, scroll observation, refresh control, empty state) are duplicated rather than extracted into a base class, to avoid refactoring the existing `CollectionView`.

## DSL

```swift
TraditionalCollectionView(layout: myFlowLayout) {
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

## Component: `TraditionalCollectionView`

### Struct

```swift
public struct TraditionalCollectionView: ModifiableView {
    public let modifiableView: TraditionalCollectionViewWrapperView

    public init(
        layout: UICollectionViewLayout,
        @AnySectionResultBuilder content: () -> AnyViewBinding<[SectionConfig]>
    )
}
```

- Stores the wrapper view (which holds the `UICollectionView` with the provided layout)
- Observes the sections binding on `.main` and calls `modifiableView.update(sections:)`
- Same pattern as `CollectionView.init`

### WrapperView

```swift
public class TraditionalCollectionViewWrapperView: UIView, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
```

**Properties (same as `CollectionViewWrapperView`):**
- `collectionView: UICollectionView` — initialized with the user-provided layout
- `refreshControl: UIRefreshControl`
- `dataSource: AnyCollectionDiffableDataSource`
- `adapter: CellConfigAdapter`
- `currentSectionMap: [String: SectionConfig]`
- `emptyStateProvider`, `emptyStateView`
- `onScroll`, `onWillBeginDragging`, `onDidEndDragging`, `onDidEndDecelerating`
- `onRefresh`

**No `hasInitializedLayout`** — the layout is set at init time, not lazily.

**Reuses `EmptySupplementaryView` pattern** — a zero-height fallback reusable view registered at init time. When a header/footer is hidden, the supplementary provider returns this fallback. The `UICollectionViewDelegateFlowLayout` methods return `.zero` size for hidden supplementaries, so the fallback view takes no space.

### `update(sections:)` Method

Simpler than `CollectionView`'s version:

1. Rebuild `currentSectionMap` from incoming sections
2. Call `dataSource.display(sections)` for incremental diffing
3. No compositional layout creation
4. No decoration view registration
5. No empty section hiding via layout manipulation

### Supplementary View Provider

Same pattern as `CollectionView`: the data source's `supplementaryViewProvider` closure looks up the section from `currentSectionMap`, checks for header/footer, dequeues via `SupplementaryController.dequeue()`.

For hidden headers/footers: returns a zero-height fallback view (registered at init time), same as `CollectionView`.

### `UICollectionViewDelegateFlowLayout` Support

When the layout is a `UICollectionViewFlowLayout`, the wrapper view provides header/footer sizing:

```swift
func collectionView(_ collectionView: UICollectionView,
                    layout: UICollectionViewLayout,
                    referenceSizeForHeaderInSection section: Int) -> CGSize

func collectionView(_ collectionView: UICollectionView,
                    layout: UICollectionViewLayout,
                    referenceSizeForFooterInSection section: Int) -> CGSize
```

- If a non-hidden header/footer exists for the section → return `CGSize(width: collectionView.bounds.width, height: 44)` as a reasonable default. Users who need different sizing should configure their `UICollectionViewFlowLayout`'s `headerReferenceSize`/`footerReferenceSize` directly, or provide a custom layout that handles supplementary sizing.
- If no header/footer, or hidden → return `.zero` (suppresses supplementary view creation)

This only activates when the layout is a `UICollectionViewFlowLayout` (checked via `is UICollectionViewFlowLayout`). Other custom layouts handle supplementary views through their own mechanisms.

### Delegate Forwarding

Identical to `CollectionViewWrapperView`:
- `didSelectItemAt` → `adapter`
- `prefetchItemsAt` → `adapter`
- `cancelPrefetchingForItemsAt` → `adapter`

### Scroll Observation

Identical to `CollectionViewWrapperView`:
- `scrollViewDidScroll`, `scrollViewWillBeginDragging`, `scrollViewDidEndDragging`, `scrollViewDidEndDecelerating`

### Refresh Control

Identical to `CollectionViewWrapperView`:
- `setupRefreshControl(action:)`, `handleRefresh()`, `setRefreshing(_:)`

### Empty State

Identical to `CollectionViewWrapperView`:
- `emptyStateProvider`, `updateEmptyState(show:)`

## Modifier Compatibility

### Works As-Is on `AnySection`

| Modifier | Why |
|---|---|
| `.onSelect(_:)` | Goes through `CellConfigAdapter`, layout-agnostic |
| `.onRoute(_:)` | Same as `.onSelect` |
| `.onSelect(on:_:)` | Same |
| `.header(_:)` | Stored in `SectionConfig`, dequeued by supplementary provider |
| `.footer(_:)` | Same |
| `.headerHidden(when:)` | Toggles `isHidden` on `SupplementaryController`, provider returns fallback |
| `.footerHidden(when:)` | Same |
| `.shimmer(_:count:when:)` | Swaps cell data, layout-agnostic |

### Silently Ignored on `AnySection`

| Modifier | Why Ignored |
|---|---|
| `.layout{}` | `layoutProvider` is set on `SectionConfig` but `TraditionalCollectionView` never reads it — the layout is set at init |
| `.decorationItems(_:)` | `layoutModifiers` are set but never applied — no compositional section provider to apply them to |
| `.decorationItem(_:)` | Same |
| `.backgroundDecoration()` | `decorationProviders` and `layoutModifiers` are set but never consumed |

These modifiers don't crash — they just have no effect. The data is stored in `SectionConfig` but `TraditionalCollectionViewWrapperView.update(sections:)` never reads `layoutProvider`, `layoutModifiers`, or `decorationProviders`.

### `.emptyState()` on `AnySection`

This modifier swaps cells when the section is empty and provides a fallback `NSCollectionLayoutSection`. In `TraditionalCollectionView`, the cell swap works (the empty cell is displayed), but the layout fallback has no effect (the user's layout governs sizing). The empty cell will be sized by whatever the user's layout does. This is acceptable — the content appears, just sized by the custom layout.

### Works on `TraditionalCollectionView`

| Modifier | Notes |
|---|---|
| `.contentInset(top:left:bottom:right:)` | Adjusts scroll view content inset |
| `.onRefresh(_:action:)` | Installs `UIRefreshControl` |
| `.onScroll(_:)` | Scroll delegate forwarding |
| `.onWillBeginDragging(_:)` | Same |
| `.onDidEndDragging(_:)` | Same |
| `.onDidEndDecelerating(_:)` | Same |
| `.emptyState(when:_:)` | View-level empty state swap |

## File Structure

| File | Action |
|---|---|
| `Sources/Construkt/Core/Builder/CollectionView/Builder+TraditionalCollectionView.swift` | Create |
| `Tests/ConstruktTests/TraditionalCollectionViewTests.swift` | Create |

No existing files are modified.

## Testing Strategy

1. **Unit test:** Verify `TraditionalCollectionView` creates a `UICollectionView` with the provided layout
2. **Unit test:** Verify `update(sections:)` populates the diffable data source correctly
3. **Unit test:** Verify `UICollectionViewDelegateFlowLayout` returns correct header/footer sizes based on `SectionConfig`
4. **Unit test:** Verify selection forwarding works through `CellConfigAdapter`
5. **Integration test:** Verify the full DSL pipeline — `AnySection` with items → `SectionConfig` → data source snapshot

Tests use Swift Testing framework (`@Suite`, `@Test`, `#expect`) following existing patterns in `AnySectionBindingTests.swift`.
