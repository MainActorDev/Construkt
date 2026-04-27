//
//  TagCloudView.swift
//  Construkt
//

import UIKit
import ConstruktKit

// MARK: - Section Identifier

enum TagCloudSection: String, SectionConfigIdentifier {
    case trending
    case genres
    case moods
    
    var uniqueId: String { rawValue }
}

// MARK: - Tag Model

struct Tag: Hashable {
    let id: String
    let name: String
    let color: UIColor
    
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tag Cloud View

struct TagCloudView: ViewConvertable {
    
    // MARK: - Sample Data
    
    private let trendingTags: [Tag] = [
        Tag(id: "t1", name: "Action", color: UIColor("#ef4444")),
        Tag(id: "t2", name: "Sci-Fi", color: UIColor("#8b5cf6")),
        Tag(id: "t3", name: "Comedy", color: UIColor("#f59e0b")),
        Tag(id: "t4", name: "Drama", color: UIColor("#3b82f6")),
        Tag(id: "t5", name: "Horror", color: UIColor("#dc2626")),
        Tag(id: "t6", name: "Romance", color: UIColor("#ec4899")),
        Tag(id: "t7", name: "Thriller", color: UIColor("#6366f1")),
        Tag(id: "t8", name: "Animation", color: UIColor("#10b981")),
        Tag(id: "t9", name: "Documentary", color: UIColor("#14b8a6")),
        Tag(id: "t10", name: "Fantasy", color: UIColor("#a855f7")),
    ]
    
    private let genreTags: [Tag] = [
        Tag(id: "g1", name: "Cyberpunk", color: UIColor("#06b6d4")),
        Tag(id: "g2", name: "Film Noir", color: UIColor("#64748b")),
        Tag(id: "g3", name: "Western", color: UIColor("#d97706")),
        Tag(id: "g4", name: "Musical", color: UIColor("#e879f9")),
        Tag(id: "g5", name: "Superhero", color: UIColor("#2563eb")),
        Tag(id: "g6", name: "Indie", color: UIColor("#84cc16")),
        Tag(id: "g7", name: "Noir", color: UIColor("#475569")),
        Tag(id: "g8", name: "Slasher", color: UIColor("#b91c1c")),
        Tag(id: "g9", name: "Mockumentary", color: UIColor("#0d9488")),
        Tag(id: "g10", name: "Kaiju", color: UIColor("#7c3aed")),
        Tag(id: "g11", name: "Heist", color: UIColor("#ea580c")),
        Tag(id: "g12", name: "Dystopian", color: UIColor("#4f46e5")),
    ]
    
    private let moodTags: [Tag] = [
        Tag(id: "m1", name: "Feel Good", color: UIColor("#fbbf24")),
        Tag(id: "m2", name: "Mind-Bending", color: UIColor("#7c3aed")),
        Tag(id: "m3", name: "Adrenaline Rush", color: UIColor("#ef4444")),
        Tag(id: "m4", name: "Chill", color: UIColor("#06b6d4")),
        Tag(id: "m5", name: "Tear Jerker", color: UIColor("#3b82f6")),
        Tag(id: "m6", name: "Edge of Seat", color: UIColor("#f97316")),
        Tag(id: "m7", name: "Nostalgic", color: UIColor("#a78bfa")),
        Tag(id: "m8", name: "Dark & Gritty", color: UIColor("#374151")),
    ]
    
    // MARK: - Body
    
    func asViews() -> [View] {
        let layout = AlignedCollectionViewFlowLayout()
        layout.estimatedItemSize = CGSize(width: 110, height: 30)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = .init(top: 4, left: 0, bottom: 4, right: 0)
        layout.verticalAlignment = .top
        layout.horizontalAlignment = .leading
        layout.headerReferenceSize = CGSize(width: 0, height: 44)
        
        return Screen {
            TraditionalCollectionView(layout: layout) {
                trendingSection
                genresSection
                moodsSection
            }
            .contentInset(top: 16, bottom: 32)
        }
        .backgroundColor(UIColor("#0A0A0A"))
        .asViews()
    }
    
