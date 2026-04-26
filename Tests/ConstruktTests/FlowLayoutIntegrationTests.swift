import Testing
@testable import ConstruktKit
import UIKit

@Suite("Flow Layout Integration")
@MainActor
struct FlowLayoutIntegrationTests {

    @Test("flow layout sets layoutProvider on SectionConfig")
    func flowLayoutSetsProvider() {
        let bag = CancelBag()
        var emissions: [[SectionConfig]] = []

        let sizes = [
            CGSize(width: 60, height: 30),
            CGSize(width: 80, height: 30),
            CGSize(width: 100, height: 30)
        ]

        AnySection(id: FlowTestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
            AnyCell("tag2", id: "tag2") { _ in ContainerView() }
            AnyCell("tag3", id: "tag3") { _ in ContainerView() }
        }
        .layout {
            CollectionLayoutSectionBuilder.flow(
                itemSizes: sizes,
                horizontalSpacing: 8,
                lineSpacing: 8
            )
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].count == 1)

        let section = emissions[0][0]
        #expect(section.layoutProvider != nil)

        // Verify the layout provider returns a valid NSCollectionLayoutSection
        let layoutSection = section.layoutProvider?(section.identifier.uniqueId)
        #expect(layoutSection != nil)
    }

    @Test("flow layout composes with other section modifiers")
    func flowLayoutComposesWithModifiers() {
        let bag = CancelBag()
        var emissions: [[SectionConfig]] = []

        let sizes = [CGSize(width: 60, height: 30)]

        AnySection(id: FlowTestSection.tags) {
            AnyCell("tag1", id: "tag1") { _ in ContainerView() }
        }
        .layout {
            CollectionLayoutSectionBuilder.flow(itemSizes: sizes)
                .insets(top: 16, leading: 16, bottom: 16, trailing: 16)
                .supplementaryHeader(height: .estimated(44))
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        let section = emissions[0][0]
        let layoutSection = section.layoutProvider?(section.identifier.uniqueId)
        #expect(layoutSection != nil)
        #expect(layoutSection!.contentInsets.top == 16)
        #expect(layoutSection!.boundarySupplementaryItems.count == 1)
    }
}

private enum FlowTestSection: SectionConfigIdentifier {
    case tags
    var uniqueId: String { "flow-test-\(self)" }
}
