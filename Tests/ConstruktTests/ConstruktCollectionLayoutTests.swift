import Testing
@testable import ConstruktKit
import UIKit

@Suite("ConstruktCollectionLayout Protocol")
@MainActor
struct ConstruktCollectionLayoutTests {

    @Test("protocol provides section metadata to layout")
    func protocolProvidesSectionMetadata() {
        let layout = MockConstruktLayout()
        let metadata = CollectionLayoutMetadata(
            sections: [
                CollectionLayoutMetadata.Section(
                    identifier: "section-0",
                    itemCount: 3
                ),
                CollectionLayoutMetadata.Section(
                    identifier: "section-1",
                    itemCount: 5
                )
            ]
        )

        layout.updateMetadata(metadata)

        #expect(layout.lastMetadata?.sections.count == 2)
        #expect(layout.lastMetadata?.sections[0].identifier == "section-0")
        #expect(layout.lastMetadata?.sections[0].itemCount == 3)
        #expect(layout.lastMetadata?.sections[1].identifier == "section-1")
        #expect(layout.lastMetadata?.sections[1].itemCount == 5)
    }
}

private final class MockConstruktLayout: UICollectionViewLayout, ConstruktCollectionLayout {
    var lastMetadata: CollectionLayoutMetadata?

    func updateMetadata(_ metadata: CollectionLayoutMetadata) {
        lastMetadata = metadata
        invalidateLayout()
    }
}