    // MARK: - Sections
    
    private var trendingSection: AnySection {
        AnySection(id: TagCloudSection.trending, items: trendingTags) { tag in
            AnyCell(tag, id: tag.id) { model in
                TagChipCell(tag: model)
            }
        }
        .header {
            Header {
                SectionHeaderLabel(title: "TRENDING")
            }
        }
        .onSelect { (tag: Tag) in
            print("Selected trending tag: \(tag.name)")
        }
    }
    
    private var genresSection: AnySection {
        AnySection(id: TagCloudSection.genres, items: genreTags) { tag in
            AnyCell(tag, id: tag.id) { model in
                TagChipCell(tag: model)
            }
        }
        .header {
            Header {
                SectionHeaderLabel(title: "GENRES")
            }
        }
        .onSelect { (tag: Tag) in
            print("Selected genre tag: \(tag.name)")
        }
    }
    
    private var moodsSection: AnySection {
        AnySection(id: TagCloudSection.moods, items: moodTags) { tag in
            AnyCell(tag, id: tag.id) { model in
                TagChipCell(tag: model)
            }
        }
        .header {
            Header {
                SectionHeaderLabel(title: "MOODS")
            }
        }
        .onSelect { (tag: Tag) in
            print("Selected mood tag: \(tag.name)")
        }
    }
}

// MARK: - Tag Chip Cell

private struct TagChipCell: ViewBuilder {
    let tag: Tag
    
    var body: View {
        HStackView(spacing: 6) {
            ContainerView()
                .backgroundColor(tag.color)
                .cornerRadius(4)
                .size(width: 8, height: 8)
            
            LabelView(tag.name)
                .font(.systemFont(ofSize: 14, weight: .medium))
                .color(.white)
        }
        .padding(h: 14, v: 10)
        .backgroundColor(tag.color.withAlphaComponent(0.15))
        .cornerRadius(20)
        .border(color: tag.color.withAlphaComponent(0.3), lineWidth: 1)
    }
}

// MARK: - Section Header

private struct SectionHeaderLabel: ViewBuilder {
    let title: String
    
    var body: View {
        LabelView(title)
            .color(UIColor("#737373"))
            .font(.systemFont(ofSize: 12, weight: .semibold))
    }
}


//
//  AlignedCollectionViewFlowLayout.swift
//
//  Created by Mischa Hildebrand on 12/04/2017.
//  Copyright © 2017 Mischa Hildebrand.
//
//  Licensed under the terms of the MIT license:
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


// MARK: - 🦆 Type definitions

/// An abstract protocol that defines an alignment.
protocol Alignment {}

/// Defines a horizontal alignment for UI elements.
public enum HorizontalAlignment: Alignment {
    case left
    case right
    case leading
    case trailing
    case justified
}

/// Defines a vertical alignment for UI elements.
public enum VerticalAlignment: Alignment {
    case top
    case center
    case bottom
}

/// A horizontal alignment used internally by `AlignedCollectionViewFlowLayout`
/// to layout the items, after resolving layout direction specifics.
private enum EffectiveHorizontalAlignment: Alignment {
    case left
    case right
    case justified
}

/// Describes an axis with respect to which items can be aligned.
private struct AlignmentAxis<A: Alignment> {
    
    /// Determines how items are aligned relative to the axis.
    let alignment: A
    
    /// Defines the position of the axis.
    /// * If the `Alignment` is horizontal, the alignment axis is vertical and this is the position on the `x` axis.
    /// * If the `Alignment` is vertical, the alignment axis is horizontal and this is the position on the `y` axis.
    let position: CGFloat
}



// MARK: - Flow Layout

/// A `UICollectionViewFlowLayout` subclass that gives you control
/// over the horizontal and vertical alignment of the cells.
/// You can use it to align the cells like words in a left- or right-aligned text
/// and you can specify how the cells are vertically aligned in their row.
open class AlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    // MARK: - 🔶 Properties
    
