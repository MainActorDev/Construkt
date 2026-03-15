//
//  SheetTransitionAnimator.swift
//  Construkt
//

import UIKit

public final class SheetTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let isPresenting: Bool
    let config: SheetConfiguration
    
    public init(isPresenting: Bool, config: SheetConfiguration) {
        self.isPresenting = isPresenting
        self.config = config
        super.init()
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        config.baseDuration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toController = transitionContext.viewController(forKey: .to),
              let fromController = transitionContext.viewController(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let animatedController = isPresenting ? toController : fromController
        let animatedView = transitionContext.view(forKey: isPresenting ? .to : .from) ?? animatedController.view!
        
        if isPresenting {
            containerView.addSubview(animatedView)
        }
        
        let finalFrame = transitionContext.finalFrame(for: toController)
        var startFrame = finalFrame
        var endFrame = finalFrame
        
        if config.transitionStyle == .bottomSheet {
            if isPresenting {
                startFrame.origin.y = containerView.bounds.height
                animatedView.frame = startFrame
            } else {
                endFrame.origin.y = containerView.bounds.height
            }
        } else if config.transitionStyle == .push {
            if isPresenting {
                startFrame.origin.x = containerView.bounds.width
                animatedView.frame = startFrame
            } else {
                endFrame.origin.x = containerView.bounds.width
            }
        }
        
        let duration = transitionDuration(using: transitionContext)
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                animatedView.frame = self.isPresenting ? finalFrame : endFrame
            },
            completion: { finished in
                if !self.isPresenting {
                    animatedView.removeFromSuperview()
                }
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
}
