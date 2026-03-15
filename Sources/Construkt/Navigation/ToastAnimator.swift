//
//  ToastAnimator.swift
//  Construkt
//

import UIKit

struct ToastAnimator {
    
    let config: ToastConfiguration
    
    init(config: ToastConfiguration) {
        self.config = config
    }
    
    func prepareForEnter(_ view: UIView, containerBounds: CGRect) {
        view.alpha = 0
        
        switch config.enterAnimation {
        case .fade:
            view.transform = .identity
            
        case .slide:
            view.transform = slideTransform(for: view, containerBounds: containerBounds, isEnter: true)
            
        case .slideAndFade:
            view.transform = slideTransform(for: view, containerBounds: containerBounds, isEnter: true)
            
        case .scale:
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
        case .scaleAndFade:
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
        case .bounce:
            view.transform = slideTransform(for: view, containerBounds: containerBounds, isEnter: true)
            
        case .pop:
            view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            
        case .flip:
            view.layer.anchorPoint = CGPoint(x: 0.5, y: config.position.isTop ? 0.0 : 1.0)
            view.transform = CGAffineTransform(rotationAngle: config.position.isTop ? -.pi / 2 : .pi / 2)
            
        case .none:
            view.alpha = 1
            view.transform = .identity
        }
    }
    
    func animateEnter(_ view: UIView, completion: (() -> Void)? = nil) {
        switch config.enterAnimation {
        case .fade:
            animateFade(view, toAlpha: 1, completion: completion)
            
        case .slide:
            animateSlide(view, completion: completion)
            
        case .slideAndFade:
            animateSlideAndFade(view, toAlpha: 1, completion: completion)
            
        case .scale:
            animateScale(view, toScale: 1, completion: completion)
            
        case .scaleAndFade:
            animateScaleAndFade(view, toScale: 1, toAlpha: 1, completion: completion)
            
        case .bounce:
            animateBounce(view, completion: completion)
            
        case .pop:
            animatePop(view, completion: completion)
            
        case .flip:
            animateFlip(view, isEnter: true, completion: completion)
            
        case .none:
            completion?()
        }
    }
    
    func animateExit(_ view: UIView, completion: @escaping () -> Void) {
        switch config.exitAnimation {
        case .fade:
            animateFade(view, toAlpha: 0, completion: completion)
            
        case .slide:
            animateSlideOut(view, completion: completion)
            
        case .slideAndFade:
            animateSlideAndFade(view, toAlpha: 0, completion: completion)
            
        case .scale:
            animateScale(view, toScale: 0.8, completion: completion)
            
        case .scaleAndFade:
            animateScaleAndFade(view, toScale: 0.8, toAlpha: 0, completion: completion)
            
        case .bounce:
            animateBounceOut(view, completion: completion)
            
        case .pop:
            animatePopOut(view, completion: completion)
            
        case .flip:
            animateFlip(view, isEnter: false, completion: completion)
            
        case .none:
            completion()
        }
    }
    
    // MARK: - Private Helpers
    
    private func slideTransform(for view: UIView, containerBounds: CGRect, isEnter: Bool) -> CGAffineTransform {
        let offset = isEnter ? (view.frame.height + 50) : -(view.frame.height + 50)
        
        switch config.position {
        case .top:
            return CGAffineTransform(translationX: 0, y: -offset)
        case .bottom:
            return CGAffineTransform(translationX: 0, y: offset)
        }
    }
    
