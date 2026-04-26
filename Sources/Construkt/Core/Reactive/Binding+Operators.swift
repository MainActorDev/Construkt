//
//  Binding+Operators.swift
//  Construkt
//
//  Created for Construkt core.
//

import Foundation

/// A type-erased `ViewBinding` used for returning dynamic functional compositions (like map).
public struct AnyViewBinding<T>: ViewBinding {
    public typealias Value = T
    private let _observe: (DispatchQueue?, @escaping (T) -> Void) -> AnyCancellableLifecycle
    
    public init(_ observe: @escaping (DispatchQueue?, @escaping (T) -> Void) -> AnyCancellableLifecycle) {
        self._observe = observe
    }
    
    public func observe(on queue: DispatchQueue?, _ handler: @escaping (T) -> Void) -> AnyCancellableLifecycle {
        return _observe(queue, handler)
    }
    
    /// Creates a binding that immediately emits a constant value to every observer.
    public static func just(_ value: T) -> AnyViewBinding<T> {
        AnyViewBinding<T> { _, handler in
            handler(value)
            return EmptyCancellable()
        }
    }
    
    /// Combines two bindings, emitting the latest values from each whenever either changes.
    public static func combineLatest<A: ViewBinding, B: ViewBinding>(
        _ a: A, _ b: B
    ) -> AnyViewBinding<(A.Value, B.Value)> where T == (A.Value, B.Value) {
        AnyViewBinding<(A.Value, B.Value)> { queue, handler in
            let lock = NSLock()
            var latestA: A.Value?
            var latestB: B.Value?
            
            let tokenA = a.observe(on: queue) { aVal in
                lock.lock()
                latestA = aVal
                let b = latestB
                lock.unlock()
                if let b = b { handler((aVal, b)) }
            }
            let tokenB = b.observe(on: queue) { bVal in
                lock.lock()
                latestB = bVal
                let a = latestA
                lock.unlock()
                if let a = a { handler((a, bVal)) }
            }
            
            return CompoundCancellable([tokenA, tokenB])
        }
    }
}

/// Combines an array of bindings of arrays, emitting a flattened array whenever any source changes.
public func combineLatestBindings<U>(_ bindings: [AnyViewBinding<[U]>]) -> AnyViewBinding<[U]> {
    guard !bindings.isEmpty else { return .just([]) }
    if bindings.count == 1 { return bindings[0] }
    
    return AnyViewBinding<[U]> { queue, handler in
        let lock = NSLock()
        var latestValues: [[U]?] = Array(repeating: nil, count: bindings.count)
        var tokens: [AnyCancellableLifecycle] = []
        
        for (index, binding) in bindings.enumerated() {
            let token = binding.observe(on: queue) { value in
                lock.lock()
                latestValues[index] = value
                let allReady = latestValues.allSatisfy { $0 != nil }
                let combined: [[U]]? = allReady ? latestValues.compactMap { $0 } : nil
                lock.unlock()
                
                if let combined = combined {
                    handler(combined.flatMap { $0 })
                }
            }
            tokens.append(token)
        }
        
        return CompoundCancellable(tokens)
    }
}

/// An empty cancellable that does nothing — used by `.just()`.
private struct EmptyCancellable: AnyCancellableLifecycle {
    func cancel() {}
}

/// Groups multiple cancellables into one lifecycle token.
private final class CompoundCancellable: AnyCancellableLifecycle {
    private let tokens: [AnyCancellableLifecycle]
    init(_ tokens: [AnyCancellableLifecycle]) { self.tokens = tokens }
    func cancel() { tokens.forEach { $0.cancel() } }
}

public extension ViewBinding {
    
    /// Transforms the emitted values using the provided closure.
    @_disfavoredOverload
    func map<U>(_ transform: @escaping (Value) -> U) -> AnyViewBinding<U> {
        return AnyViewBinding<U> { queue, handler in
            return self.observe(on: queue) { value in
                handler(transform(value))
            }
        }
    }
    
    /// Transforms and filters emitted values, only forwarding non-nil results.
    @_disfavoredOverload
    func compactMap<U>(_ transform: @escaping (Value) -> U?) -> AnyViewBinding<U> {
        return AnyViewBinding<U> { queue, handler in
            return self.observe(on: queue) { value in
                if let transformed = transform(value) {
                    handler(transformed)
                }
            }
        }
    }
    
    /// Bypasses the queue switching of this binding for observation logic.
    func receive(on queue: DispatchQueue?) -> AnyViewBinding<Value> {
        return AnyViewBinding<Value> { _, handler in
            return self.observe(on: queue, handler)
        }
    }
    
    
    /// Only forwards values matching the given predicate.
    @_disfavoredOverload
    func filter(_ predicate: @escaping (Value) -> Bool) -> AnyViewBinding<Value> {
        return AnyViewBinding<Value> { queue, handler in
            return self.observe(on: queue) { value in
                if predicate(value) {
                    handler(value)
                }
            }
        }
    }
    
    /// Accumulates values using the provided closure, emitting the running result.
    @_disfavoredOverload
    func scan<Result>(_ initial: Result, _ accumulator: @escaping (Result, Value) -> Result) -> AnyViewBinding<Result> {
        return AnyViewBinding<Result> { queue, handler in
            let lock = NSLock()
            var accumulated = initial
            
            return self.observe(on: queue) { value in
                lock.lock()
                accumulated = accumulator(accumulated, value)
                let current = accumulated
                lock.unlock()
                handler(current)
            }
        }
    }
    
