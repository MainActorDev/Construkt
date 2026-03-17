// 
//  👨‍💻 Created by @thatswiftdev on 02/11/25.
//
//  © 2025, https://github.com/thatswiftdev. All rights reserved.
//
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import UIKit
import ConstruktKit


@available(iOS 15.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var appCoordinator: AppCoordinator?
    // private var appRouteHandler: AppRouteHandler? // (Example usage kept below)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // Setup TabBar and Coordinator
        let baseRouter = DefaultRouter()
        let factory = ScreenFactory()
        let coordinator = AppCoordinator(router: baseRouter, factory: factory)
        
        /*
        // --- ConstruktRouteHandler Example (Alternative to Coordinators) ---
        //
        // If you prefer not to use Coordinators, you can use AppRouteHandler directly:
        //
        // let tabBarController = UITabBarController()
        // let routeHandler = AppRouteHandler(router: baseRouter, tabBarController: tabBarController)
        // routeHandler.setupTabs()
        // self.appRouteHandler = routeHandler
        // tabBarController.associatedRouteHandler = routeHandler
        */

        // Initial Loading Screen
        let launchVC = LaunchViewController()
        launchVC.onFinished = { [weak self] in
            // Boot Core Flow
            coordinator.start()
            self?.appCoordinator = coordinator
            
            // Crossfade transition to main layout
            UIView.transition(
                with: window,
                duration: 0.4,
                options: .transitionCrossDissolve,
                animations: {
                    self?.window?.rootViewController = coordinator.rootViewController()
                }
            )
        }
        
        window.rootViewController = launchVC
        window.makeKeyAndVisible()
        
        #if DEBUG
        LifecycleDebugTrigger.enable(on: window)
        #endif
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    // MARK: - Deep Links
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        print("🔗 Deep Link Received: \(url.absoluteString)")
        print("🔗 AppCoordinator Status: \(String(describing: appCoordinator))")
        appCoordinator?.handleDeepLink(url)
        
        /*
        // --- ConstruktRouteHandler Deep Link Example ---
        // appRouteHandler?.handleDeepLink(url)
        */
    }
}