    /// Determines how the cells are horizontally aligned in a row.
    /// - Note: The default is `.justified`.
    public var horizontalAlignment: HorizontalAlignment = .justified

    /// Determines how the cells are vertically aligned in a row.
    /// - Note: The default is `.center`.
    public var verticalAlignment: VerticalAlignment = .center

    /// The `horizontalAlignment` with its layout direction specifics resolved,
    /// i.e. `.leading` and `.trailing` alignments are mapped to `.left` or `right`,
    /// depending on the current layout direction.
    fileprivate var effectiveHorizontalAlignment: EffectiveHorizontalAlignment {

        var trivialMapping: [HorizontalAlignment: EffectiveHorizontalAlignment] {
            return [
                .left: .left,
                .right: .right,
                .justified: .justified
            ]
        }

        let layoutDirection = UIApplication.shared.userInterfaceLayoutDirection

        switch layoutDirection {
        case .leftToRight:
            switch horizontalAlignment {
            case .leading:
                return .left
            case .trailing:
                return .right
            default:
                break
            }

        case .rightToLeft:
            switch horizontalAlignment {
            case .leading:
                return .right
            case .trailing:
                return .left
            default:
                break
            }
        @unknown default:
            fatalError("Unknown orientation")
        }

        // It's safe to force-unwrap as `.leading` and `.trailing` are covered
        // above and the `trivialMapping` dictionary contains all other keys.
        return trivialMapping[horizontalAlignment]!
    }
    
    /// The vertical axis with respect to which the cells are horizontally aligned.
    /// For a `justified` alignment the alignment axis is not defined and this value is `nil`.
    fileprivate var alignmentAxis: AlignmentAxis<HorizontalAlignment>? {
        switch effectiveHorizontalAlignment {
        case .left:
            return AlignmentAxis(alignment: HorizontalAlignment.left, position: sectionInset.left)
        case .right:
            guard let collectionViewWidth = collectionView?.frame.size.width else {
                return nil
            }
            return AlignmentAxis(alignment: HorizontalAlignment.right, position: collectionViewWidth - sectionInset.right)
        default:
            return nil
        }
    }
    
    /// The width of the area inside the collection view that can be filled with cells.
    private var contentWidth: CGFloat? {
        guard let collectionViewWidth = collectionView?.frame.size.width else {
            return nil
        }
        return collectionViewWidth - sectionInset.left - sectionInset.right
    }
    
    
    // MARK: - 👶 Initialization
    
    /// The designated initializer.
    ///
    /// - Parameters:
    ///   - horizontalAlignment: Specifies how the cells are horizontally aligned in a row. --
    ///                          (Default: `.justified`)
    ///   - verticalAlignment:   Specified how the cells are vertically aligned in a row. --
    ///                          (Default: `.center`)
    public init(horizontalAlignment: HorizontalAlignment = .justified, verticalAlignment: VerticalAlignment = .center) {
        super.init()
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    // MARK: - 🅾️ Overrides
    
    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        
        // 💡 IDEA:
        // The approach for computing a cell's frame is to create a rectangle that covers the current line.
        // Then we check if the preceding cell's frame intersects with this rectangle.
        // If it does, the current item is not the first item in the line. Otherwise it is.
        // (Vice-versa for right-aligned cells.)
        //
        // +---------+----------------------------------------------------------------+---------+
        // |         |                                                                |         |
        // |         |     +------------+                                             |         |
        // |         |     |            |                                             |         |
        // | section |- - -|- - - - - - |- - - - +---------------------+ - - - - - - -| section |
        // |  inset  |     |intersection|        |                     |   line rect  |  inset  |
        // |         |- - -|- - - - - - |- - - - +---------------------+ - - - - - - -|         |
        // | (left)  |     |            |             current item                    | (right) |
        // |         |     +------------+                                             |         |
        // |         |     previous item                                              |         |
        // +---------+----------------------------------------------------------------+---------+
        //
        // ℹ️ We need this rather complicated approach because the first item in a line
        //    is not always left-aligned and the last item in a line is not always right-aligned:
        //    If there is only one item in a line UICollectionViewFlowLayout will center it.
        
        // We may not change the original layout attributes or UICollectionViewFlowLayout might complain.
        guard let layoutAttributes = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        
        // For a justified layout there's nothing to do here
        // as UICollectionViewFlowLayout justifies the items in a line by default.
        if horizontalAlignment != .justified {
            layoutAttributes.alignHorizontally(collectionViewLayout: self)
        }
        
        // For a vertically centered layout there's nothing to do here
        // as UICollectionViewFlowLayout center-aligns the items in a line by default.
        if verticalAlignment != .center {
            layoutAttributes.alignVertically(collectionViewLayout: self)
        }
        
        return layoutAttributes
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // We may not change the original layout attributes or UICollectionViewFlowLayout might complain.
        let layoutAttributesObjects = copy(super.layoutAttributesForElements(in: rect))
        layoutAttributesObjects?.forEach({ (layoutAttributes) in
            setFrame(forLayoutAttributes: layoutAttributes)
        })
        return layoutAttributesObjects
    }
    
    
    // MARK: - 👷 Private layout helpers
    
