import Foundation
import ConstruktKit

/// A protocol that allows LoadableState properties to be accessed homogeneously, enabling direct `ViewBinding` property bridging.
public protocol LoadableStateProtocol {
    associatedtype StateType: Equatable & Sendable
    var isLoading: Bool { get }
    var loadedValue: StateType? { get }
    var error: String? { get }
}

/// A generic state enum for loading data.
/// Automatically handles "production grade" features like Stable Cache Keys and Smart Updates.
public enum LoadableState<T: Equatable & Sendable>: Equatable, Sendable, EquivalentState, CacheKeyProviding, LoadableStateProtocol {
    case initial
    case loading
    case loaded(T)
    case empty(String)
    case error(String)
    
    // MARK: - CacheKeyProviding
    /// Stable key for caching views. Ignores the associated data in .loaded case.
    public var cacheKey: String {
        switch self {
        case .initial: return "initial"
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .empty: return "empty"
        case .error: return "error"
        }
    }
    
    // MARK: - EquivalentState
    /// Smart check to determine if we should Swap (Rebuild) or Update (Reload)
    public func isModification(of previous: Any) -> Bool {
        guard let previous = previous as? LoadableState<T> else { return false }
        
        switch (self, previous) {
        // If we are already loaded and get new data, it's just an update!
        // This preserves scroll position/focus in the active view.
        case (.loaded, .loaded): return true
        default: return false
        }
    }
    
    // MARK: - Helpers
    
    public var isLoading: Bool {
        switch self {
        case .loading, .initial: return true
        default: return false
        }
    }
    
    public var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    public var loadedValue: T? {
        return value
    }
    
    public var error: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}

// MARK: - Hashable Conformance
extension LoadableState: Hashable where T: Hashable {}
