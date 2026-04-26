//
//  RouteChannel.swift
//  Construkt
//

import UIKit

/// A type-safe, 1:N broadcast channel for delivering route events across view controller boundaries.
///
/// `RouteChannel` solves the problem of communicating events from a modally presented screen
/// (e.g. a bottom sheet) back to its presenting screen, where the UIKit responder chain cannot bridge
/// across separate presentation contexts.
///
/// **Usage:**
/// ```swift
/// // 1. Coordinator creates the channel
/// let channel = RouteChannel<SheetEvent>()
///
/// // 2. Presenting screen subscribes
/// let homeScreen = HomeView()
///     .onReceiveChannel(channel) { event, sender in
///         sender?.route(SomeRoute.detail(id), sender: sender)
///         return true
///     }
///
/// // 3. Presented screen sends events
/// channel.send(.didSelectItem(item), sender: self.view)
/// ```
///
/// Listeners are stored with weak ownership semantics and automatically cleaned up on send.
@MainActor
public final class RouteChannel<Event> {
    private var listeners: [ChannelListener<Event>] = []
    
    /// A shared singleton channel for the given `Event` type.
    ///
    /// Use this when screens need to communicate via the same event type
    /// without sharing the same channel instance explicitly.
    /// ```swift
    /// // Subscribe
    /// .onReceiveChannel(RouteChannel<SheetEvent>.shared) { event, sender in ... }
    ///
    /// // Send from anywhere
    /// RouteChannel<SheetEvent>.shared.send(.didSelectItem(item), sender: view)
    /// ```
    nonisolated public static var shared: RouteChannel<Event> {
        let resolve: @MainActor () -> RouteChannel<Event> = {
            let key = ObjectIdentifier(Event.self)
            if let existing = SharedChannelRegistry.channels[key] as? RouteChannel<Event> {
                return existing
            }
            let channel = RouteChannel<Event>()
            SharedChannelRegistry.channels[key] = channel
            return channel
        }
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                resolve()
            }
        } else {
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    resolve()
                }
            }
        }
    }

    public init() {}

    /// Send an event to all active listeners.
    /// - Parameters:
    ///   - event: The event payload to broadcast.
    ///   - sender: The responder that triggered the event (e.g. a view or view controller).
    ///             Listeners can use this to perform responder-chain routing via `sender.route(...)`.
    /// - Returns: `true` if at least one listener handled the event.
    @discardableResult
    public func send(_ event: Event, sender: UIResponder? = nil) -> Bool {
        // Purge stale (deallocated owner) listeners
        listeners.removeAll { !$0.isAlive }

        var handled = false
        for listener in listeners {
            if listener.handle(event, sender: sender) { handled = true }
        }
        return handled
    }

    /// Subscribe a handler to this channel.
    /// The handler is kept alive as long as the `owner` is alive.
    internal func subscribe<Owner: AnyObject>(owner: Owner, handler: @escaping @MainActor (Event, UIResponder?) -> Bool) {
        listeners.removeAll { !$0.isAlive }
        listeners.append(ChannelListener(owner: owner, handler: handler))
    }
}

/// An internal wrapper that weakly references the owner to provide automatic cleanup.
@MainActor
private final class ChannelListener<Event> {
    private weak var owner: AnyObject?
    private let handler: (Event, UIResponder?) -> Bool

    init<Owner: AnyObject>(owner: Owner, handler: @escaping @MainActor (Event, UIResponder?) -> Bool) {
        self.owner = owner
        self.handler = handler
    }

    var isAlive: Bool { owner != nil }

    func handle(_ event: Event, sender: UIResponder?) -> Bool {
        guard owner != nil else { return false }
        return handler(event, sender)
    }
}

// MARK: - Shared Channel Registry

/// Global storage for shared `RouteChannel` instances, keyed by event type.
@MainActor
private enum SharedChannelRegistry {
    static var channels: [ObjectIdentifier: AnyObject] = [:]
}
