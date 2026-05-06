//
//  SheetController.swift
//  Construkt
//

import UIKit

public final class SheetController: UIViewController {
    
    public var onDismiss: (() -> Void)?
    
    private let containerView = UIView()
    private let topHandle = UIView()
    private let contentVC: UIViewController
    
    private let config: SheetConfiguration
    
    private var containerHeightConstraint: NSLayoutConstraint!
    private var containerBottomConstraint: NSLayoutConstraint!
    private var containerLeadingConstraint: NSLayoutConstraint!
    
    private var panStartBottomConstant: CGFloat = 0
    private var panStartLeadingConstant: CGFloat = 0
    private weak var scrollView: UIScrollView?
    private var keyboardHeight: CGFloat = 0
    
    private var resolvedAnchors: [CGFloat] = []
    
    public init(content: UIViewController, config: SheetConfiguration) {
        self.contentVC = content
        self.config = config
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        embedContent()
        setupGestures()
        
        if config.handleKeyboard {
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resolveAnchors()
        
        if containerBottomConstraint?.constant == 0 && config.transitionStyle == .bottomSheet {
            _ = snapToNearest(forProjectedBottom: 0, velocity: 0)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        containerView.backgroundColor = config.backgroundColor
        containerView.clipsToBounds = true
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.layer.cornerRadius = config.cornerRadius
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(containerView)
        
        switch config.transitionStyle {
        case .bottomSheet:
            containerLeadingConstraint = containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            let trailing = containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            containerHeightConstraint = containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor)
            containerHeightConstraint.priority = .required - 1
            containerHeightConstraint.constant = 0
            
            NSLayoutConstraint.activate([
                containerLeadingConstraint!, trailing, containerBottomConstraint!, containerHeightConstraint
            ])
            
            if config.showDragHandle {
                topHandle.backgroundColor = .systemGray4
                topHandle.layer.cornerRadius = 3
                topHandle.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(topHandle)
                
                NSLayoutConstraint.activate([
                    topHandle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                    topHandle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                    topHandle.widthAnchor.constraint(equalToConstant: 44),
                    topHandle.heightAnchor.constraint(equalToConstant: 6)
                ])
            }
            
        case .push:
            let initialOffset = view.bounds.width * (1.0 - config.pushWidthFraction)
            containerLeadingConstraint = containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: initialOffset)
            let top = containerView.topAnchor.constraint(equalTo: view.topAnchor)
            let bottom = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            let trailing = containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            
            NSLayoutConstraint.activate([
                containerLeadingConstraint!, top, bottom, trailing
            ])
        }
    }
    
    private func embedContent() {
        addChild(contentVC)
        contentVC.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentVC.view)
        
        let topAnchor: NSLayoutYAxisAnchor = config.transitionStyle == .bottomSheet && config.showDragHandle
            ? topHandle.bottomAnchor
            : containerView.topAnchor
        
        let topConstant: CGFloat = config.showDragHandle ? 8 : 0
        