    /// Sets the frame for the passed layout attributes object by calling the `layoutAttributesForItem(at:)` function.
    private func setFrame(forLayoutAttributes layoutAttributes: UICollectionViewLayoutAttributes) {
        if layoutAttributes.representedElementCategory == .cell { // Do not modify header views etc.
            let indexPath = layoutAttributes.indexPath
            if let newFrame = layoutAttributesForItem(at: indexPath)?.frame {
                layoutAttributes.frame = newFrame
            }
        }
    }
    
    /// A function to access the `super` implementation of `layoutAttributesForItem(at:)` externally.
    ///
    /// - Parameter indexPath: The index path of the item for which to return the layout attributes.
    /// - Returns: The unmodified layout attributes for the item at the specified index path
    ///            as computed by `UICollectionViewFlowLayout`.
    fileprivate func originalLayoutAttribute(forItemAt indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return super.layoutAttributesForItem(at: indexPath)
    }
    
    /// Determines if the `firstItemAttributes`' frame is in the same line
    /// as the `secondItemAttributes`' frame.
    ///
    /// - Parameters:
    ///   - firstItemAttributes:  The first layout attributes object to be compared.
    ///   - secondItemAttributes: The second layout attributes object to be compared.
    /// - Returns: `true` if the frames of the two layout attributes are in the same line, else `false`.
    ///            `false` is also returned when the layout's `collectionView` property is `nil`.
    fileprivate func isFrame(for firstItemAttributes: UICollectionViewLayoutAttributes, inSameLineAsFrameFor secondItemAttributes: UICollectionViewLayoutAttributes) -> Bool {
        guard let lineWidth = contentWidth else {
            return false
        }
        let firstItemFrame = firstItemAttributes.frame
        let lineFrame = CGRect(x: sectionInset.left,
                               y: firstItemFrame.origin.y,
                               width: lineWidth,
                               height: firstItemFrame.size.height)
        return lineFrame.intersects(secondItemAttributes.frame)
    }
    
    /// Determines the layout attributes objects for all items displayed in the same line as the item
    /// represented by the passed `layoutAttributes` object.
    ///
    /// - Parameter layoutAttributes: The layout attributed that represents the reference item.
    /// - Returns: The layout attributes objects representing all other items in the same line.
    ///            The passed `layoutAttributes` object itself is always contained in the returned array.
    fileprivate func layoutAttributes(forItemsInLineWith layoutAttributes: UICollectionViewLayoutAttributes) -> [UICollectionViewLayoutAttributes] {
        guard let lineWidth = contentWidth else {
            return [layoutAttributes]
        }
        var lineFrame = layoutAttributes.frame
        lineFrame.origin.x = sectionInset.left
        lineFrame.size.width = lineWidth
        return super.layoutAttributesForElements(in: lineFrame) ?? []
    }
    
