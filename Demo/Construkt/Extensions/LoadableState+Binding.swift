import Foundation
import ConstruktKit

// MARK: - Protocol-Oriented Property Bridging

public extension ViewBinding where Value: LoadableStateProtocol {
    
    /// Projects the `isLoading` state directly as a boolean binding.
    var isLoading: AnyViewBinding<Bool> {
        return map { $0.isLoading }
    }
    
    /// Projects the `loadedValue` directly as an optional binding.
    var loadedValue: AnyViewBinding<Value.StateType?> {
        return map { $0.loadedValue }
    }
    
    /// Projects the `error` message directly as an optional string binding.
    var error: AnyViewBinding<String?> {
        return map { $0.error }
    }
}

// MARK: - LoadableState ViewBinding Operators

public extension ViewBinding {
    
    /// Maps a `LoadableState<[T]>` binding to emit only the loaded items `[T]`.
    /// Emits an empty array when not in `.loaded` state.
    func mapItems<T: Equatable & Sendable>() -> AnyViewBinding<[T]> where Value == LoadableState<[T]> {
        return map { state in
            if case .loaded(let items) = state { return items }
            return []
        }
    }
    
    /// Maps a `LoadableState<T>` binding to emit only the loaded value `T?`.
    /// Emits `nil` when not in `.loaded` state.
    func mapValue<T: Equatable & Sendable>() -> AnyViewBinding<T?> where Value == LoadableState<T> {
        return map { state in
            if case .loaded(let item) = state { return item }
            return nil
        }
    }

    /// Maps a `LoadableState<T>` binding to a Boolean indicating loading state.
    /// Returns `true` for `.initial` and `.loading`, `false` otherwise.
    func mapLoading<T: Equatable & Sendable>() -> AnyViewBinding<Bool> where Value == LoadableState<T> {
        return map { state in
            if case .initial = state { return true }
            if case .loading = state { return true }
            return false
        }
    }
}
