import Foundation
import Testing
@testable import ConstruktKit

/// End-to-end runtime tests that validate policy semantics and lifecycle guarantees.
@Suite("FeatureRuntime", .serialized)
struct FeatureRuntimeTests {

    @Test("Serialized intent processing keeps deterministic state")
    func deterministicStateUpdates() async {
        let runtime = makeRuntime()

        await runtime.send(.increment)
        await runtime.send(.increment)

        let state = await runtime.currentState()
        #expect(state.counter == 2)
    }

    @Test("Latest policy keeps only most recent completion")
    func latestPolicyDropsSupersededCompletion() async {
        let runtime = makeRuntime()

        await runtime.send(.triggerLatest(value: 1, delayNanos: 200_000_000))
        await sleep(25_000_000)
        await runtime.send(.triggerLatest(value: 2, delayNanos: 20_000_000))

        await sleep(260_000_000)

        let state = await runtime.currentState()
        #expect(state.latestValue == 2)
    }

    @Test("Queue policy executes effects sequentially")
    func queuePolicyExecutesInOrder() async {
        let probe = EffectProbe()
        let runtime = makeRuntime(probe: probe)

        await runtime.send(.triggerQueue(label: "A", delayNanos: 120_000_000))
        await runtime.send(.triggerQueue(label: "B", delayNanos: 10_000_000))

        await sleep(220_000_000)

        let state = await runtime.currentState()
        let started = await probe.queueStarts()

        #expect(started == ["A", "B"])
        #expect(state.queueValues == ["A", "B"])
    }

    @Test("Drop policy ignores new effect while key is running")
    func dropPolicySkipsOverlappingEffect() async {
        let probe = EffectProbe()
        let runtime = makeRuntime(probe: probe)

        await runtime.send(.triggerDrop(label: "first", delayNanos: 120_000_000))
        await sleep(15_000_000)
        await runtime.send(.triggerDrop(label: "second", delayNanos: 10_000_000))

        await sleep(200_000_000)

        let state = await runtime.currentState()
        let started = await probe.dropStarts()

        #expect(started == ["first"])
        #expect(state.dropValues == ["first"])
    }

    @Test("Restartable policy cancels previous running effect")
    func restartablePolicyCancelsPreviousEffect() async {
        let probe = EffectProbe()
        let runtime = makeRuntime(probe: probe)

        await runtime.send(.triggerRestartable(label: "first", delayNanos: 180_000_000))
        await sleep(20_000_000)
        await runtime.send(.triggerRestartable(label: "second", delayNanos: 20_000_000))

        await sleep(240_000_000)

        let state = await runtime.currentState()
        let started = await probe.restartStarts()
        let cancelled = await probe.restartCancelledIDs()

        #expect(started == ["first", "second"])
        #expect(cancelled == ["first"])
        #expect(state.restartValues == ["second"])
    }

    @Test("Debounce policy only executes the latest intent")
    func debouncePolicyKeepsLatestValue() async {
        let probe = EffectProbe()
        let runtime = makeRuntime(probe: probe)

        await runtime.send(.triggerDebounce(label: "first", interval: 0.08))
        await sleep(10_000_000)
        await runtime.send(.triggerDebounce(label: "second", interval: 0.08))

        await sleep(180_000_000)

        let state = await runtime.currentState()
        let fired = await probe.debounceFires()

        #expect(fired == ["second"])
        #expect(state.debounceValues == ["second"])
    }

    @Test("Stale epoch guard prevents out-of-date completion writes")
    func staleEpochGuardDropsOutdatedCompletion() async {
        let runtime = makeRuntime()

        await runtime.send(.triggerStale(value: 7, delayNanos: 100_000_000))
        await sleep(20_000_000)
        await runtime.send(.increment)

        await sleep(140_000_000)

        let state = await runtime.currentState()
        #expect(state.staleValue == nil)
    }

    @Test("Parent scope shutdown cancels child runtime effects")
    func shutdownCascadesToChildScope() async {
        let probe = EffectProbe()
        let parent = RuntimeScope.root()
        let child = await parent.makeChild()
        let runtime = makeRuntime(probe: probe, scope: child)

        await runtime.send(.triggerLongRunning(id: "job-1"))
        await sleep(30_000_000)
        await parent.shutdown()
        await sleep(30_000_000)

        let cancelled = await probe.cancelledIDs()
        #expect(cancelled == ["job-1"])
    }

