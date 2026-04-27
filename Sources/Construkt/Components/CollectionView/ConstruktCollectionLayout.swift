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
