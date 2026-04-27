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
public class TraditionalCollectionViewWrapperView: UIView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

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
