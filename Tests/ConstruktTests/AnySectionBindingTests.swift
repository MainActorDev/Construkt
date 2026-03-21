import Testing
@testable import ConstruktKit

@Suite("AnySection Bindings")
struct AnySectionBindingTests {

    @Test("when binding toggles section visibility")
    func whenBindingTogglesSection() {
        let bag = CancelBag()
        let isVisible = Property(false)
        var emissions: [[SectionConfig]] = []

        AnySection(id: TestSection.login, when: isVisible) {
            AnyCell("login", id: "login") { _ in
                ContainerView()
            }
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].isEmpty)

        isVisible.wrappedValue = true
        #expect(emissions.count == 2)
        #expect(emissions[1].count == 1)
        #expect(emissions[1][0].identifier.uniqueId == TestSection.login.uniqueId)
        #expect(emissions[1][0].cells.count == 1)

        isVisible.wrappedValue = false
        #expect(emissions.count == 3)
        #expect(emissions[2].isEmpty)
    }

    @Test("item binding maps single model without array boilerplate")
    func itemBindingRendersSingleModel() {
        let bag = CancelBag()
        let profile = Property(Profile(id: 1, name: "John"))
        var emissions: [[SectionConfig]] = []

        AnySection(id: TestSection.profile, item: profile) { item in
            AnyCell(item, id: item.id) { _ in
                ContainerView()
            }
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].count == 1)
        #expect(emissions[0][0].cells.count == 1)
        #expect(emissions[0][0].cells[0].id == AnyHashable(1))

        profile.wrappedValue = Profile(id: 2, name: "Jane")
        #expect(emissions.count == 2)
        #expect(emissions[1][0].cells[0].id == AnyHashable(2))
    }

    @Test("optional item binding hides section when nil")
    func optionalItemBindingHidesSectionWhenNil() {
        let bag = CancelBag()
        let promo = Property<Promo?>(nil)
        var emissions: [[SectionConfig]] = []

        AnySection(id: TestSection.promo, item: promo) { item in
            AnyCell(item, id: item.id) { _ in
                ContainerView()
            }
        }
        .asAnySectionObservable()
        .observe(on: nil) { sections in
            emissions.append(sections)
        }
        .store(in: bag)

        #expect(emissions.count == 1)
        #expect(emissions[0].isEmpty)

        promo.wrappedValue = Promo(id: "promo-1")
        #expect(emissions.count == 2)
        #expect(emissions[1].count == 1)
        #expect(emissions[1][0].cells.count == 1)

        promo.wrappedValue = nil
        #expect(emissions.count == 3)
        #expect(emissions[2].isEmpty)
    }
}

private enum TestSection: SectionConfigIdentifier {
    case login
    case profile
    case promo

    var uniqueId: String { "test-\(self)" }
}

private struct Profile: Hashable {
    let id: Int
    let name: String
}

private struct Promo: Hashable {
    let id: String
}
