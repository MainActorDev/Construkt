//
//  SheetPresentationController.swift
//  Construkt
//

import UIKit

public final class SheetPresentationController: UIPresentationController {
    
    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(config.dimOpacity)
        view.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDimmingViewTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }()
    
    private let config: SheetConfiguration
    
    var onDismiss: (() -> Void)?
    
    init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, config: SheetConfiguration) {
        self.config = config
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
    public override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, at: 0)
        
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 1.0
            }, completion: nil)
        } else {
            dimmingView.alpha = 1.0
        }
    }
    
    public override func dismissalTransitionWillBegin() {
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 0.0
            }, completion: nil)
        } else {
            dimmingView.alpha = 0.0
        }
    }
    
    public override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let containerView = containerView else { return }
        dimmingView.frame = containerView.bounds
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    
    public override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        return containerView.bounds
    }
    
    @objc private func handleDimmingViewTap(_ sender: UITapGestureRecognizer) {
        onDismiss?()
        presentedViewController.dismiss(animated: true, completion: nil)
    }
}