    /// Skips the first `count` values, forwarding only subsequent ones.
    @_disfavoredOverload
    func skip(_ count: Int) -> AnyViewBinding<Value> {
        return AnyViewBinding<Value> { queue, handler in
            let lock = NSLock()
            var skipped = 0
            
            return self.observe(on: queue) { value in
                lock.lock()
                let shouldSkip = skipped < count
                if shouldSkip { skipped += 1 }
                lock.unlock()
                
                if !shouldSkip {
                    handler(value)
                }
            }
        }
    }
    
    /// Waits until values stop arriving for the specified duration before forwarding the latest.
    @_disfavoredOverload
    func debounce(for interval: TimeInterval, on scheduler: DispatchQueue = .main) -> AnyViewBinding<Value> {
        return AnyViewBinding<Value> { queue, handler in
            let lock = NSLock()
            var workItem: DispatchWorkItem?
            
            return self.observe(on: nil) { value in
                lock.lock()
                workItem?.cancel()
                let item = DispatchWorkItem {
                    if let targetQueue = queue {
                        targetQueue.async { handler(value) }
                    } else {
                        handler(value)
                    }
                }
                workItem = item
                lock.unlock()
                scheduler.asyncAfter(deadline: .now() + interval, execute: item)
            }
        }
    }
    
    /// Rate-limits emissions to at most one per interval.
    /// - Parameter latest: If `true`, emits the most recent value at the end of each window.
    ///   If `false`, emits the first value and suppresses the rest until the window expires.
    @_disfavoredOverload
    func throttle(for interval: TimeInterval, latest: Bool = true, on scheduler: DispatchQueue = .main) -> AnyViewBinding<Value> {
        return AnyViewBinding<Value> { queue, handler in
            let lock = NSLock()
            var lastEmitTime: Date = .distantPast
            var pendingValue: Value?
            var pendingWorkItem: DispatchWorkItem?
            
            return self.observe(on: nil) { value in
                let now = Date()
                lock.lock()
                let elapsed = now.timeIntervalSince(lastEmitTime)
                
                if elapsed >= interval {
                    // Window expired — emit immediately
                    lastEmitTime = now
                    pendingWorkItem?.cancel()
                    pendingWorkItem = nil
                    pendingValue = nil
                    lock.unlock()
                    
                    if let targetQueue = queue {
                        targetQueue.async { handler(value) }
                    } else {
                        handler(value)
                    }
                } else if latest {
                    // Within window — schedule the latest value at window end
                    pendingValue = value
                    if pendingWorkItem == nil {
                        let remaining = interval - elapsed
                        let item = DispatchWorkItem { [weak lock] in
                            guard let lock = lock else { return }
                            lock.lock()
                            let val = pendingValue
                            pendingValue = nil
                            pendingWorkItem = nil
                            lastEmitTime = Date()
                            lock.unlock()
                            
                            if let val = val {
                                if let targetQueue = queue {
                                    targetQueue.async { handler(val) }
                                } else {
                                    handler(val)
                                }
                            }
                        }
                        pendingWorkItem = item
                        lock.unlock()
                        scheduler.asyncAfter(deadline: .now() + remaining, execute: item)
                    } else {
                        lock.unlock()
                    }
                } else {
                    // Not latest mode — just drop
                    lock.unlock()
                }
            }
        }
    }
    
    /// Delays each emitted value by the specified time interval before forwarding it.
    @_disfavoredOverload
    func delay(_ interval: TimeInterval, on queue: DispatchQueue = .main) -> AnyViewBinding<Value> {
        return AnyViewBinding { queue, handler in
            self.observe(on: queue) { value in
                queue?.asyncAfter(deadline: .now() + interval) {
                    handler(value)
                }
            }
        }
    }
    
    /// Transforms each value into a new binding and only observes the latest one, cancelling previous subscriptions.
    @_disfavoredOverload
    func flatMapLatest<T>(_ transform: @escaping (Value) -> AnyViewBinding<T>) -> AnyViewBinding<T> {
        return AnyViewBinding<T> { queue, handler in
            var innerCancellable: AnyCancellableLifecycle?
            return self.observe(on: queue) { value in
                innerCancellable?.cancel()
                let inner = transform(value)
                innerCancellable = inner.observe(on: queue) { innerValue in
                    handler(innerValue)
                }
            }
        }
    }
    
    /// Merges emissions from this binding and another binding of the same type into a single stream.
    @_disfavoredOverload
    func merge<B: ViewBinding>(with other: B) -> AnyViewBinding<Value> where B.Value == Value {
        return AnyViewBinding<Value> { queue, handler in
            let tokenA = self.observe(on: queue, handler)
            let tokenB = other.observe(on: queue, handler)
            return CompoundCancellable([tokenA, tokenB])
        }
    }
    
    /// Filters out consecutive duplicate values using a custom comparator.
    func removeDuplicates(by predicate: @escaping (Value, Value) -> Bool) -> AnyViewBinding<Value> {
        return AnyViewBinding<Value> { queue, handler in
            let lock = NSLock()
            var lastValue: Value?
            
            return self.observe(on: queue) { value in
                lock.lock()
                let isDuplicate: Bool
                if let last = lastValue {
                    isDuplicate = predicate(last, value)
                } else {
                    isDuplicate = false
                }
                if !isDuplicate {
                    lastValue = value
                }
                lock.unlock()
                
                if !isDuplicate {
                    handler(value)
                }
            }
        }
    }
}

public extension ViewBinding where Value: Equatable {
    
    /// Filters out consecutive duplicate values from being emitted.
    @_disfavoredOverload
    func distinctUntilChanged() -> AnyViewBinding<Value> {
        return removeDuplicates(by: ==)
    }
    
}

public extension ViewBinding {
    
    /// Wraps any concrete `ViewBinding` into a type-erased `AnyViewBinding`.
    func eraseToAnyViewBinding() -> AnyViewBinding<Value> {
        AnyViewBinding { queue, handler in
            self.observe(on: queue, handler)
        }
    }
    
}
