import Testing
@testable import ConstruktKit

@Suite("AnySection Supplementary Visibility")
@MainActor
struct AnySectionSupplementaryVisibilityTests {

    @Test("headerHidden updates only when visibility changes")
    func headerHiddenUpdatesOnlyOnVisibilityChanges() {
        let bag = CancelBag()
        let hidden = Property(false)
        var emissions: [[SectionConfig]] = []

        AnySection(
            id: VisibilitySection.header
        ) {
            Header(id: "header-id") {
                ContainerView()
            }
            AnyCell("A", id: "A") { _ in
                ContainerView()
            }
        }
        .headerHidden(when: hidden)
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].count == 1)
        #expect(emissions[0][0].header?.id as? String == "header-id")

        hidden.wrappedValue = false
        #expect(emissions.count == 1)

        hidden.wrappedValue = true
        #expect(emissions.count == 2)
        #expect(emissions[1][0].header == nil)

        hidden.wrappedValue = true
        #expect(emissions.count == 2)

        hidden.wrappedValue = false
        #expect(emissions.count == 3)
        #expect(emissions[2][0].header?.id as? String == "header-id")
    }

    @Test("footerHidden updates only when visibility changes")
    func footerHiddenUpdatesOnlyOnVisibilityChanges() {
        let bag = CancelBag()
        let hidden = Property(false)
        var emissions: [[SectionConfig]] = []

        AnySection(
            id: VisibilitySection.footer
        ) {
            Footer(id: "footer-id") {
                ContainerView()
            }
            AnyCell("A", id: "A") { _ in
                ContainerView()
            }
        }
        .footerHidden(when: hidden)
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].count == 1)
        #expect(emissions[0][0].footer?.id as? String == "footer-id")

        hidden.wrappedValue = false
        #expect(emissions.count == 1)

        hidden.wrappedValue = true
        #expect(emissions.count == 2)
        #expect(emissions[1][0].footer == nil)

        hidden.wrappedValue = true
        #expect(emissions.count == 2)

        hidden.wrappedValue = false
        #expect(emissions.count == 3)
        #expect(emissions[2][0].footer?.id as? String == "footer-id")
    }
}

private enum VisibilitySection: SectionConfigIdentifier {
    case header
    case footer

    var uniqueId: String { "supplementary-\(self)" }
}
