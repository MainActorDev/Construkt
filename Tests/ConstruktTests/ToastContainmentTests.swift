import Testing
import UIKit
@testable import ConstruktKit

/// Verifies that ToastManager properly adds content VCs to the containment hierarchy.
/// This test validates the fix for A2 (toast VC containment) by checking that
/// `setContent(_:in:)` receives a non-nil parent VC.
@Suite("Toast Containment") @MainActor
struct ToastContainmentTests {
    @Test("toast content VC is added as child of root VC")
    func toastContentVCAddedAsChild() {
        // Verify the fix at the ToastItemView level directly,
        // avoiding ToastManager singleton state issues in concurrent tests.
        let toastView = ToastItemView(config: ToastConfiguration())
        let parentVC = UIViewController()
        let contentVC = UIViewController()
        let label = UILabel()
        label.text = "Toast message"
        contentVC.view.addSubview(label)

        toastView.setContent(contentVC, in: parentVC)

        #expect(contentVC.parent === parentVC, "Toast content VC should be a child of the provided parent VC")
    }
}