    @Test("Mapped errors are routed back as typed intents")
    func mappedErrorIntentIsDispatched() async {
        let runtime = makeRuntime()

        await runtime.send(.triggerFailure)
        await sleep(40_000_000)

        let state = await runtime.currentState()
        #expect(state.mappedFailureCount == 1)
    }

    @Test("waitUntilIdle suspends until active effects finish")
    func waitUntilIdleTracksQueueCompletion() async {
        let runtime = makeRuntime()

        await runtime.send(.triggerQueue(label: "A", delayNanos: 80_000_000))
        await runtime.send(.triggerQueue(label: "B", delayNanos: 20_000_000))
        await runtime.waitUntilIdle()

        let state = await runtime.currentState()
        #expect(state.queueValues == ["A", "B"])
    }

    @Test("iOS16 duration debounce convenience maps to interval")
    func durationDebounceConvenience() {
        guard #available(iOS 16.0, *) else {
            return
        }

        let policy = EffectPolicy.debounce("duration-key", for: .milliseconds(125))
        if case .debounce(let key, let interval) = policy {
            #expect(key == "duration-key")
            #expect(abs(interval - 0.125) < 0.000_001)
        } else {
            #expect(false)
        }
    }

    private func makeRuntime(
        probe: EffectProbe = EffectProbe(),
        scope: RuntimeScope = RuntimeScope.root()
    ) -> FeatureRuntime<RuntimeTestFeature> {
        FeatureRuntime(dependencies: .init(probe: probe), scope: scope) { effect, dependencies in
            switch effect {
            case .latest(let value, let delayNanos):
                try await Task.sleep(nanoseconds: delayNanos)
                return .init(intents: [.applyLatest(value)])

            case .queued(let label, let delayNanos):
                await dependencies.probe.recordQueueStart(label)
                try await Task.sleep(nanoseconds: delayNanos)
                return .init(intents: [.applyQueue(label)])

            case .drop(let label, let delayNanos):
                await dependencies.probe.recordDropStart(label)
                try await Task.sleep(nanoseconds: delayNanos)
                return .init(intents: [.applyDrop(label)])

            case .restartable(let label, let delayNanos):
                await dependencies.probe.recordRestartStart(label)
                do {
                    try await Task.sleep(nanoseconds: delayNanos)
                    return .init(intents: [.applyRestartable(label)])
                } catch is CancellationError {
                    await dependencies.probe.recordRestartCancelled(label)
                    throw CancellationError()
                }

            case .debounced(let label, _):
                await dependencies.probe.recordDebounceFire(label)
                return .init(intents: [.applyDebounce(label)])

            case .stale(let value, let delayNanos):
                try await Task.sleep(nanoseconds: delayNanos)
                return .init(intents: [.applyStale(value)])

            case .longRunning(let id):
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    return .none
                } catch is CancellationError {
                    await dependencies.probe.recordCancelled(id)
                    throw CancellationError()
                }

            case .failing:
                throw RuntimeTestError.expected
            }
        }
    }

    private func sleep(_ nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private enum RuntimeTestError: Error {
    case expected
}

private actor EffectProbe {
    private var queueStartOrder: [String] = []
    private var dropStartOrder: [String] = []
    private var restartStartOrder: [String] = []
    private var restartCancelledOrder: [String] = []
    private var debounceFiredOrder: [String] = []
    private var cancelled: [String] = []

    func recordQueueStart(_ value: String) {
        queueStartOrder.append(value)
    }

    func recordDropStart(_ value: String) {
        dropStartOrder.append(value)
    }

    func recordRestartStart(_ value: String) {
        restartStartOrder.append(value)
    }

    func recordRestartCancelled(_ value: String) {
        restartCancelledOrder.append(value)
    }

    func recordDebounceFire(_ value: String) {
        debounceFiredOrder.append(value)
    }

    func recordCancelled(_ id: String) {
        cancelled.append(id)
    }

    func queueStarts() -> [String] {
        queueStartOrder
    }

    func dropStarts() -> [String] {
        dropStartOrder
    }

    func restartStarts() -> [String] {
        restartStartOrder
    }

    func restartCancelledIDs() -> [String] {
        restartCancelledOrder
    }

    func debounceFires() -> [String] {
        debounceFiredOrder
    }

    func cancelledIDs() -> [String] {
        cancelled
    }
}

/// Local feature used to exercise runtime policy behavior deterministically.
private struct RuntimeTestFeature: FeatureSpec {
    struct State: Equatable, Sendable {
        var counter = 0
        var latestValue: Int?
        var queueValues: [String] = []
        var dropValues: [String] = []
        var restartValues: [String] = []
        var debounceValues: [String] = []
        var staleValue: Int?
        var mappedFailureCount = 0
    }

    enum Intent: Sendable {
        case increment
        case triggerLatest(value: Int, delayNanos: UInt64)
        case applyLatest(Int)
        case triggerQueue(label: String, delayNanos: UInt64)
        case applyQueue(String)
        case triggerDrop(label: String, delayNanos: UInt64)
        case applyDrop(String)
        case triggerRestartable(label: String, delayNanos: UInt64)
        case applyRestartable(String)
        case triggerDebounce(label: String, interval: TimeInterval)
        case applyDebounce(String)
        case triggerStale(value: Int, delayNanos: UInt64)
        case applyStale(Int)
        case triggerLongRunning(id: String)
        case triggerFailure
        case mappedFailure
    }

    enum Effect: Hashable, Sendable {
        case latest(value: Int, delayNanos: UInt64)
        case queued(label: String, delayNanos: UInt64)
        case drop(label: String, delayNanos: UInt64)
        case restartable(label: String, delayNanos: UInt64)
        case debounced(label: String, interval: TimeInterval)
        case stale(value: Int, delayNanos: UInt64)
        case longRunning(id: String)
        case failing
    }

    enum Output: Sendable {
        case none
    }

    struct Dependencies: Sendable {
        let probe: EffectProbe
    }

    static var initialState: State {
        .init()
    }

    static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .increment:
            state.counter += 1
            return .none

        case .triggerLatest(let value, let delayNanos):
            return .init(effects: [.latest(value: value, delayNanos: delayNanos)])

        case .applyLatest(let value):
            state.latestValue = value
            return .none

        case .triggerQueue(let label, let delayNanos):
            return .init(effects: [.queued(label: label, delayNanos: delayNanos)])

        case .applyQueue(let label):
            state.queueValues.append(label)
            return .none

        case .triggerDrop(let label, let delayNanos):
            return .init(effects: [.drop(label: label, delayNanos: delayNanos)])

        case .applyDrop(let label):
            state.dropValues.append(label)
            return .none

        case .triggerRestartable(let label, let delayNanos):
            return .init(effects: [.restartable(label: label, delayNanos: delayNanos)])

        case .applyRestartable(let label):
            state.restartValues.append(label)
            return .none

        case .triggerDebounce(let label, let interval):
            return .init(effects: [.debounced(label: label, interval: interval)])

        case .applyDebounce(let label):
            state.debounceValues.append(label)
            return .none

        case .triggerStale(let value, let delayNanos):
            return .init(effects: [.stale(value: value, delayNanos: delayNanos)])

        case .applyStale(let value):
            state.staleValue = value
            return .none

        case .triggerLongRunning(let id):
            return .init(effects: [.longRunning(id: id)])

        case .triggerFailure:
            return .init(effects: [.failing])

        case .mappedFailure:
            state.mappedFailureCount += 1
            return .none
        }
    }

    static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .latest:
            return .latest("latest")
        case .queued:
            return .queue("queue")
        case .drop:
            return .dropIfRunning("drop")
        case .restartable:
            return .restartable("restartable")
        case .debounced(_, let interval):
            return .debounce("debounce", interval)
        case .stale, .longRunning, .failing:
            return .concurrent
        }
    }

    static func staleStrategy(for effect: Effect) -> StaleEffectStrategy {
        switch effect {
        case .queued, .drop, .restartable, .debounced:
            return .accept
        case .latest, .stale, .longRunning, .failing:
            return .drop
        }
    }

    static func mapEffectError(_ error: any Error, effect: Effect) -> Intent? {
        guard case .failing = effect else {
            return nil
        }
        return .mappedFailure
    }
}
