//
//  ToastManager.swift
//  Construkt
//

import UIKit

@MainActor
public final class ToastManager {
    
    public static let shared = ToastManager()
    
    private var activeToasts: [(toast: ToastItem, view: ToastItemView)] = []
    private var containerView: UIView?
    private weak var hostWindow: UIWindow?
    
    private init() {}
    
    public func show(content: UIViewController, config: ToastConfiguration, in window: UIWindow) {
        setupContainerIfNeeded(in: window)
        
        let toast = ToastItem(content: content, config: config)
        let toastView = createToastView(for: toast, config: config)
        
        containerView?.addSubview(toastView)
        activeToasts.append((toast, toastView))
        
        let animator = ToastAnimator(config: config)
        
        setupInitialToastFrame(toastView, config: config, animator: animator)
        relayoutAllToasts(animated: false)
        animator.animateEnter(toastView)
        
        toast.scheduleAutoDismiss(after: config.duration) { [weak self, weak toast] in
            guard let self = self, let toast = toast else { return }
            self.dismiss(toast: toast, animated: true)
        }
    }
    
    public func dismissAll(animated: Bool) {
        activeToasts.forEach { $0.toast.cancelAutoDismiss() }
        
        if animated {
            let group = DispatchGroup()
            for item in activeToasts {
                group.enter()
                let animator = ToastAnimator(config: item.toast.config)
                animator.animateExit(item.view) {
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                self?.containerView?.removeFromSuperview()
                self?.containerView = nil
                self?.activeToasts.removeAll()
                self?.hostWindow = nil
            }
        } else {
            containerView?.removeFromSuperview()
            containerView = nil
            activeToasts.removeAll()
            hostWindow = nil
        }
    }
    
    private func setupContainerIfNeeded(in window: UIWindow) {
        guard containerView == nil || hostWindow !== window else { return }
        
        containerView?.removeFromSuperview()
        
        hostWindow = window
        
        let container = UIView()
        container.backgroundColor = .clear
        container.frame = window.bounds
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(container)
        
        containerView = container
    }
    
    private func createToastView(for toast: ToastItem, config: ToastConfiguration) -> ToastItemView {
        let toastView = ToastItemView(config: config)
        toastView.setContent(toast.contentViewController, in: nil)
        
        toastView.onTap = { [weak self, weak toast] in
            guard let self = self, let toast = toast else { return }
            if config.dismissOnTap {
                toast.cancelAutoDismiss()
                self.dismiss(toast: toast, animated: true)
            }
        }
        
        return toastView
    }
    
    private func setupInitialToastFrame(_ toastView: ToastItemView, config: ToastConfiguration, animator: ToastAnimator) {
        let containerBounds = containerView?.bounds ?? .zero
        let horizontalPadding = config.horizontalPadding
        
        let targetWidth = containerBounds.width - (horizontalPadding * 2)
        let fittingSize = toastView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        var frame = CGRect(x: horizontalPadding, y: 0, width: targetWidth, height: fittingSize.height)
        
        let containerBoundsHeight = containerBounds.height
        
        switch config.position {
        case .top:
            frame.origin.y = -frame.height
        case .bottom:
            frame.origin.y = containerBoundsHeight
        }
        
        toastView.frame = frame
        
        animator.prepareForEnter(toastView, containerBounds: containerBounds)
    }
    
    private func relayoutAllToasts(animated: Bool) {
        guard let containerView = containerView else { return }
        
        let containerBounds = containerView.bounds
        let safeArea = containerView.safeAreaInsets
        
        let topToasts = activeToasts.filter { $0.toast.config.position.isTop }
        let bottomToasts = activeToasts.filter { $0.toast.config.position.isBottom }
        
        var currentTopY = safeArea.top
        for (index, item) in topToasts.enumerated() {
            let config = item.toast.config
            let spacing = config.spacingBetweenToasts
            let offset: CGFloat
            switch config.position {
            case .top(let o): offset = o
            default: offset = 0
            }
            
            if index == 0 {
                currentTopY = safeArea.top + offset + spacing
            }
            
            let targetFrame = CGRect(
                x: item.view.frame.origin.x,
                y: currentTopY,
                width: item.view.frame.width,
                height: item.view.frame.height
            )
            
            currentTopY += item.view.frame.height + spacing
            
            if animated {
                UIView.animate(
                    withDuration: config.animationDuration,
                    delay: 0,
                    usingSpringWithDamping: config.springDamping,
                    initialSpringVelocity: 0,
                    options: [.curveEaseOut],
                    animations: {
                        item.view.frame = targetFrame
                    }
                )
            } else {
                item.view.frame = targetFrame
            }
        }
        
        var currentBottomY = containerBounds.height
        for (index, item) in bottomToasts.enumerated() {
            let config = item.toast.config
            let spacing = config.spacingBetweenToasts
            let offset: CGFloat
            switch config.position {
            case .bottom(let o): offset = o
            default: offset = 0
            }
                        
            currentBottomY -= spacing
            
            if index == 0 {
                currentBottomY -= offset
            }
            
            let targetFrame = CGRect(
                x: item.view.frame.origin.x,
                y: currentBottomY,
                width: item.view.frame.width,
                height: item.view.frame.height
            )
            
            if animated {
                UIView.animate(
                    withDuration: config.animationDuration,
                    delay: 0,
                    usingSpringWithDamping: config.springDamping,
                    initialSpringVelocity: 0,
                    options: [.curveEaseOut],
                    animations: {
                        item.view.frame = targetFrame
                    }
                )
            } else {
                item.view.frame = targetFrame
            }
        }
    }
    
    private func dismiss(toast: ToastItem, animated: Bool) {
        guard let index = activeToasts.firstIndex(where: { $0.toast === toast }) else { return }
        
        let item = activeToasts.remove(at: index)
        let toastView = item.view
        let animator = ToastAnimator(config: item.toast.config)
        
        let completion: () -> Void = { [weak self] in
            guard let self = self else { return }
            toastView.removeFromSuperview()
            toast.onDismiss?()
            self.relayoutAllToasts(animated: true)
            
            if self.activeToasts.isEmpty {
                self.containerView?.removeFromSuperview()
                self.containerView = nil
                self.hostWindow = nil
            }
        }
        
        if animated {
            animator.animateExit(toastView, completion: completion)
        } else {
            completion()
        }
    }
}
