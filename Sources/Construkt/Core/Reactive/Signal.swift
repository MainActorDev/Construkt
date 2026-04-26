//
//  Signal.swift
//  Construkt
//
//  Created for Construkt core.
//

import Foundation

/// A lightweight, generic, thread-safe event broadcaster.
/// Unlike `Property`, it does not store a state value; it only pushes events to active observers when `send()` is called.
/// Serves as the native, zero-dependency alternative to `PublishRelay` or `PassthroughSubject`.
public final class Signal<T>: ViewBinding {
    public typealias Value = T
    
    private var observers: [UUID: Observer] = [:]
    private let lock = NSRecursiveLock()
    
    private struct Observer {
        let queue: DispatchQueue?
        let handler: (T) -> Void
    }
    
    public init() {}
    
    /// Sends a new value to all active observers.
    public func send(_ value: T) {
        lock.lock()
        let currentObservers = observers.values
        lock.unlock()
        
        for observer in currentObservers {
            if let queue = observer.queue {
                if queue == .main && Thread.isMainThread {
                    observer.handler(value)
                } else {
                    queue.async { observer.handler(value) }
                }
            } else {
                observer.handler(value)
            }
        }
    }
    
    /// Subscribes to future events. Unlike `Property`, no initial value is emitted.
    public func observe(on queue: DispatchQueue? = .main, _ handler: @escaping (T) -> Void) -> AnyCancellableLifecycle {
        lock.lock()
        defer { lock.unlock() }
        
        let id = UUID()
        observers[id] = Observer(queue: queue, handler: handler)
        
        // Note: Signal does not broadcast any initial state to new observers.
        
        return SignalCancellable { [weak self] in
            self?.removeObserver(id: id)
        }
    }
    
    private func removeObserver(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        observers.removeValue(forKey: id)
    }
}

/// Internal lifecycle token for `Signal` observations.
private final class SignalCancellable: AnyCancellableLifecycle {
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