    /// Copmutes the alignment axis with which to align the items represented by the `layoutAttributes` objects vertically.
    ///
    /// - Parameter layoutAttributes: The layout attributes objects to be vertically aligned.
    /// - Returns: The axis with respect to which the layout attributes can be aligned
    ///            or `nil` if the `layoutAttributes` array is empty.
    private func verticalAlignmentAxisForLine(with layoutAttributes: [UICollectionViewLayoutAttributes]) -> AlignmentAxis<VerticalAlignment>? {
        
        guard let firstAttribute = layoutAttributes.first else {
            return nil
        }
        
        switch verticalAlignment {
        case .top:
            let minY = layoutAttributes.reduce(CGFloat.greatestFiniteMagnitude) { min($0, $1.frame.minY) }
            return AlignmentAxis(alignment: .top, position: minY)
            
        case .bottom:
            let maxY = layoutAttributes.reduce(0) { max($0, $1.frame.maxY) }
            return AlignmentAxis(alignment: .bottom, position: maxY)
            
        default:
            let centerY = firstAttribute.center.y
            return AlignmentAxis(alignment: .center, position: centerY)
        }
    }
    
    /// Computes the axis with which to align the item represented by the `currentLayoutAttributes` vertically.
    ///
    /// - Parameter currentLayoutAttributes: The layout attributes representing the item to be vertically aligned.
    /// - Returns: The axis with respect to which the item can be aligned.
    fileprivate func verticalAlignmentAxis(for currentLayoutAttributes: UICollectionViewLayoutAttributes) -> AlignmentAxis<VerticalAlignment> {
        let layoutAttributesInLine = layoutAttributes(forItemsInLineWith: currentLayoutAttributes)
        // It's okay to force-unwrap here because we pass a non-empty array.
        return verticalAlignmentAxisForLine(with: layoutAttributesInLine)!
    }
    
    /// Creates a deep copy of the passed array by copying all its items.
    ///
    /// - Parameter layoutAttributesArray: The array to be copied.
    /// - Returns: A deep copy of the passed array.
    private func copy(_ layoutAttributesArray: [UICollectionViewLayoutAttributes]?) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributesArray?.map{ $0.copy() } as? [UICollectionViewLayoutAttributes]
    }
    
    
    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}



// MARK: - 👷 Layout attributes helpers

