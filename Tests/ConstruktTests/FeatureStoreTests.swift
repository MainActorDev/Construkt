import Foundation
import Testing
@testable import ConstruktKit

/// Integration tests for the runtime-to-reactive bridge exposed by `FeatureStore`.
@Suite("FeatureStore", .serialized)
struct FeatureStoreTests {

    @Test("Store state property mirrors runtime updates")
    func statePropertyMirrorsRuntime() async {
        let store = makeStore()

        await store.sendAndWait(.increment)

        let didUpdate = await waitUntil {
            store.state.wrappedValue.counter == 1
        }

        #expect(didUpdate)
    }

    @Test("Store outputs signal mirrors runtime outputs")
    func outputsSignalMirrorsRuntime() async {
        let store = makeStore()
        let captured = LockedArray<String>()

        let token = store.observeOutputs(on: nil) { output in
            if case .message(let value) = output {
                captured.append(value)
            }
        }

        await store.sendAndWait(.emitOutput("hello"))

        let didReceive = await waitUntil {
            captured.snapshot() == ["hello"]
        }

        token.cancel()
        #expect(didReceive)
    }

    @Test("Dispatch works without awaiting")
    func fireAndForgetDispatch() async {
        let store = makeStore()

        store.dispatch(.increment)

        let didUpdate = await waitUntil {
            store.state.wrappedValue.counter == 1
        }

        #expect(didUpdate)
    }

    @Test("Shutdown prevents further intent processing")
    func shutdownPreventsFurtherIntents() async {
        let store = makeStore()
        await store.shutdown()

        await store.sendAndWait(.increment)
        store.dispatch(.increment)
        try? await Task.sleep(nanoseconds: 40_000_000)

        #expect(store.state.wrappedValue.counter == 0)
    }

    @Test("sendAndDrain waits for asynchronous effect completion")
    func sendAndDrainWaitsForEffects() async {
        let store = makeStore()

        await store.sendAndDrain(.triggerAsyncIncrement(delayNanos: 40_000_000))

        #expect(store.state.wrappedValue.counter == 1)
    }

    @Test("Dispatch intents are processed before subsequent awaited sends")
    func dispatchOrderingIsStable() async {
        let store = makeStore()

        store.dispatch(.increment)
        await store.sendAndDrain(.triggerAsyncIncrement(delayNanos: 20_000_000))

        #expect(store.state.wrappedValue.counter == 2)
    }

    private func makeStore() -> FeatureStore<FeatureStoreTestFeature> {
        FeatureStore(dependencies: .init()) { effect, _ in
            switch effect {
            case .none:
                return .none
            case .delayedIncrement(let delayNanos):
                try await Task.sleep(nanoseconds: delayNanos)
                return .init(intents: [.applyAsyncIncrement])
            }
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }

            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }

        return condition()
    }
}

private final class LockedArray<T> {
    private let lock = NSLock()
    private var values: [T] = []

    func append(_ value: T) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [T] {
        lock.lock()
        let snapshot = values
        lock.unlock()
        return snapshot
    }
}

private struct FeatureStoreTestFeature: FeatureSpec {
    struct State: Equatable, Sendable {
        var counter = 0
    }

    enum Intent: Sendable {
        case increment
        case emitOutput(String)
        case triggerAsyncIncrement(delayNanos: UInt64)
        case applyAsyncIncrement
    }

    enum Effect: Hashable, Sendable {
        case none
        case delayedIncrement(delayNanos: UInt64)
    }

    enum Output: Sendable {
        case message(String)
    }

    struct Dependencies: Sendable {}

    static var initialState: State {
        .init()
    }

    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .increment:
            state.counter += 1
            return .none
        case .emitOutput(let value):
            return .init(outputs: [.message(value)])
        case .triggerAsyncIncrement(let delayNanos):
            return .init(effects: [.delayedIncrement(delayNanos: delayNanos)])
        case .applyAsyncIncrement:
            state.counter += 1
            return .none
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        .concurrent
    }
}
