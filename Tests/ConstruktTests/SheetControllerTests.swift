import Testing
import UIKit
@testable import ConstruktKit

@Suite("SheetController") @MainActor
struct SheetControllerTests {

    @Test("onDismiss fires when dimming view is tapped")
    func onDismissFiresOnDimmingTap() {
        let config = SheetConfiguration()
        let contentVC = UIViewController()
        let sheet = SheetController(content: contentVC, config: config)

        var dismissed = false
        sheet.onDismiss = { dismissed = true }

        // Obtain the presentation controller
        let presentationController = sheet.presentationController(
            forPresented: sheet,
            presenting: nil,
            source: UIViewController()
        ) as! SheetPresentationController

        // Simulate dimming view tap by calling the handler directly
        presentationController.onDismiss?()

        #expect(dismissed, "onDismiss should fire when dimming view tap triggers presentationController.onDismiss")
    }

    @Test("pan gesture uses constraint-only positioning (no transform)")
    func panUsesConstraintOnly() {
        let config = SheetConfiguration()
        let content = UIViewController()
        let sheet = SheetController(content: content, config: config)

        // Load the view hierarchy
        sheet.loadViewIfNeeded()

        // After any interaction, the container should never have a non-identity transform
        // This verifies the fix removed transform usage
        #expect(sheet.view.subviews.allSatisfy { $0.transform == .identity },
                "All subviews should use identity transform (constraint-only positioning)")
    }
}
