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

public struct CollectionLayoutSectionBuilder {
    public let section: NSCollectionLayoutSection
    
    internal init(section: NSCollectionLayoutSection) {
        self.section = section
    }
    
    // MARK: - Factory Methods
    
    /// Creates a 1-column list layout.
    public static func list(
        itemHeight: NSCollectionLayoutDimension,
        itemInsets: NSDirectionalEdgeInsets = .zero
    ) -> CollectionLayoutSectionBuilder {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: itemHeight)
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = itemInsets
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: itemHeight)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        return CollectionLayoutSectionBuilder(section: section)
    }
    
    /// Creates a multi-column grid layout.
    public static func grid(
        itemHeight: NSCollectionLayoutDimension,
        columns: Int,
        itemInsets: NSDirectionalEdgeInsets = .zero
    ) -> CollectionLayoutSectionBuilder {
        let fraction = 1.0 / CGFloat(columns)
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: itemHeight)
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = itemInsets
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: itemHeight)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        return CollectionLayoutSectionBuilder(section: section)
    }
    
    /// Creates a horizontally scrolling carousel layout.
    public static func carousel(
        itemWidth: NSCollectionLayoutDimension,
        itemHeight: NSCollectionLayoutDimension,
        itemInsets: NSDirectionalEdgeInsets = .zero
    ) -> CollectionLayoutSectionBuilder {
        let itemSize = NSCollectionLayoutSize(widthDimension: itemWidth, heightDimension: itemHeight)
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = itemInsets
        
        let groupSize = NSCollectionLayoutSize(widthDimension: itemWidth, heightDimension: itemHeight)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        return CollectionLayoutSectionBuilder(section: section)
    }
    
    // MARK: - Modifiers
    
    @discardableResult
    public func spacing(_ spacing: CGFloat) -> Self {
        section.interGroupSpacing = spacing
        return self
    }
    
    @discardableResult
    public func insets(_ insets: NSDirectionalEdgeInsets) -> Self {
        section.contentInsets = insets
        return self
    }
    
    @discardableResult
    public func insets(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) -> Self {
        section.contentInsets = NSDirectionalEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        return self
    }
    
    @discardableResult
    public func orthogonalScrolling(_ behavior: UICollectionLayoutSectionOrthogonalScrollingBehavior) -> Self {
        section.orthogonalScrollingBehavior = behavior
        return self
    }
    
    @discardableResult
    public func supplementaryItems(_ items: [NSCollectionLayoutBoundarySupplementaryItem]) -> Self {
        section.boundarySupplementaryItems = items
        return self
    }
    
    @discardableResult
    public func supplementaryHeader(
        height: NSCollectionLayoutDimension,
        contentInsets: NSDirectionalEdgeInsets = .zero,
        isSticky: Bool = false
    ) -> Self {
        let header = NSCollectionLayoutBoundarySupplementaryItem.header(height: height, isSticky: isSticky)
        header.contentInsets = contentInsets
        var newSupplementaries = section.boundarySupplementaryItems
        newSupplementaries.append(header)
        section.boundarySupplementaryItems = newSupplementaries
        return self
    }
    
    @discardableResult
    public func supplementaryFooter(
        height: NSCollectionLayoutDimension,
        contentInsets: NSDirectionalEdgeInsets = .zero,
        isSticky: Bool = false
    ) -> Self {
        let footer = NSCollectionLayoutBoundarySupplementaryItem.footer(height: height, isSticky: isSticky)
        footer.contentInsets = contentInsets
        var newSupplementaries = section.boundarySupplementaryItems
        newSupplementaries.append(footer)
        section.boundarySupplementaryItems = newSupplementaries
        return self
    }
    
    @discardableResult
    public func decorationItems(_ items: [NSCollectionLayoutDecorationItem]) -> Self {
        section.decorationItems = items
        return self
    }
    
    @discardableResult
    public func decorationItem(_ item: NSCollectionLayoutDecorationItem) -> Self {
        var newDecorations = section.decorationItems
        newDecorations.append(item)
        section.decorationItems = newDecorations
        return self
    }
}

extension NSCollectionLayoutBoundarySupplementaryItem {
    public static func header(
        height: NSCollectionLayoutDimension,
        isSticky: Bool = false
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .entireWidth(withHeight: height),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.pinToVisibleBounds = isSticky
        return header
    }
    
    public static func footer(
        height: NSCollectionLayoutDimension,
        isSticky: Bool = false
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .entireWidth(withHeight: height),
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        header.pinToVisibleBounds = isSticky
        return header
    }
}


extension NSCollectionLayoutSize {
    public static func entireWidth(withHeight height: NSCollectionLayoutDimension) -> NSCollectionLayoutSize {
        return NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: height
        )
    }
}

extension NSDirectionalEdgeInsets {
    public init(v: CGFloat, h: CGFloat) {
        self.init(top: v, leading: h, bottom: v, trailing: h)
    }
}
