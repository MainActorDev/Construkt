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

    @Test("flow layout returns header size when header exists")
    func flowLayoutHeaderSizing() {
        let flowLayout = UICollectionViewFlowLayout()

        let cv = TraditionalCollectionView(layout: flowLayout) {
            AnySection(id: TestSection.tags) {
                AnyCell("tag1", id: "tag1") { _ in ContainerView() }
            }
            .header {
                Header {
                    ContainerView()
                }
            }
        }

        let wrapper = cv.modifiableView

        // Trigger update so currentSectionMap is populated
        let bag = CancelBag()
        var sections: [SectionConfig] = []
        AnySection(id: TestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
        .header {
            Header {
                ContainerView()
            }
        }
        .asAnySectionObservable()
        .observe(on: nil) { s in sections = s }
        .store(in: bag)

        wrapper.update(sections: sections)

        // Flow layout delegate should return non-zero header size
        let size = wrapper.collectionView(
            wrapper.collectionView,
            layout: flowLayout,
            referenceSizeForHeaderInSection: 0
        )
        #expect(size.height > 0)
    }

    @Test("flow layout returns zero header size when no header")
    func flowLayoutNoHeaderSizing() {
        let flowLayout = UICollectionViewFlowLayout()

        let cv = TraditionalCollectionView(layout: flowLayout) {
            AnySection(id: TestSection.tags) {
                AnyCell("tag1", id: "tag1") { _ in ContainerView() }
            }
        }

        let wrapper = cv.modifiableView

        let bag = CancelBag()
        var sections: [SectionConfig] = []
        AnySection(id: TestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
        .asAnySectionObservable()
        .observe(on: nil) { s in sections = s }
        .store(in: bag)

        wrapper.update(sections: sections)

        let size = wrapper.collectionView(
            wrapper.collectionView,
            layout: flowLayout,
            referenceSizeForHeaderInSection: 0
        )
        #expect(size == .zero)
    }
}

private enum TestSection: SectionConfigIdentifier {
    case tags
    case items

    var uniqueId: String { "test-\(self)" }
}
