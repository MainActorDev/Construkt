//
//  Builder+DynamicForEach.swift
//  Construkt
//
//  Identity-aware dynamic view builder with minimal diffing.
//

import UIKit

// MARK: - DynamicForEachChangeset

/// A minimal diff result describing the changes between two identity-keyed collections.
public struct DynamicForEachChangeset {

    /// Represents a positional move of an item that exists in both old and new arrays.
    public struct Move: Equatable {
        public let from: Int
        public let to: Int
    }

    /// Indices in the OLD array of items that were removed, sorted descending for safe removal.
    public let removes: [Int]
    /// Indices in the NEW array of items that were inserted, sorted ascending for safe insertion.
    public let inserts: [Int]
    /// Items present in both arrays but at different relative positions among survivors.
    public let moves: [Move]

    /// Computes a minimal changeset between two `Identifiable` arrays.
    public static func diff<Item: Identifiable>(old: [Item], new: [Item]) -> DynamicForEachChangeset {
        let oldIDs = old.map { $0.id }
        let newIDs = new.map { $0.id }

        let oldIDSet = Set(oldIDs)
        let newIDSet = Set(newIDs)

        // Removes: IDs in old but not in new → old indices, sorted descending
        let removes = oldIDs.enumerated()
            .filter { !newIDSet.contains($0.element) }
            .map { $0.offset }
            .sorted(by: >)

        // Inserts: IDs in new but not in old → new indices, sorted ascending
        let inserts = newIDs.enumerated()
            .filter { !oldIDSet.contains($0.element) }
            .map { $0.offset }
            .sorted()

        // Moves: IDs in both but at different relative positions among survivors
        // Build the survivor subsequences preserving relative order
        let survivorIDs = oldIDs.filter { newIDSet.contains($0) }
        let newSurvivorIDs = newIDs.filter { oldIDSet.contains($0) }

        // Build old-index map for survivors
        var oldIndexMap: [Item.ID: Int] = [:]
        for (index, id) in oldIDs.enumerated() {
            if newIDSet.contains(id) {
                oldIndexMap[id] = index
            }
        }

        // Build new-index map for survivors
        var newIndexMap: [Item.ID: Int] = [:]
        for (index, id) in newIDs.enumerated() {
            if oldIDSet.contains(id) {
                newIndexMap[id] = index
            }
        }

        // Detect moves: items whose relative position changed among survivors
        var moves: [Move] = []
        for (newPos, id) in newSurvivorIDs.enumerated() {
            let oldPos = survivorIDs.firstIndex(of: id)!
            if oldPos != newPos {
                if let oldIdx = oldIndexMap[id], let newIdx = newIndexMap[id] {
                    moves.append(Move(from: oldIdx, to: newIdx))
                }
            }
        }

        // Deduplicate moves (avoid reporting both sides of a swap)
        var seen: Set<Int> = []
        var dedupedMoves: [Move] = []
        for move in moves {
            if !seen.contains(move.from) && !seen.contains(move.to) {
                dedupedMoves.append(move)
                seen.insert(move.from)
                seen.insert(move.to)
            }
        }

        return DynamicForEachChangeset(removes: removes, inserts: inserts, moves: dedupedMoves)
    }
}

// MARK: - DynamicForEach

/// A reactive, identity-aware builder component that diffs by `Identifiable.id` and applies
/// minimal insert/remove operations to a `UIStackView`.
///
/// Unlike `DynamicItemViewBuilder`, this class tracks identity across updates and exposes
/// a `lastChangeset` for efficient incremental UI updates.
public class DynamicForEach<Item: Identifiable>: AnyIndexableViewBuilder {

    public var items: [Item] {
        didSet {
            let changeset = DynamicForEachChangeset.diff(old: oldValue, new: items)
            lastChangeset = changeset
            updatePublisher.send(())
        }
    }

    public var count: Int { items.count }
    public var updated: Signal<Void>? { updatePublisher }
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

    /// Applies the most recent changeset to a `UIStackView`, performing minimal insert/remove operations.
    /// Call this after updating `items` to efficiently reconcile the stack's arranged subviews.
    @MainActor
    public func applyChangeset(to stackView: UIStackView) {
        guard let changeset = lastChangeset else { return }

        // 1. Remove views at old indices (sorted descending so indices stay valid)
        for index in changeset.removes {
            let view = stackView.arrangedSubviews[index]
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // 2. Insert new views at new indices (sorted ascending so indices stay valid)
        for index in changeset.inserts {
            if let view = self.view(at: index)?.build() {
                stackView.insertArrangedSubview(view, at: index)
            }
        }

        // 3. Apply moves by reordering arranged subviews to match new item order.
        // After removes and inserts, the stack should have the correct count.
        // We reorder by removing and reinserting at the target position.
        for move in changeset.moves {
            let currentCount = stackView.arrangedSubviews.count
            // Translate the move's `from` index to the current stack position
            // after removes have been applied. Since removes are descending,
            // indices below the removed ones shift down.
            var adjustedFrom = move.from
            for removedIndex in changeset.removes {
                if removedIndex < move.from {
                    adjustedFrom -= 1
                }
            }
            guard adjustedFrom >= 0, adjustedFrom < currentCount else { continue }
            guard move.to >= 0, move.to < currentCount else { continue }

            let view = stackView.arrangedSubviews[adjustedFrom]
            stackView.removeArrangedSubview(view)
            stackView.insertArrangedSubview(view, at: move.to)
        }
    }
}
