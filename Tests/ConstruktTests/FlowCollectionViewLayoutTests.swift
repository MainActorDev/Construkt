import Testing
@testable import ConstruktKit
import UIKit

@Suite("FlowCollectionViewLayout")
@MainActor
struct FlowCollectionViewLayoutTests {

    @Test("layout conforms to ConstruktCollectionLayout")
    func conformsToProtocol() {
        let layout = FlowCollectionViewLayout()
        #expect(layout is ConstruktCollectionLayout)
    }

    @Test("layout accepts item size provider")
    func acceptsItemSizeProvider() {
        let layout = FlowCollectionViewLayout { _, _ in
            CGSize(width: 60, height: 30)
        }
        #expect(layout.horizontalSpacing == 8) // default
        #expect(layout.lineSpacing == 8) // default
    }

    @Test("layout properties are configurable")
    func configurableProperties() {
        let layout = FlowCollectionViewLayout { _, _ in
            CGSize(width: 60, height: 30)
        }
        layout.horizontalSpacing = 12
        layout.lineSpacing = 16
        layout.sectionInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        #expect(layout.horizontalSpacing == 12)
        #expect(layout.lineSpacing == 16)
        #expect(layout.sectionInsets.top == 8)
    }
}
