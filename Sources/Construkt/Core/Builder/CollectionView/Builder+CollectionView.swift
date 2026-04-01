//
//  👨‍💻 Created by @thatswiftdev on 04/02/26.
//
//  © 2026, https://github.com/thatswiftdev. All rights reserved.
//
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
//

import UIKit

// MARK: - CollectionView Wrapper

/// A declarative builder component that bridges Construkt's View architecture with modern
/// `UICollectionView` APIs powered by Diffable Data Sources and Compositional Layouts.
public struct CollectionView: ModifiableView {
    
    public let modifiableView = CollectionViewWrapperView()
    
    /// Initializes a declarative collection view dynamically mapped to a reactive stream of `Section` arrays.
    public init(@AnySectionResultBuilder content: () -> AnyViewBinding<[SectionConfig]>) {
        let sectionsBinding = content()
        
        sectionsBinding.observe(on: .main) { [weak modifiableView] sections in
            modifiableView?.update(sections: sections)
        }.store(in: modifiableView.cancelBag)
    }
}

/// The internal `UIView` subclass responsible for hosting the actual `UICollectionView` and
/// maintaining the Diffable Data Source mappings.
public class CollectionViewWrapperView: UIView, UICollectionViewDelegate {
    /// A zero-height supplementary view returned when a header/footer is hidden.
    /// Overrides `preferredLayoutAttributesFitting` so that UICollectionViewCompositionalLayout
    /// collapses this view to zero height when using `.estimated` sizing.
    private final class EmptySupplementaryView: UICollectionReusableView {
        override func preferredLayoutAttributesFitting(
            _ layoutAttributes: UICollectionViewLayoutAttributes
        ) -> UICollectionViewLayoutAttributes {
            let attrs = super.preferredLayoutAttributesFitting(layoutAttributes)
            attrs.frame.size.height = 0
            attrs.size.height = 0
            return attrs
        }
    }

    private func fallbackSupplementary(
        in collectionView: UICollectionView,
        kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView? {
        if kind == UICollectionView.elementKindSectionHeader {
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FallbackEmptyHeader", for: indexPath)
        } else if kind == UICollectionView.elementKindSectionFooter {
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FallbackEmptyFooter", for: indexPath)
        }
        return nil
    }
    
    public private(set) lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        cv.backgroundColor = .clear
        cv.clipsToBounds = false
        cv.delegate = self
        cv.register(EmptySupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "FallbackEmptyHeader")
        cv.register(EmptySupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "FallbackEmptyFooter")
        return cv
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var dataSource: AnyCollectionDiffableDataSource = {
        let ds = AnyCollectionDiffableDataSource(
            collectionView: collectionView,
            cellProvider: { (collectionView, index, item) in
                return item.cell(in: collectionView, at: index)
            }
        )
        
        ds.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader || kind == UICollectionView.elementKindSectionFooter else {
                return nil
            }

            // Identify section via currentSectionMap for O(1) lookup and guaranteed
            // consistency with the layout provider (both read the same source of truth).
            guard let self = self,
                  let identifier = self.dataSource.sectionIdentifier(at: indexPath.section),
                  let section = self.currentSectionMap[identifier]
            else {
                return self?.fallbackSupplementary(
                    in: collectionView,
                    kind: kind,
                    at: indexPath
                )
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

            return self.fallbackSupplementary(
                in: collectionView,
                kind: kind,
                at: indexPath
            )
            
        }
        
        return ds
    }()
    
    private lazy var adapter: CellConfigAdapter = {
        return CellConfigAdapter(dataSource: dataSource)
    }()
    
    /// Cached section map for O(1) layout provider lookups
    private var currentSectionMap: [String: SectionConfig] = [:]
    
    /// Tracks whether the compositional layout has been set up
    private var hasInitializedLayout = false
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
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
        // Update the cached section map before applying data
        currentSectionMap = Dictionary(
            uniqueKeysWithValues: sections.map { ($0.identifier.uniqueId, $0) }
        )
        
        let activeLayout: UICollectionViewLayout
        if !hasInitializedLayout {
            // Create layout once — the provider closure reads from currentSectionMap.
            // Boundary supplementary items are NEVER removed based on isHidden.
            // Instead, the supplementaryViewProvider returns a zero-height EmptySupplementaryView
            // when hidden, allowing the layout structure to stay stable across visibility changes.
            // This avoids recreating the layout (which disrupts visibleItemsInvalidationHandler,
            // zIndex, orthogonalScrollingBehavior, etc.) and avoids the iOS 16 bug where
            // UICollectionViewCompositionalLayout caches section layouts aggressively and
            // does not re-invoke the section provider after invalidateLayout().
            let layout = UICollectionViewCompositionalLayout { [weak self] index, _ in
                guard let self = self,
                      let sect = self.dataSource.sectionIdentifier(at: index) else { return nil }
                
                // O(1) Lookup
                if let sectionController = self.currentSectionMap[sect],
                   let sectionLayout = sectionController.layoutProvider?(sect) {
                    
                    // Apply any layout modifiers (e.g. from .decorationItem used out of order)
                    sectionController.layoutModifiers.forEach { $0(sectionLayout) }
                    
                    // Hide empty sections logic
                    if self.dataSource.snapshot().numberOfItems(inSection: sectionController) == 0 {
                        sectionLayout.contentInsets = .zero
                        sectionLayout.decorationItems = []
                        sectionLayout.boundarySupplementaryItems = []
                    } else {
                        // Only remove boundary items for headers/footers that don't exist at all.
                        // Hidden headers/footers keep their boundary item so the supplementary
                        // provider is always called — it returns a zero-height fallback view.
                        sectionLayout.boundarySupplementaryItems = sectionLayout.boundarySupplementaryItems.filter { item in
                            if item.elementKind == UICollectionView.elementKindSectionHeader {
                                return sectionController.header != nil
                            } else if item.elementKind == UICollectionView.elementKindSectionFooter {
                                return sectionController.footer != nil
                            }
                            return true
                        }
                    }
                    
                    return sectionLayout
                }
                
                return nil
            }
            collectionView.setCollectionViewLayout(layout, animated: false)
            hasInitializedLayout = true
            activeLayout = layout
        } else {
            activeLayout = collectionView.collectionViewLayout
        }
        
        // Extract all unique background decoration element kinds from active layouts
        var customBackgroundKinds = Set<String>()
        
        for section in sections {
            if let sectLayout = section.layoutProvider?(section.identifier.uniqueId) {
                section.layoutModifiers.forEach { $0(sectLayout) }
                sectLayout.decorationItems.forEach { item in
                    if item.elementKind.hasPrefix("custom_bg_") {
                        customBackgroundKinds.insert(item.elementKind)
                    }
                }
            }
        }
        
        // Register all variations dynamically (ignores already registered safely)
        for kind in customBackgroundKinds {
            activeLayout.register(CustomBackgroundReusableView.self, forDecorationViewOfKind: kind)
        }
        
        // Apply data changes (smart incremental diffing).
        // When isHidden changes, DataSource.display() detects the change and calls
        // reloadSections, which causes UIKit to re-request supplementary views from the
        // supplementaryViewProvider — swapping between the real header and the zero-height fallback.
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

public extension CollectionView {
    /// Dynamically swaps the internal collection view display for a custom empty state `View` when the
    /// bounding binding resolves to `true`.
    func emptyState<B: ViewBinding>(when binding: B, @ViewResultBuilder _ content: @escaping () -> ViewConvertable) -> CollectionView where B.Value == Bool {
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

public extension ModifiableView where Base: CollectionViewWrapperView {
    
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