fileprivate extension UICollectionViewLayoutAttributes {
    
    private var currentSection: Int {
        return indexPath.section
    }
    
    private var currentItem: Int {
        return indexPath.item
    }
    
    /// The index path for the item preceding the item represented by this layout attributes object.
    private var precedingIndexPath: IndexPath {
        return IndexPath(item: currentItem - 1, section: currentSection)
    }
    
    /// The index path for the item following the item represented by this layout attributes object.
    private var followingIndexPath: IndexPath {
        return IndexPath(item: currentItem + 1, section: currentSection)
    }
    
    /// Checks if the item represetend by this layout attributes object is the first item in the line.
    ///
    /// - Parameter collectionViewLayout: The layout for which to perform the check.
    /// - Returns: `true` if the represented item is the first item in the line, else `false`.
    func isRepresentingFirstItemInLine(collectionViewLayout: AlignedCollectionViewFlowLayout) -> Bool {
        if currentItem <= 0 {
            return true
        }
        else {
            if let layoutAttributesForPrecedingItem = collectionViewLayout.originalLayoutAttribute(forItemAt: precedingIndexPath) {
                return !collectionViewLayout.isFrame(for: self, inSameLineAsFrameFor: layoutAttributesForPrecedingItem)
            }
            else {
                return true
            }
        }
    }
    
    /// Checks if the item represetend by this layout attributes object is the last item in the line.
    ///
    /// - Parameter collectionViewLayout: The layout for which to perform the check.
    /// - Returns: `true` if the represented item is the last item in the line, else `false`.
    func isRepresentingLastItemInLine(collectionViewLayout: AlignedCollectionViewFlowLayout) -> Bool {
        guard let itemCount = collectionViewLayout.collectionView?.numberOfItems(inSection: currentSection) else {
            return false
        }
        
        if currentItem >= itemCount - 1 {
            return true
        }
        else {
            if let layoutAttributesForFollowingItem = collectionViewLayout.originalLayoutAttribute(forItemAt: followingIndexPath) {
                return !collectionViewLayout.isFrame(for: self, inSameLineAsFrameFor: layoutAttributesForFollowingItem)
            }
            else {
                return true
            }
        }
    }
    
    /// Moves the layout attributes object's frame so that it is aligned horizontally with the alignment axis.
    func align(toAlignmentAxis alignmentAxis: AlignmentAxis<HorizontalAlignment>) {
        switch alignmentAxis.alignment {
        case .left:
            frame.origin.x = alignmentAxis.position
        case .right:
            frame.origin.x = alignmentAxis.position - frame.size.width
        default:
            break
        }
    }
    
    /// Moves the layout attributes object's frame so that it is aligned vertically with the alignment axis.
    func align(toAlignmentAxis alignmentAxis: AlignmentAxis<VerticalAlignment>) {
        switch alignmentAxis.alignment {
        case .top:
            frame.origin.y = alignmentAxis.position
        case .bottom:
            frame.origin.y = alignmentAxis.position - frame.size.height
        default:
            center.y = alignmentAxis.position
        }
    }
    
    /// Positions the frame right of the preceding item's frame, leaving a spacing between the frames
    /// as defined by the collection view layout's `minimumInteritemSpacing`.
    ///
    /// - Parameter collectionViewLayout: The layout on which to perfom the calculations.
    private func alignToPrecedingItem(collectionViewLayout: AlignedCollectionViewFlowLayout) {
        let itemSpacing = collectionViewLayout.minimumInteritemSpacing
        
        if let precedingItemAttributes = collectionViewLayout.layoutAttributesForItem(at: precedingIndexPath) {
            frame.origin.x = precedingItemAttributes.frame.maxX + itemSpacing
        }
    }
    
    /// Positions the frame left of the following item's frame, leaving a spacing between the frames
    /// as defined by the collection view layout's `minimumInteritemSpacing`.
    ///
    /// - Parameter collectionViewLayout: The layout on which to perfom the calculations.
    private func alignToFollowingItem(collectionViewLayout: AlignedCollectionViewFlowLayout) {
        let itemSpacing = collectionViewLayout.minimumInteritemSpacing
        
        if let followingItemAttributes = collectionViewLayout.layoutAttributesForItem(at: followingIndexPath) {
            frame.origin.x = followingItemAttributes.frame.minX - itemSpacing - frame.size.width
        }
    }
    
    /// Aligns the frame horizontally as specified by the collection view layout's `horizontalAlignment`.
    ///
    /// - Parameters:
    ///   - collectionViewLayout: The layout providing the alignment information.
    func alignHorizontally(collectionViewLayout: AlignedCollectionViewFlowLayout) {
        
        guard let alignmentAxis = collectionViewLayout.alignmentAxis else {
            return
        }
        
        switch collectionViewLayout.effectiveHorizontalAlignment {
            
        case .left:
            if isRepresentingFirstItemInLine(collectionViewLayout: collectionViewLayout) {
                align(toAlignmentAxis: alignmentAxis)
            } else {
                alignToPrecedingItem(collectionViewLayout: collectionViewLayout)
            }
            
        case .right:
            if isRepresentingLastItemInLine(collectionViewLayout: collectionViewLayout) {
                align(toAlignmentAxis: alignmentAxis)
            } else {
                alignToFollowingItem(collectionViewLayout: collectionViewLayout)
            }
            
        default:
            return
        }
    }
    
    /// Aligns the frame vertically as specified by the collection view layout's `verticalAlignment`.
    ///
    /// - Parameter collectionViewLayout: The layout providing the alignment information.
    func alignVertically(collectionViewLayout: AlignedCollectionViewFlowLayout) {
        let alignmentAxis = collectionViewLayout.verticalAlignmentAxis(for: self)
        align(toAlignmentAxis: alignmentAxis)
    }
    
}
