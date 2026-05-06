import Foundation

/// Hierarchical cancellation scope for runtime-managed tasks.
///
/// `FeatureRuntime` registers every managed effect/debounce task with a scope.
/// Shutting down a parent scope cascades cancellation to all descendants.
public actor RuntimeScope {
    public let id: UUID
    public let parentID: UUID?

    private var cancellables: [UUID: @Sendable () -> Void] = [:]
    private var children: [UUID: RuntimeScope] = [:]
    private var isShutDown = false
    private var parent: RuntimeScope?

    public init(id: UUID = UUID(), parentID: UUID? = nil, parent: RuntimeScope? = nil) {
        self.id = id
        self.parentID = parentID
        self.parent = parent
    }

    /// Creates a root scope for a feature tree.
    public static func root() -> RuntimeScope {
        RuntimeScope()
    }

    /// Creates and registers a child scope.
    ///
    /// If parent has already shut down, the child is shut down immediately.
    public func makeChild() -> RuntimeScope {
        let child = RuntimeScope(parentID: id, parent: self)
        children[child.id] = child

        if isShutDown {
            Task {
                await child.shutdown()
            }
        }

        return child
    }

    /// Removes a child scope from this scope's children dictionary.
    public func removeChild(id: UUID) {
        children[id] = nil
    }

    /// Registers a cancellation closure under a token.
    ///
    /// If scope is already terminated, cancellation is executed immediately.
    @discardableResult
    public func register(token: UUID = UUID(), cancel: @escaping @Sendable () -> Void) -> UUID {
        if isShutDown {
            cancel()
            return token
        }

        cancellables[token] = cancel
        return token
    }

    /// Removes token without cancellation.
    public func unregister(token: UUID) {
        cancellables[token] = nil
    }

    /// Cancels and removes token if it exists.
    public func cancel(token: UUID) {
        guard let cancel = cancellables.removeValue(forKey: token) else {
            return
        }
        cancel()
    }

    /// Cancels all registered tasks and recursively shuts down children.
    public func shutdown() async {
        guard !isShutDown else {
            return
        }

        isShutDown = true

        // Remove self from parent's children to prevent leak.
        let parentRef = parent
        parent = nil
        await parentRef?.removeChild(id: self.id)

        let cancelHandlers = Array(cancellables.values)
        cancellables.removeAll(keepingCapacity: false)
        cancelHandlers.forEach { $0() }

        let childScopes = Array(children.values)
        children.removeAll(keepingCapacity: false)

        for child in childScopes {
            await child.shutdown()
        }
    }

    /// True after scope has been shut down.
    public func terminated() -> Bool {
        isShutDown
    }

    /// Number of currently registered child scopes (internal for testing).
    func childCount() -> Int {
        children.count
    }
}
