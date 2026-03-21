import Testing
import UIKit
@testable import ConstruktKit

@Suite("LifecycleHostControllerTests") @MainActor
struct LifecycleHostControllerTests {

    private final class LeakProbe {}

    private final class LifecycleOwner {
        var didLoad = false
    }

    @Test("onHostDidLoad should be called when host loads view")
    func testOnHostDidLoadIsCalled() {
        var didLoad = false
        
        let view = VStackView { LabelView("Test") }
        .onHostDidLoad {
            didLoad = true
        }
        
        let vc = view.toPresentable() as! LifecycleHostController
        
        // Trigger view load
        _ = vc.view
        
        #expect(didLoad)
    }

    @Test("onHostWillAppear should be called")
    func testOnHostWillAppearIsCalled() {
        var didAppear = false
        
        let view = VStackView { LabelView("Test") }
        .onHostWillAppear { animated in
            didAppear = true
            #expect(animated)
        }
        
        let vc = view.toPresentable() as! LifecycleHostController
        
        // Trigger view load
        _ = vc.view
        vc.viewWillAppear(true)
        
        #expect(didAppear)
    }

    @Test("onHostDidLoad captured objects should be released after load")
    func testOnHostDidLoadReleasesCapturedObjectsAfterLoad() {
        weak var weakProbe: LeakProbe?

        let vc: LifecycleHostController = {
            let probe = LeakProbe()
            weakProbe = probe

            let view = VStackView { LabelView("Test") }
                .onHostDidLoad {
                    _ = probe
                }

            return view.toPresentable() as! LifecycleHostController
        }()

        #expect(weakProbe != nil)

        _ = vc.view

        #expect(weakProbe == nil)
    }

    @Test("lifecycle callbacks should be released when host detaches")
    func testLifecycleCallbacksReleasedOnDetach() {
        weak var weakProbe: LeakProbe?

        let host: LifecycleHostController = {
            let probe = LeakProbe()
            weakProbe = probe

            let view = VStackView { LabelView("Test") }
                .onHostWillAppear { _ in
                    _ = probe
                }

            return view.toPresentable() as! LifecycleHostController
        }()

        #expect(weakProbe != nil)

        let parent = UIViewController()
        _ = parent.view

        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)

        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()

        #expect(weakProbe == nil)
    }

    @Test("weak-target onHostDidLoad should not retain target")
    func testWeakTargetOnHostDidLoadDoesNotRetainTarget() {
        var owner: LifecycleOwner? = LifecycleOwner()
        weak var weakOwner = owner

        let vc = VStackView { LabelView("Test") }
            .onHostDidLoad(on: owner!) { owner in
                owner.didLoad = true
            }
            .toPresentable() as! LifecycleHostController

        owner = nil

        #expect(weakOwner == nil)

        _ = vc.view
    }
}
