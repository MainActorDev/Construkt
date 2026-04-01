//
//  👨‍💻 Created by @thatswiftdev on 26/09/25.
//
//  © 2025, https://github.com/thatswiftdev. All rights reserved.
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

import UIKit

public typealias AnyCellRegistration<Cell: UICollectionViewCell, Item> = UICollectionView.CellRegistration<Cell, Item>

/// A type alias for a diffable data source snapshot mapping `SectionConfig` sections to `CellConfig` items.
public typealias AnyCollectionSnapshot = NSDiffableDataSourceSnapshot<SectionConfig, CellConfig>

/// A type alias for a `UICollectionViewDiffableDataSource` driven by `SectionConfig` and `CellConfig`.
public typealias AnyCollectionDiffableDataSource = UICollectionViewDiffableDataSource<SectionConfig, CellConfig>

public extension AnyCollectionDiffableDataSource {
    func display(_ sections: [SectionConfig], completion: (() -> Void)? = nil) {
        var newSnapshot = AnyCollectionSnapshot()
        
        // 1. Build the new structure
        for section in sections {
            if !section.cells.isEmpty {
                newSnapshot.appendSections([section])
                newSnapshot.appendItems(section.cells, toSection: section)
            }
        }
        
        // 2. Calculate reloads *before* applying
        let currentSnapshot = snapshot()
        let isFirstLoad = currentSnapshot.numberOfSections == 0
        
        if !isFirstLoad {
            let oldItemMap = buildContentMap(from: currentSnapshot)
            
            // 2a. Find items that need reloading
            let itemsToReload = newSnapshot.itemIdentifiers.filter { newItem in
                guard let oldHash = oldItemMap[newItem.id] else { return false }
                guard let newHash = newItem.contentHash else { return true }
                return newHash != oldHash
            }
            
            // 2b. Find sections that need reloading (header/footer changes)
            // We can't rely on SectionConfig equality since it only checks uniqueId.
            // We need to manually check if the supplementaries changed.
            let oldSectionMap = Dictionary(uniqueKeysWithValues: currentSnapshot.sectionIdentifiers.map { ($0.identifier.uniqueId, $0) })
            
            let sectionsToReload = newSnapshot.sectionIdentifiers.filter { newSection in
                guard let oldSection = oldSectionMap[newSection.identifier.uniqueId] else { return false }
                
                // Check if header changed ID
                if let newHeader = newSection.header, let oldHeader = oldSection.header {
                    if newHeader.id != oldHeader.id { return true }
                    if newHeader.isHidden != oldHeader.isHidden { return true }
                } else if (newSection.header == nil) != (oldSection.header == nil) {
                    return true
                }
                
                // Check if footer changed ID
                if let newFooter = newSection.footer, let oldFooter = oldSection.footer {
                    if newFooter.id != oldFooter.id { return true }
                    if newFooter.isHidden != oldFooter.isHidden { return true }
                } else if (newSection.footer == nil) != (oldSection.footer == nil) {
                    return true
                }

                return false
            }
            
            if !itemsToReload.isEmpty {
                newSnapshot.reloadItems(itemsToReload)
            }
            if !sectionsToReload.isEmpty {
                newSnapshot.reloadSections(sectionsToReload)
            }
        }
        
        // 3. Apply once
        apply(newSnapshot, animatingDifferences: false, completion: completion)
    }
    
    func appendItems(
        _ items: [CellConfig],
        into identifier: SectionConfigIdentifier,
        animated: Bool = false
    ) {
        let displayedSections = snapshot().sectionIdentifiers
        let section = displayedSections.section(identifier: identifier)
        
        var snapshot = snapshot()
        snapshot.appendItems(items, toSection: section)
        apply(snapshot, animatingDifferences: animated)
    }
    
    func deleteItems(_ items: [CellConfig]) {
        var snapshot = snapshot()
        snapshot.deleteItems(items)
        apply(snapshot, animatingDifferences: true)
    }
    
    func section(at index: Int) -> SectionConfig? {
        return snapshot().sectionIdentifiers[safe: index]
    }
    
    func sectionIdentifier(at index: Int) -> String? {
        return snapshot().sectionIdentifiers[safe: index]?.identifier.uniqueId
    }
    
    // MARK: - Private Helpers
    
    /// Builds a lookup of [CellConfig.id → contentHash] from the current snapshot
    private func buildContentMap(
        from snapshot: AnyCollectionSnapshot
    ) -> [AnyHashable: AnyHashable] {
        var map: [AnyHashable: AnyHashable] = [:]
        for item in snapshot.itemIdentifiers {
            if let hash = item.contentHash {
                map[item.id] = hash
            }
        }
        return map
    }
}
