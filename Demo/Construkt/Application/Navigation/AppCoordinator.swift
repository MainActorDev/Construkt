import UIKit
import ConstruktKit

@MainActor
enum AppTab: Int {
    case home = 0
    case explore = 1
    case profile = 2
}

@available(iOS 15.0, *)
@MainActor
final class AppCoordinator: BaseCoordinator, RouteHandlingCoordinator {
    
    let router: any ConstruktRouter
    private let factory: ScreenFactoryProtocol
    private let tabBarController = UITabBarController()
    private let deepLinkMapper: DeepLinkMapper
    
    /// Keep a serializable path for restoration.
    public private(set) var currentPath: [AppRoute] = []
    
    init(router: any ConstruktRouter, factory: ScreenFactoryProtocol, deepLinkMapper: DeepLinkMapper = .init()) {
        self.router = router
        self.factory = factory
        self.deepLinkMapper = deepLinkMapper
        super.init()
    }
    
    override func start() {
        let homeNav = NavigationController()
        let AppRouter = DefaultRouter(navigationController: homeNav)
        let homeCoordinator = HomeCoordinator(router: AppRouter, factory: factory)
        store(homeCoordinator)
        
        // Setup Home Tab
        homeCoordinator.onSwitchToExplore = { [weak self] in
            self?.switchToTab(.explore)
        }
        homeCoordinator.start()
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        
        let exploreNav = NavigationController()
        let exploreRouter = DefaultRouter(navigationController: exploreNav)
        let exploreCoordinator = ExploreCoordinator(router: exploreRouter, factory: factory)
        store(exploreCoordinator)
        
        // Setup Explore Tab
        exploreCoordinator.start()
        exploreNav.tabBarItem = UITabBarItem(title: "Explore", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "text.magnifyingglass"))
        
        let profileNav = NavigationController()
        let profileRouter = DefaultRouter(navigationController: profileNav)
        let profileCoordinator = ProfileCoordinator(router: profileRouter, factory: factory)
        store(profileCoordinator)
        
        // Setup Profile Tab
        profileCoordinator.start()
        profileNav.tabBarItem = UITabBarItem(title: ProfileView.screenTitle, image: UIImage(systemName: "person.crop.circle"), selectedImage: UIImage(systemName: "person.crop.circle.fill"))
       
        tabBarController.viewControllers = [homeNav, exploreNav, profileNav]
        
        // Styling TabBar roughly (can refine later with custom subclass)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        tabBarController.tabBar.standardAppearance = appearance
        tabBarController.tabBar.scrollEdgeAppearance = appearance
        tabBarController.tabBar.tintColor = .white
        tabBarController.tabBar.unselectedItemTintColor = .gray
    }
    
    func switchToTab(_ tab: AppTab) {
        tabBarController.selectedIndex = tab.rawValue
    }
    
    // MARK: Public navigation & deep link API
    
    public func open(_ route: AppRoute, animated: Bool = true) {
        currentPath.append(route)
        
        switch route {
        case .home:
            switchToTab(.home)
        case .explore, .search:
            switchToTab(.explore)
        case .profile:
            switchToTab(.profile)
        case .movieDetail:
            let screen = factory.makeScreen(for: route)
            router.push(screen, animated: true, hideTabBar: true, receiver: self)
        case .back:
            router.pop(animated: true)
        default:
            return
        }
    }
    
    func canReceive(_ event: AppRoute, sender: Any?) -> Bool {
        open(event)
        return true
    }
    
    public func handleDeepLink(_ url: URL) {
        guard let route = deepLinkMapper.route(from: url) else { return }
        open(route)
    }
    
    // MARK: Restoration
    
    public func saveRestorationData() -> Data? {
        try? JSONEncoder().encode(currentPath)
    }
    
    public func restore(from data: Data) {
        guard let saved = try? JSONDecoder().decode([AppRoute].self, from: data) else { return }
        // Set the root to the first item (e.g. .home) and manually replay the route pushes.
        // currentPath = saved
        // Logic for restoring children navigation controllers stack sequentially.
    }
    
    /// Returns the main tab bar controller as the root of this coordinator.
    func rootViewController() -> UIViewController {
        tabBarController
    }
    
    // MARK: - Helpers
    
    private func activeNavigationController(for viewController: UIViewController) -> UINavigationController? {
        if let nav = viewController as? UINavigationController {
            return nav
        }
        if let tab = viewController as? UITabBarController, let selected = tab.selectedViewController {
            return activeNavigationController(for: selected)
        }
        if let presented = viewController.presentedViewController {
            return activeNavigationController(for: presented)
        }
        return viewController.navigationController
    }
}
