import Testing
import UIKit
@testable import ConstruktKit

@Suite("Toast Containment") @MainActor
struct ToastContainmentTests {
    @Test("toast content VC is added as child of root VC")
    func toastContentVCAddedAsChild() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        let rootVC = UIViewController()
        window.rootViewController = rootVC
        window.makeKeyAndVisible()

        let contentVC = UIViewController()
        let label = UILabel()
        label.text = "Toast message"
        contentVC.view.addSubview(label)

        let config = ToastConfiguration()
        ToastManager.shared.show(content: contentVC, config: config, in: window)

        #expect(contentVC.parent === rootVC, "Toast content VC should be a child of the window's root VC")

        // Cleanup
        ToastManager.shared.dismissAll(animated: false)
    }
}
