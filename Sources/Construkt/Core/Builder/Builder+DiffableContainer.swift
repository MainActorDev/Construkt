//
//  Builder+DiffableContainer.swift
//  Construkt
//
//  A container view that tracks children by identity and only adds/removes the delta.
//  Unlike `DynamicContainerView` which rebuilds its entire child hierarchy on every
//  binding emission, `DiffableContainerView` preserves existing views whose ID persists.
//

import UIKit

// MARK: - TaggedView

/// Associates a stable identity with a declarative `View` recipe.
/// Used by `DiffableContainerView` to track which children should be preserved across updates.
public struct TaggedView {
    public let id: AnyHashable
    public let view: View

    public init(id: some Hashable, view: View) {
        self.id = AnyHashable(id)
        self.view = view
    }
}

// MARK: - DiffableContainerView

/// A container that observes a binding of `[TaggedView]` and performs identity-based
/// incremental updates — only adding/removing the delta rather than rebuilding everything.
///
/// Existing subviews whose ID persists across emissions are **never rebuilt**.
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

// MARK: - DiffableContainerInternalView

/// The internal `UIView` subclass that performs identity-based diffing of child views.
public final class DiffableContainerInternalView: UIView {

    private var childrenByID: [AnyHashable: UIView] = [:]
    private var currentOrder: [AnyHashable] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Applies an incremental diff against the current child set.
    ///
    /// 1. Removes subviews whose ID is no longer present.
    /// 2. Adds subviews for new IDs (built from the `View` recipe).
    /// 3. Reorders to match the new order.
    /// 4. Existing views whose ID persists are **not** rebuilt.
    func applyDiff(_ newItems: [TaggedView]) {
        let newIDs = newItems.map { $0.id }
        let newIDSet = Set(newIDs)
        let oldIDSet = Set(currentOrder)

        // Remove views whose ID is no longer present
        for id in oldIDSet.subtracting(newIDSet) {
            childrenByID[id]?.removeFromSuperview()
            childrenByID.removeValue(forKey: id)
        }

        // Add views for new IDs
        for item in newItems where !oldIDSet.contains(item.id) {
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

        // Reorder to match new order
        for (index, id) in newIDs.enumerated() {
            if let view = childrenByID[id] {
                insertSubview(view, at: index)
            }
        }

        currentOrder = newIDs
    }

    // MARK: - Hit Testing

    /// Pass-through hit testing for clear backgrounds (same pattern as `BuilderInternalContainerView`).
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self && backgroundColor == .clear {
            if let recognizers = gestureRecognizers, !recognizers.isEmpty {
                return hitView
            }
            return nil
        }
        return hitView
    }
}
