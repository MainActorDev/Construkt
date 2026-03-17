//
//  ConstruktRouter.swift
//  Construkt
//

import UIKit

public enum SheetDetent {
    case medium
    case large
}

public enum ModalStyle {
    case sheet(detents: [SheetDetent] = [.medium, .large], prefersGrabberVisible: Bool = true)
    case pageSheet
    case fullScreen
    case formSheet
    case configurable(SheetConfiguration)
    case custom((UIViewController) -> Void)
}

public protocol ConstruktRouter: AnyObject {
    var navigationController: UINavigationController { get }
    func setRoot(_ module: ConstruktPresentable, hideBar: Bool, animated: Bool, receiver: AnyRouteReceiving?)
    func push(_ module: ConstruktPresentable, animated: Bool, hideTabBar: Bool, completion: (() -> Void)?, receiver: AnyRouteReceiving?)
    func pop(animated: Bool)
    func popToRoot(animated: Bool)
    func present(_ module: ConstruktPresentable, style: ModalStyle, animated: Bool, completion: (() -> Void)?, receiver: AnyRouteReceiving?)
    func dismiss(animated: Bool, completion: (() -> Void)?)
    func showToast(_ module: ConstruktPresentable, config: ToastConfiguration)
    func replaceStack(with modules: [ConstruktPresentable], completion: (() -> Void)?, receiver: AnyRouteReceiving?, animated: Bool)
}

public extension ConstruktRouter {
    func setRoot(_ module: ConstruktPresentable, hideBar: Bool = false, animated: Bool = true, receiver: AnyRouteReceiving? = nil) {
        setRoot(module, hideBar: hideBar, animated: animated, receiver: receiver)
    }
    
    func push(_ module: ConstruktPresentable, animated: Bool = true, hideTabBar: Bool = false, completion: (() -> Void)? = nil, receiver: AnyRouteReceiving? = nil) {
        push(module, animated: animated, hideTabBar: hideTabBar, completion: completion, receiver: receiver)
    }
    
    func pop(animated: Bool = true) {
        pop(animated: animated)
    }
    
    func popToRoot(animated: Bool = true) {
        popToRoot(animated: animated)
    }
    
    func present(_ module: ConstruktPresentable, style: ModalStyle = .pageSheet, animated: Bool = true, completion: (() -> Void)? = nil, receiver: AnyRouteReceiving? = nil) {
        present(module, style: style, animated: animated, completion: completion, receiver: receiver)
    }
    
    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        dismiss(animated: animated, completion: completion)
    }
    
    func showToast(_ module: ConstruktPresentable, config: ToastConfiguration = .bottom()) {
        showToast(module, config: config)
    }
    
    func replaceStack(with modules: [ConstruktPresentable], completion: (() -> Void)? = nil, receiver: AnyRouteReceiving? = nil, animated: Bool = true) {
        replaceStack(with: modules, completion: completion, receiver: receiver, animated: animated)
    }
}

public final class DefaultRouter: NSObject, ConstruktRouter, UINavigationControllerDelegate {
    public let navigationController: UINavigationController
    private var completions: [UIViewController: () -> Void] = [:]
    
    public init(navigationController: UINavigationController = UINavigationController()) {
        self.navigationController = navigationController
        super.init()
        self.navigationController.delegate = self
    }
    
    public func setRoot(_ module: ConstruktPresentable, hideBar: Bool = false, animated: Bool = true, receiver: AnyRouteReceiving? = nil) {
        let vc = module.toPresentable()
        vc.associatedCoordinator = receiver
        navigationController.setViewControllers([vc], animated: animated)
        navigationController.isNavigationBarHidden = hideBar
    }
    
    public func push(_ module: ConstruktPresentable, animated: Bool = true, hideTabBar: Bool = false, completion: (() -> Void)? = nil, receiver: AnyRouteReceiving? = nil) {
        let vc = module.toPresentable()
        vc.associatedCoordinator = receiver
        vc.hidesBottomBarWhenPushed = hideTabBar
        if let completion = completion {
            completions[vc] = completion
        }
        navigationController.pushViewController(vc, animated: animated)
    }
    
    public func pop(animated: Bool = true) {
        if let vc = navigationController.popViewController(animated: animated) {
            runCompletion(for: vc)
        }
    }
    
    public func popToRoot(animated: Bool = true) {
        let popped = navigationController.popToRootViewController(animated: animated) ?? []
        popped.forEach { runCompletion(for: $0) }
    }
    
    public func present(_ module: ConstruktPresentable, style: ModalStyle = .pageSheet, animated: Bool = true, completion: (() -> Void)? = nil, receiver: AnyRouteReceiving? = nil) {
        let vc = module.toPresentable()
        vc.associatedCoordinator = receiver
        
        if case let .configurable(config) = style {
            let sheetVC = SheetController(content: vc, config: config)
            topMostViewController().present(sheetVC, animated: animated, completion: completion)
            return
        }
        
        switch style {
        case .pageSheet:
            vc.modalPresentationStyle = .pageSheet
        case .fullScreen:
            vc.modalPresentationStyle = .fullScreen
        case .formSheet:
            vc.modalPresentationStyle = .formSheet
        case .custom(let configure):
            configure(vc)
        default: break
        }
        
        if #available(iOS 15.0, *) {
            if case let .sheet(detents, grabber) = style {
                vc.modalPresentationStyle = .pageSheet
                if let sheet = vc.sheetPresentationController {
                    sheet.detents = detents.map { d in
                        switch d {
                        case .medium: return .medium()
                        case .large: return .large()
                        }
                    }
                    sheet.prefersGrabberVisible = grabber
                }
            }
        }
        
        topMostViewController().present(vc, animated: animated, completion: completion)
    }
    
    public func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        topMostViewController().dismiss(animated: animated, completion: completion)
    }
    
    public func showToast(_ module: ConstruktPresentable, config: ToastConfiguration = .bottom()) {
        let vc = module.toPresentable()
        guard let window = topMostWindow() else { return }
        ToastManager.shared.show(content: vc, config: config, in: window)
    }
    
    public func replaceStack(with modules: [ConstruktPresentable], completion: (() -> Void)? = nil, receiver: AnyRouteReceiving? = nil, animated: Bool = true) {
        var newStack: [UIViewController] = []
        
        if let existingRoot = navigationController.viewControllers.first {
            newStack.append(existingRoot)
        }
        
        for module in modules {
            let vc = module.toPresentable()
            vc.associatedCoordinator = receiver
            newStack.append(vc)
        }
        
        if let completion = completion, let topVC = newStack.last {
            completions[topVC] = completion
        }
        
        navigationController.setViewControllers(newStack, animated: animated)
    }
    
    // MARK: - UINavigationControllerDelegate
    
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard let fromVC = navigationController.transitionCoordinator?.viewController(forKey: .from),
              !navigationController.viewControllers.contains(fromVC) else { return }
        runCompletion(for: fromVC)
    }
    
    private func runCompletion(for vc: UIViewController) {
        if let completion = completions.removeValue(forKey: vc) {
            completion()
        }
    }
    
    private func topMostViewController(base: UIViewController? = nil) -> UIViewController {
        let base = base ?? navigationController
        if let presented = base.presentedViewController { return topMostViewController(base: presented) }
        if let nav = base as? UINavigationController { return nav.visibleViewController.map { topMostViewController(base: $0) } ?? nav }
        if let tab = base as? UITabBarController { return tab.selectedViewController.map { topMostViewController(base: $0) } ?? tab }
        return base
    }
    
    private func topMostWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
}