    private func animateFade(_ view: UIView, toAlpha: CGFloat, completion: (() -> Void)?) {
        UIView.animate(
            withDuration: config.animationDuration,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                view.alpha = toAlpha
            },
            completion: { _ in completion?() }
        )
    }
    
    private func animateSlide(_ view: UIView, completion: (() -> Void)?) {
        UIView.animate(
            withDuration: config.animationDuration,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                view.transform = .identity
                view.alpha = 1
            },
            completion: { _ in completion?() }
        )
    }
    
    private func animateSlideAndFade(_ view: UIView, toAlpha: CGFloat, completion: (() -> Void)?) {
        UIView.animate(
            withDuration: config.animationDuration,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: 0,
            options: [.curveEaseOut],
            animations: {
                view.transform = .identity
                view.alpha = toAlpha
            },
            completion: { _ in completion?() }
        )
    }
    
    private func animateSlideOut(_ view: UIView, completion: @escaping () -> Void) {
        let containerBounds = view.superview?.bounds ?? .zero
        let transform = slideTransform(for: view, containerBounds: containerBounds, isEnter: false)
        
        UIView.animate(
            withDuration: config.animationDuration,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                view.transform = transform
                view.alpha = 0
            },
            completion: { _ in completion() }
        )
    }
    
    private func animateScale(_ view: UIView, toScale: CGFloat, completion: (() -> Void)?) {
        UIView.animate(
            withDuration: config.animationDuration,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                view.transform = CGAffineTransform(scaleX: toScale, y: toScale)
            },
            completion: { _ in completion?() }
        )
    }
    
    private func animateScaleAndFade(_ view: UIView, toScale: CGFloat, toAlpha: CGFloat, completion: (() -> Void)?) {
        UIView.animate(
            withDuration: config.animationDuration,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: 0,
            options: [.curveEaseOut],
            animations: {
                view.transform = CGAffineTransform(scaleX: toScale, y: toScale)
                view.alpha = toAlpha
            },
            completion: { _ in completion?() }
        )
    }
    
    private func animateBounce(_ view: UIView, completion: (() -> Void)?) {
        UIView.animate(
            withDuration: config.animationDuration * 1.2,
            delay: 0,
            usingSpringWithDamping: config.springDamping,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut],
            animations: {
                view.transform = .identity
                view.alpha = 1
            },
            completion: { _ in completion?() }
        )
    }
    
    private func animateBounceOut(_ view: UIView, completion: @escaping () -> Void) {
        let containerBounds = view.superview?.bounds ?? .zero
        let transform = slideTransform(for: view, containerBounds: containerBounds, isEnter: false)
        
        UIView.animate(
            withDuration: config.animationDuration * 0.8,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0.8,
            options: [.curveEaseIn],
            animations: {
                view.transform = transform
                view.alpha = 0
            },
            completion: { _ in completion() }
        )
    }
    
    private func animatePop(_ view: UIView, completion: (() -> Void)?) {
        view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(
            withDuration: config.animationDuration * 0.6,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8,
            options: [.curveEaseOut],
            animations: {
                view.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                view.alpha = 1
            },
            completion: { _ in
                UIView.animate(
                    withDuration: config.animationDuration * 0.4,
                    delay: 0,
                    options: [.curveEaseOut],
                    animations: {
                        view.transform = .identity
                    },
                    completion: { _ in completion?() }
                )
            }
        )
    }
    
    private func animatePopOut(_ view: UIView, completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: config.animationDuration * 0.5,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                view.alpha = 0
            },
            completion: { _ in completion() }
        )
    }
    
    private func animateFlip(_ view: UIView, isEnter: Bool, completion: (() -> Void)?) {
        let startAngle: CGFloat
        let endAngle: CGFloat
        
        if isEnter {
            startAngle = config.position.isTop ? -.pi / 2 : .pi / 2
            endAngle = 0
            view.layer.anchorPoint = CGPoint(x: 0.5, y: config.position.isTop ? 0.0 : 1.0)
        } else {
            startAngle = 0
            endAngle = config.position.isTop ? -.pi / 2 : .pi / 2
        }
        
        view.transform = CGAffineTransform(rotationAngle: startAngle)
        
        let durationMultiplier: CGFloat = isEnter ? 1.0 : 0.7
        
        UIView.animate(
            withDuration: config.animationDuration * durationMultiplier,
            delay: 0,
            usingSpringWithDamping: isEnter ? config.springDamping : 1.0,
            initialSpringVelocity: 0,
            options: isEnter ? [.curveEaseOut] : [.curveEaseIn],
            animations: {
                view.transform = CGAffineTransform(rotationAngle: endAngle)
                view.alpha = isEnter ? 1 : 0
            },
            completion: { _ in
                if !isEnter {
                    view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    view.transform = .identity
                }
                completion?()
            }
        )
    }
}