        NSLayoutConstraint.activate([
            contentVC.view.topAnchor.constraint(equalTo: topAnchor, constant: topConstant),
            contentVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        contentVC.didMove(toParent: self)
        
        if config.coordinateScrollGestures {
            findScrollView()
        }
    }
    
    private func resolveAnchors() {
        guard config.transitionStyle == .bottomSheet else { return }
        
        var heights: [CGFloat] = []
        let safeContainerHeight = view.bounds.height - view.safeAreaInsets.top
        
        for anchor in config.anchors {
            switch anchor {
            case .fraction(let f):
                heights.append(f * view.bounds.height)
            case .absolute(let p):
                heights.append(p)
            case .intrinsic(let maxFrac):
                contentVC.view.layoutIfNeeded()
                let targetSize = CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
                var intrinsicHeight: CGFloat = 0
                
                if let scrollView = contentVC.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                    scrollView.layoutIfNeeded()
                    intrinsicHeight = scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom
                } else {
                    intrinsicHeight = contentVC.view.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
                }
                
                if config.showDragHandle { intrinsicHeight += 22 }
                
                if let maxF = maxFrac {
                    intrinsicHeight = min(intrinsicHeight, view.bounds.height * maxF)
                }
                
                heights.append(min(intrinsicHeight, safeContainerHeight))
            }
        }
        
        resolvedAnchors = heights.sorted()
        
        if let maxH = resolvedAnchors.last {
            containerHeightConstraint.constant = maxH + keyboardHeight
        }
    }
    
    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        if config.coordinateScrollGestures { pan.delegate = self }
        view.addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        if config.tapToDismiss { dismissSheet() }
    }
    
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let velocity = pan.velocity(in: view)
        
        switch config.transitionStyle {
        case .bottomSheet:
            handleBottomSheetPan(pan, translation: translation, velocity: velocity)
        case .push:
            handlePushPan(pan, translation: translation, velocity: velocity)
        }
    }
    
    private func handleBottomSheetPan(_ pan: UIPanGestureRecognizer, translation: CGPoint, velocity: CGPoint) {
        switch pan.state {
        case .began:
            panStartBottomConstant = containerBottomConstraint?.constant ?? 0
            containerView.layer.removeAllAnimations()
        case .changed:
            let newBottom = max(0, panStartBottomConstant + translation.y)
            let clampedBottom = newBottom < 0 ? newBottom * 0.2 : newBottom
            containerView.transform = CGAffineTransform(translationX: 0, y: clampedBottom)
            
        case .ended, .cancelled, .failed:
            let projectedTranslation = translation.y + velocity.y * 0.15
            let projectedBottom = panStartBottomConstant + projectedTranslation
            
            let targetOffset = snapToNearest(forProjectedBottom: projectedBottom, velocity: velocity.y)
            
            if targetOffset > (resolvedAnchors.last ?? 0) * 0.8 || velocity.y > 1000 {
                dismissSheet()
                return
            }
            
            animateToBottomOffset(targetOffset, velocity: velocity.y)
        default: break
        }
    }
    
    private func snapToNearest(forProjectedBottom bottomOffset: CGFloat, velocity: CGFloat) -> CGFloat {
        guard let maxH = resolvedAnchors.last else { return 0 }
        
        let currentVisualHeight = maxH - bottomOffset
        
        if velocity < -250 { return 0 }
        if velocity > 250 && currentVisualHeight < (resolvedAnchors.first ?? 0) {
            return maxH
        }
        
        var nearestHeight = resolvedAnchors.first ?? 0
        var minDiff = CGFloat.greatestFiniteMagnitude
        
        for anchorH in resolvedAnchors {
            let diff = abs(anchorH - currentVisualHeight)
            if diff < minDiff {
                minDiff = diff
                nearestHeight = anchorH
            }
        }
        
        return maxH - nearestHeight
    }
    
    private func animateToBottomOffset(_ offset: CGFloat, velocity: CGFloat = 0) {
        containerView.transform = .identity
        containerBottomConstraint?.constant = offset
        
        UIView.animate(withDuration: config.baseDuration,
                       delay: 0,
                       usingSpringWithDamping: config.springDamping,
                       initialSpringVelocity: abs(velocity) / 1000,
                       options: [.allowUserInteraction, .curveEaseOut]) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func handlePushPan(_ pan: UIPanGestureRecognizer, translation: CGPoint, velocity: CGPoint) {
        switch pan.state {
        case .began:
            panStartLeadingConstant = containerLeadingConstraint?.constant ?? 0
            containerView.layer.removeAllAnimations()
        case .changed:
            if translation.x > 0 {
                containerView.transform = CGAffineTransform(translationX: translation.x, y: 0)
            }
        case .ended, .cancelled, .failed:
            if translation.x > view.bounds.width * 0.25 || velocity.x > 500 {
                dismissSheet()
            } else {
                containerView.transform = .identity
                UIView.animate(withDuration: config.baseDuration) {
                    self.view.layoutIfNeeded()
                }
            }
        default: break
        }
    }
    
    private func findScrollView() {
        func walk(_ v: UIView) -> UIScrollView? {
            if let s = v as? UIScrollView { return s }
            for sub in v.subviews { if let r = walk(sub) { return r } }
            return nil
        }
        scrollView = walk(contentVC.view)
        scrollView?.contentInsetAdjustmentBehavior = .never
    }
    
    public func dismissSheet() {
        onDismiss?()
        dismiss(animated: true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        self.keyboardHeight = frame.height
        
        if config.transitionStyle == .bottomSheet {
            containerHeightConstraint?.constant = (resolvedAnchors.last ?? 0) + keyboardHeight
            containerBottomConstraint?.constant = -keyboardHeight
        }
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        self.keyboardHeight = 0
        
        if config.transitionStyle == .bottomSheet {
            containerHeightConstraint?.constant = resolvedAnchors.last ?? 0
            containerBottomConstraint?.constant = 0
        }
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
}

extension SheetController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard config.coordinateScrollGestures else { return true }
        guard let pan = g as? UIPanGestureRecognizer else { return true }
        guard let scroll = scrollView else { return true }
        
        let v = pan.velocity(in: view)
        let up = (v.y < 0)
        let down = (v.y > 0)
        
        let atTop = scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 0.5
        let atBottom = scroll.contentOffset.y >= (scroll.contentSize.height - scroll.bounds.height) - 0.5
        
        if up && atBottom { return true }
        if down && atTop { return true }
        
        return false
    }
    
    public func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        guard config.coordinateScrollGestures else { return false }
        guard let scroll = scrollView else { return false }
        return other == scroll.panGestureRecognizer
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer {
            let location = touch.location(in: view)
            return !containerView.frame.contains(location)
        }
        return true
    }
}

extension SheetController: UIViewControllerTransitioningDelegate {
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let pc = SheetPresentationController(presentedViewController: presented, presenting: presenting, config: config)
        pc.onDismiss = { [weak self] in self?.onDismiss?() }
        return pc
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        SheetTransitionAnimator(isPresenting: true, config: config)
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        SheetTransitionAnimator(isPresenting: false, config: config)
    }
}
