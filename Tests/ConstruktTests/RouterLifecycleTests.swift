import Testing
import UIKit
@testable import ConstruktKit

@Suite("RouterLifecycleTests") @MainActor
struct RouterLifecycleTests {

    @Test("setRoot releases completions for removed controllers")
    func testSetRootRunsCompletionsForRemovedControllers() {
        let navigationController = UINavigationController()
        let router = DefaultRouter(navigationController: navigationController)

        let root = UIViewController()
        router.setRoot(root, hideBar: false, animated: false, receiver: nil)

        var completionCallCount = 0
        let pushed = UIViewController()
        router.push(pushed, animated: false, hideTabBar: false, completion: {
            completionCallCount += 1
        }, receiver: nil)

        #expect(completionCallCount == 0)

        let replacementRoot = UIViewController()
        router.setRoot(replacementRoot, hideBar: false, animated: false, receiver: nil)

        #expect(completionCallCount == 1)

        let secondRoot = UIViewController()
        router.setRoot(secondRoot, hideBar: false, animated: false, receiver: nil)

        #expect(completionCallCount == 1)
    }

    @Test("replaceStack releases completions for removed controllers")
    func testReplaceStackRunsCompletionsForRemovedControllers() {
        let navigationController = UINavigationController()
        let router = DefaultRouter(navigationController: navigationController)

        let root = UIViewController()
        router.setRoot(root, hideBar: false, animated: false, receiver: nil)

        var completionCallCount = 0
        let pushed = UIViewController()
        router.push(pushed, animated: false, hideTabBar: false, completion: {
            completionCallCount += 1
        }, receiver: nil)

        #expect(completionCallCount == 0)

        let replacementTop = UIViewController()
        router.replaceStack(with: [replacementTop], completion: nil, receiver: nil, animated: false)

        #expect(completionCallCount == 1)

        let secondTop = UIViewController()
        router.replaceStack(with: [secondTop], completion: nil, receiver: nil, animated: false)

        #expect(completionCallCount == 1)
    }
}
