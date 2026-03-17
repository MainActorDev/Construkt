//
//  LifecycleDebugTrigger.swift
//  Construkt Demo
//

import UIKit
import ConstruktKit

@MainActor
final class LifecycleDebugTrigger {
    private weak var window: UIWindow?
    private var gestureRecognizer: UILongPressGestureRecognizer?
    
    private init(window: UIWindow) {
        self.window = window
    }
    
    static func enable(on window: UIWindow) {
        #if DEBUG
        let config = LifecycleHostTracker.shared.configuration
        guard config.isEnabled else { return }
        
        switch config.debugTrigger {
        case .shake:
            enableShakeTrigger(on: window)
        case .threeFingerLongPress:
            enableThreeFingerTrigger(on: window)
        case .disabled:
            break
        }
        #endif
    }
    
    private static func enableShakeTrigger(on window: UIWindow) {
        swizzleMotionEnded()
    }
    
    private static func enableThreeFingerTrigger(on window: UIWindow) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleThreeFingerLongPress(_:)))
        gesture.numberOfTouchesRequired = 3
        gesture.minimumPressDuration = 1.5
        window.addGestureRecognizer(gesture)
    }
    
    @objc private static func handleThreeFingerLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        guard let window = gesture.view as? UIWindow else { return }
        presentDebugView(from: window)
    }
    
    static func presentDebugView(from window: UIWindow) {
        let config = LifecycleHostTracker.shared.configuration
        let debugVC = LifecycleDebugViewController(config: config)
        let nav = UINavigationController(rootViewController: debugVC)
        nav.modalPresentationStyle = .formSheet
        nav.overrideUserInterfaceStyle = .dark
        
        window.rootViewController?.present(nav, animated: true)
    }
    
    private static func swizzleMotionEnded() {
        let original = class_getInstanceMethod(UIResponder.self, #selector(UIResponder.motionEnded(_:with:)))
        let swizzled = class_getInstanceMethod(UIResponder.self, #selector(UIResponder.construkt_motionEnded(_:with:)))
        
        if let original = original, let swizzled = swizzled {
            method_exchangeImplementations(original, swizzled)
        }
    }
}

extension UIResponder {
    @objc func construkt_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        construkt_motionEnded(motion, with: event)
        
        guard motion == .motionShake else { return }
        guard LifecycleHostTracker.shared.configuration.isEnabled else { return }
        guard LifecycleHostTracker.shared.configuration.debugTrigger == .shake else { return }
        
        var targetWindow: UIWindow?
        if let window = self as? UIWindow {
            targetWindow = window
        } else if let view = self as? UIView {
            targetWindow = view.window
        } else if let vc = self as? UIViewController {
            targetWindow = vc.viewIfLoaded?.window
        }
        
        guard let window = targetWindow else { return }
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        LifecycleDebugTrigger.presentDebugView(from: window)
    }
}
