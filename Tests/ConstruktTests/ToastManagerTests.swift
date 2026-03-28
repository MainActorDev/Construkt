import Testing
import UIKit
@testable import ConstruktKit

@Suite("ToastManagerTests") @MainActor
struct ToastManagerTests {
    @Test("message validation rejects nil, empty, and whitespace")
    func messageValidationRejectsInvalidMessages() {
        #expect(ToastManager.isDisplayableMessage(nil) == false)
        #expect(ToastManager.isDisplayableMessage("") == false)
        #expect(ToastManager.isDisplayableMessage("   \n\t") == false)
    }

    @Test("message validation accepts non-empty text")
    func messageValidationAcceptsNonEmptyText() {
        #expect(ToastManager.isDisplayableMessage("hello") == true)
        #expect(ToastManager.isDisplayableMessage("  hello  ") == true)
    }

    @Test("queue behavior defaults to replaced")
    func queueBehaviorDefaultsToReplaced() {
        #expect(ToastManager.shared.queueBehavior == .replaced)
    }

    @Test("content displayability rejects views with only empty text")
    func contentDisplayabilityRejectsEmptyTextOnlyViews() {
        let vc = UIViewController()
        let label = UILabel()
        label.text = "   \n"
        vc.view.addSubview(label)

        #expect(ToastManager.hasDisplayableText(in: vc.view) == false)
    }

    @Test("content displayability accepts non-empty text")
    func contentDisplayabilityAcceptsNonEmptyText() {
        let vc = UIViewController()
        let label = UILabel()
        label.text = "Hello"
        vc.view.addSubview(label)

        #expect(ToastManager.hasDisplayableText(in: vc.view) == true)
    }

    @Test("edge stacking order places newest first")
    func edgeStackingOrderPlacesNewestFirst() {
        #expect(ToastManager.edgeStackOrder([1, 2, 3]) == [3, 2, 1])
    }
}
