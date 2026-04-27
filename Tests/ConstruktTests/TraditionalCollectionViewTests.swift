import Testing
import UIKit
@testable import ConstruktKit

@MainActor
@Suite("TraditionalCollectionView")
struct TraditionalCollectionViewTests {

    @Test("initializes with provided layout")
    func initializesWithProvidedLayout() {
        let flowLayout = UICollectionViewFlowLayout()

        let cv = TraditionalCollectionView(layout: flowLayout) {
            AnySection(id: TestSection.tags) {
                AnyCell("tag1", id: "tag1") { _ in ContainerView() }
            }
        }

        let wrapper = cv.modifiableView
        #expect(wrapper.collectionView.collectionViewLayout === flowLayout)
    }
}

private enum TestSection: SectionConfigIdentifier {
    case tags
    case items

    var uniqueId: String { "test-\(self)" }
}
