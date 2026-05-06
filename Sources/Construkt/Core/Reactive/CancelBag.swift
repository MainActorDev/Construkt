//
//  CancelBag.swift
//  Construkt
//
//  Created for Construkt core.
//

import Foundation

/// A container that retains `AnyCancellableLifecycle` tokens and automatically cancels them
/// when the bag itself is deallocated.
public final class CancelBag {
    private var cancellables: [AnyCancellableLifecycle] = []
    private let lock = NSLock()
    
    public init() {}
    
    /// Adds a cancellable token to the bag, retaining it until the bag is cancelled or deallocated.
    public func insert(_ cancellable: AnyCancellableLifecycle) {
        lock.lock()
        defer { lock.unlock() }
        cancellables.append(cancellable)
    }
    
    /// Cancels all stored tokens and empties the bag.
    public func cancel() {
        lock.lock()
        let items = cancellables
        cancellables.removeAll()
        lock.unlock()
        
        for item in items {
            item.cancel()
        }
    }
    
    deinit {
        cancel()
    }
}

public extension AnyCancellableLifecycle {
    /// Stores the lifecycle token in the provided `CancelBag`.
    func store(in bag: CancelBag) {
        bag.insert(self)
    }
}

public extension NSObject {
    fileprivate static var ViewBindingCancelBagKey: UInt8 = 0
    fileprivate static let cancelBagInitLock = NSLock()
    
    /// Returns a generic `CancelBag` stored dynamically on the `NSObject` class via the Objective-C runtime.
    /// This is the native, zero-dependency alternative to `rxDisposeBag`.
    var cancelBag: CancelBag {
        NSObject.cancelBagInitLock.lock()
        defer { NSObject.cancelBagInitLock.unlock() }
        
        if let bag = objc_getAssociatedObject(self, &NSObject.ViewBindingCancelBagKey) as? CancelBag {
            return bag
        }
        let bag = CancelBag()
        objc_setAssociatedObject(self, &NSObject.ViewBindingCancelBagKey, bag, .OBJC_ASSOCIATION_RETAIN)
        return bag
    }
}
