import Testing
@testable import ConstruktKit
import UIKit

@Suite("CollectionView Custom Layout")
@MainActor
struct CustomLayoutCollectionViewTests {

    @Test("customLayout sets the provided layout on the collection view")
    func customLayoutSetsLayout() {
        let customLayout = UICollectionViewFlowLayout()
        customLayout.scrollDirection = .horizontal

        let cv = CollectionView {
            AnySection(id: CustomLayoutTestSection.main) {
                AnyCell("item", id: "item1") { _ in ContainerView() }
            }
            .layout {
                CollectionLayoutSectionBuilder.list(itemHeight: .estimated(44))
            }
        }
        .customLayout(customLayout)

        let wrapper = cv.modifiableView
        #expect(wrapper.collectionView.collectionViewLayout === customLayout)
    }

    @Test("customLayout prevents compositional layout creation")
    func customLayoutPreventsCompositionalLayout() {
        let flowLayout = UICollectionViewFlowLayout()

        let cv = CollectionView {
            AnySection(id: CustomLayoutTestSection.main) {
                AnyCell("item", id: "item1") { _ in ContainerView() }
            }
        }
        .customLayout(flowLayout)

        let wrapper = cv.modifiableView
        // The layout should be the flow layout, not a UICollectionViewCompositionalLayout
        #expect(wrapper.collectionView.collectionViewLayout is UICollectionViewFlowLayout)
        #expect(!(wrapper.collectionView.collectionViewLayout is UICollectionViewCompositionalLayout))
    }
}

private enum CustomLayoutTestSection: SectionConfigIdentifier {
    case main
    var uniqueId: String { "custom-layout-\(self)" }
}
