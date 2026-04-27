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
