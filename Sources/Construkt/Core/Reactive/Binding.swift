//
//  Binding.swift
//  Construkt
//
//  Created for Construkt core.
//

import Foundation

/// Defines a lifecycle token for an active reactive binding.
/// When this token is deallocated (or explicitly canceled), the binding stops broadcasting to the tied observer.
public protocol AnyCancellableLifecycle {
    func cancel()
}

/// The fundamental protocol for agnostic reactive data flows in Construkt.
/// Allows components to observe structural property changes without forcing a dependency 
/// on heavy external frameworks like Combine.
public protocol ViewBinding {
    associatedtype Value
    
    /// Binds an observer to this reactive sequence.
    ///
    /// - Parameters:
    ///   - on: The optional `DispatchQueue` to ensure the handler fires on. Defaults to `DispatchQueue.main`.
    ///   - handler: The closure executed whenever the bound value updates.
    /// - Returns: A lifecycle token. You must retain this token (e.g., inside a view's `cancelBag`) to keep the binding alive.
    func observe(on queue: DispatchQueue?, _ handler: @escaping (Value) -> Void) -> AnyCancellableLifecycle
}

/// A reactive binding that also supports mutation, enabling two-way data flow (e.g. TextFields, Switches).
public protocol MutableViewBinding: ViewBinding {
    /// The modifiable current value of this binding. Setting it usually broadcasts the new value.
    var wrappedValue: Value { get set }
}

public extension ViewBinding {
    /// Convenience override defaulting to `DispatchQueue.main`.
    func observe(_ handler: @escaping (Value) -> Void) -> AnyCancellableLifecycle {
        return observe(on: .main, handler)
    }
}
