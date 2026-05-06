//
//  EventRouting.swift
//  Construkt
//

import UIKit

// MARK: - Type-erased entry (responder chain only knows this)
@MainActor
public protocol AnyRouteReceiving: AnyObject {
    /// Return true if the event was handled (stop bubbling)
    func __receive(_ event: Any, sender: Any?) -> Bool
}

// MARK: - Generic, strongly-typed handler each target conforms to
@MainActor
public protocol RouteReceiving: AnyRouteReceiving {
    associatedtype Event
    func canReceive(_ event: Event, sender: Any?) -> Bool
}

public extension RouteReceiving {
    func __receive(_ event: Any, sender: Any?) -> Bool {
        guard let e = event as? Event else { return false }
        return canReceive(e, sender: sender)
    }
}

// MARK: - Route Dispatcher for UIResponder
public extension UIResponder {
    /// Bubble a strongly-typed payload up the responder chain.
    @discardableResult
    func route<E>(_ event: E, sender: Any?) -> Bool {
        // 1. Check if the current responder can handle it Directly
        if let h = self as? AnyRouteReceiving, h.__receive(event, sender: sender) { return true }
        
        // 2. Check if a UIView has declarative .onReceiveRoute listeners attached
        if let view = self as? UIView {
            for receiver in view.associatedReceivers {
                if receiver.__receive(event, sender: sender) { return true }
            }
        }
        
        // 3. If it's a View Controller, check if it has an isolated Route Handler attached
        if let vc = self as? UIViewController,
           let handler = vc.associatedRouteHandler,
           handler.__receive(event, sender: sender) {
            return true
        }
        
        // 3. If it's a View Controller, check if it has an associated ConstruktCoordinator
        if let vc = self as? UIViewController,
           let coordinator = vc.associatedCoordinator,
           coordinator.__receive(event, sender: sender) {
            return true
        }
        
        // 4. Otherwise, bubble up to the next responder
        return next?.route(event, sender: sender) ?? false
    }
}

private struct CoordinatorLinkKey {
    static var coordinatorKey: UInt8 = 0
}

public extension UIViewController {
    /// A weak reference to the coordinator responsible for this view controller.
    /// This allows events to jump from the UIResponder chain to the ConstruktCoordinator tree.
    var associatedCoordinator: AnyRouteReceiving? {
        get { (objc_getAssociatedObject(self, &CoordinatorLinkKey.coordinatorKey) as? WeakBox)?.value }
        set {
            let box = newValue.map { WeakBox($0) }
            objc_setAssociatedObject(self, &CoordinatorLinkKey.coordinatorKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private final class WeakBox: NSObject {
    weak var value: AnyRouteReceiving?
    init(_ value: AnyRouteReceiving) { self.value = value }
}

private struct ReceiverLinkKey {
    static var receiverKey: UInt8 = 0
}

/// A wrapper to store an array of receivers via `objc_setAssociatedObject` (requires `AnyObject`).
private final class ReceiverBox: NSObject {
    let receivers: [AnyRouteReceiving]
    init(_ receivers: [AnyRouteReceiving]) { self.receivers = receivers }
}

public extension UIView {
    /// An ordered list of declarative route receivers attached to this view.
    /// Multiple `.onReceiveRoute` calls append to this list; events are dispatched first-match-wins.
    internal var associatedReceivers: [AnyRouteReceiving] {
        get { (objc_getAssociatedObject(self, &ReceiverLinkKey.receiverKey) as? ReceiverBox)?.receivers ?? [] }
        set { objc_setAssociatedObject(self, &ReceiverLinkKey.receiverKey, ReceiverBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private func owningViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let next = r?.next {
            if let vc = next as? UIViewController { return vc }
            r = next
        }
        return nil
    }
}

// MARK: - Event Routing View Modifier
public extension ModifiableView where Base: UIView {
    /// Add a tap gesture recognizer that routes the given event payload up the responder chain.
    /// - Parameter event: An autoclosure providing the event to route when tapped.
    @discardableResult
    func onRoute<E>(_ event: @autoclosure @escaping () -> E) -> ViewModifier<Base> {
        return self.with { view in
            // Remove previous route gesture if any
            if let oldGesture = objc_getAssociatedObject(view, &RouteAssociator.routeGestureKey) as? UIGestureRecognizer {
                view.removeGestureRecognizer(oldGesture)
            }
            
            let target = RouteTapTarget(view: view, eventProvider: event)
            
            objc_setAssociatedObject(
                view,
                &RouteAssociator.routeTargetKey,
                target,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            
            let tapGesture = UITapGestureRecognizer(target: target, action: #selector(RouteTapTarget<Any>.handleTap))
            view.addGestureRecognizer(tapGesture)
            view.isUserInteractionEnabled = true
            
            // Store gesture for cleanup on next call
            objc_setAssociatedObject(
                view,
                &RouteAssociator.routeGestureKey,
                tapGesture,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private struct RouteAssociator {
    static var routeTargetKey: UInt8 = 0
    static var routeGestureKey: UInt8 = 0
}

private final class RouteTapTarget<E>: NSObject {
    private weak var view: UIView?
    private let eventProvider: () -> E
    
    init(view: UIView, eventProvider: @escaping () -> E) {
        self.view = view
        self.eventProvider = eventProvider
    }
    
    @objc func handleTap() {
        guard let view = view else { return }
        view.route(eventProvider(), sender: view)
    }
}

// MARK: - Internal Declarative Receivers

@MainActor
final class ClosureRouteReceiver<E>: RouteReceiving {
    typealias Event = E
    private let handler: (E) -> Bool
    
    init(handler: @escaping @MainActor (E) -> Bool) {
        self.handler = handler
    }
    
    func canReceive(_ event: E, sender: Any?) -> Bool {
        return handler(event)
    }
}

@MainActor
final class TargetedClosureRouteReceiver<E, Target: AnyObject>: RouteReceiving {
    typealias Event = E
    private weak var target: Target?
    private let handler: (Target, E) -> Bool
    
    init(target: Target, handler: @escaping @MainActor (Target, E) -> Bool) {
        self.target = target
        self.handler = handler
    }
    
    func canReceive(_ event: E, sender: Any?) -> Bool {
        guard let target = target else { return false }
        return handler(target, event)
    }
}

@MainActor
final class SenderClosureRouteReceiver<E>: RouteReceiving {
    typealias Event = E
    private let handler: (E, UIResponder?) -> Bool
    
    init(handler: @escaping @MainActor (E, UIResponder?) -> Bool) {
        self.handler = handler
    }
    
    func canReceive(_ event: E, sender: Any?) -> Bool {
        return handler(event, sender as? UIResponder)
    }
}

@MainActor
final class TargetedSenderClosureRouteReceiver<E, Target: AnyObject>: RouteReceiving {
    typealias Event = E
    private weak var target: Target?
    private let handler: (Target, E, UIResponder?) -> Bool
    
    init(target: Target, handler: @escaping @MainActor (Target, E, UIResponder?) -> Bool) {
        self.target = target
        self.handler = handler
    }
    
    func canReceive(_ event: E, sender: Any?) -> Bool {
        guard let target = target else { return false }
        return handler(target, event, sender as? UIResponder)
    }
}
