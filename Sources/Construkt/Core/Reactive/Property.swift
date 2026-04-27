//
//  Property.swift
//  Construkt
//
//  Created for Construkt core.
//

import Foundation

/// A lightweight, generic, thread-safe value box that broadcasts changes to its observers.
/// Serves as the native, zero-dependency alternative to `BehaviorRelay` or `@Published`.
public final class Property<T>: MutableViewBinding {
    public typealias Value = T
    
    private var _value: T
    private var observers: [UUID: Observer] = [:]
    private let lock = NSRecursiveLock()
    
    private struct Observer {
        let queue: DispatchQueue?
        let handler: (T) -> Void
    }
    
    /// The current value. Setting this property synchronously broadcasts the new value to all active observers.
    public var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            _value = newValue
            let currentObservers = observers.values
            lock.unlock()
            
            for observer in currentObservers {
                if let queue = observer.queue {
                    // Fast path: If we are already on the main thread and target is main, execute immediately
                    if queue == .main && Thread.isMainThread {
                        observer.handler(newValue)
                    } else {
                        queue.async { observer.handler(newValue) }
                    }
                } else {
                    observer.handler(newValue)
                }
            }
        }
    }
    
    /// Creates a new property with the given initial value.
    public init(_ value: T) {
        self._value = value
    }
    
    /// Subscribes to value changes, immediately emitting the current value to the new observer.
    public func observe(on queue: DispatchQueue? = .main, _ handler: @escaping (T) -> Void) -> AnyCancellableLifecycle {
        lock.lock()
        defer { lock.unlock() }
        
        let id = UUID()
        observers[id] = Observer(queue: queue, handler: handler)
        
        // Broadcast the initial value immediately upon observation
        let currentValue = _value
        if let queue = queue {
            if queue == .main && Thread.isMainThread {
                handler(currentValue)
            } else {
                queue.async { handler(currentValue) }
            }
        } else {
            handler(currentValue)
        }
        
        return PropertyCancellable { [weak self] in
            self?.removeObserver(id: id)
        }
    }
    
    private func removeObserver(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeValue(forKey: id)
    }
    
}

/// Internal lifecycle token for `Property` observations.
private final class PropertyCancellable: AnyCancellableLifecycle {
    private var onCancel: (() -> Void)?
    private let lock = NSLock()
    
    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }
    
    func cancel() {
        lock.lock()
        let action = onCancel
        onCancel = nil
        lock.unlock()
        action?()
    }
    
    deinit {
        cancel()
    }
}
