import Foundation

/// Actor-backed runtime that executes a `FeatureSpec` deterministically.
///
/// Guarantees:
/// - Reducer (`FeatureSpec.reduce`) runs serially on actor isolation.
/// - Effects are scheduled using explicit `EffectPolicy`.
/// - State commits are versioned by monotonic `epoch`.
/// - Stale / superseded effect feedback can be dropped safely.
/// - Task lifecycle is tied to `RuntimeScope` for deterministic teardown.
public actor FeatureRuntime<F: FeatureSpec> {
    /// Effect payload queued for `.queue` policy.
    private struct ScheduledEffect {
        let effect: F.Effect
        let originEpoch: UInt64
        let latestGeneration: UInt64?
    }

    /// Internal task classification used for cleanup and keyed bookkeeping.
    private enum TaskKind {
        case effect(key: EffectKey?, policy: EffectPolicy)
        case debounce(key: EffectKey)
    }

    private let dependencies: F.Dependencies
    private let effectExecutor: FeatureEffectExecutor<F>
    private let configuration: RuntimeConfiguration
    private let scope: RuntimeScope

    private var state: F.State
    private var epoch: UInt64 = 0
    private var isShutDown = false

    private var journal: RuntimeJournal<F.Intent, F.Effect>

    private var stateContinuations: [UUID: AsyncStream<F.State>.Continuation] = [:]
    private var outputContinuations: [UUID: AsyncStream<F.Output>.Continuation] = [:]

    private var latestGenerationByKey: [EffectKey: UInt64] = [:]
    private var runningEffectTokenByKey: [EffectKey: UUID] = [:]
    private var debounceTokenByKey: [EffectKey: UUID] = [:]
    private var queuedEffectsByKey: [EffectKey: [ScheduledEffect]] = [:]
    private var taskKindsByToken: [UUID: TaskKind] = [:]
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        initialState: F.State = F.initialState,
        dependencies: F.Dependencies,
        scope: RuntimeScope = RuntimeScope.root(),
        configuration: RuntimeConfiguration = .init(),
        effectExecutor: @escaping FeatureEffectExecutor<F>
    ) {
        self.state = initialState
        self.dependencies = dependencies
        self.scope = scope
        self.configuration = configuration
        self.effectExecutor = effectExecutor
        self.journal = RuntimeJournal(capacity: configuration.journalCapacity)
    }

    deinit {
        let localScope = scope
        Task {
            await localScope.shutdown()
        }
    }

    /// Returns current committed state.
    public func currentState() -> F.State {
        state
    }

    /// Returns current state epoch.
    public func currentEpoch() -> UInt64 {
        epoch
    }

    /// Returns a bounded snapshot of runtime journal entries.
    public func journalSnapshot() -> [RuntimeJournalEntry<F.Intent, F.Effect>] {
        journal.snapshot()
    }

    /// Subscribes to state updates.
    ///
    /// If `RuntimeConfiguration.emitsInitialStateOnSubscription` is true,
    /// current state is emitted immediately.
    public func stateStream(
        bufferingPolicy: AsyncStream<F.State>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<F.State> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let token = UUID()
            stateContinuations[token] = continuation

            if configuration.emitsInitialStateOnSubscription {
                continuation.yield(state)
            }

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeStateContinuation(token)
                }
            }
        }
    }

    /// Subscribes to output events.
    public func outputStream(
        bufferingPolicy: AsyncStream<F.Output>.Continuation.BufferingPolicy = .bufferingNewest(50)
    ) -> AsyncStream<F.Output> {
        AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let token = UUID()
            outputContinuations[token] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeOutputContinuation(token)
                }
            }
        }
    }

    /// Sends an intent through reducer, commits state, and schedules resulting effects.
    public func send(_ intent: F.Intent) async {
        guard !isShutDown else {
            return
        }

        journal.append(.intentReceived(intent))

        var nextState = state
        let reduced = F.reduce(state: &nextState, intent: intent)

        epoch &+= 1
        state = nextState
        journal.append(.stateCommitted(epoch: epoch))
        publishState(nextState)
        publishOutputs(reduced.outputs)

        for effect in reduced.effects {
            await schedule(effect: effect, originEpoch: epoch)
        }

        resumeIdleWaitersIfNeeded()
    }

    /// Cancels all managed tasks and finishes streams.
    public func shutdown() async {
        guard !isShutDown else {
            return
        }

        isShutDown = true
        await scope.shutdown()
        finishStreams()
        resumeIdleWaitersIfNeeded()
    }

    /// Suspends until there is no running/debouncing/queued effect left.
    public func waitUntilIdle() async {
        guard !isShutDown else {
            return
        }

        if isIdle {
            return
        }

        await withCheckedContinuation { continuation in
            if isShutDown || isIdle {
                continuation.resume()
                return
            }

            idleWaiters.append(continuation)
        }
    }

    private func removeStateContinuation(_ token: UUID) {
        stateContinuations[token] = nil
    }

    private func removeOutputContinuation(_ token: UUID) {
        outputContinuations[token] = nil
    }

    private func publishState(_ state: F.State) {
        for continuation in stateContinuations.values {
            continuation.yield(state)
        }
    }

    private func publishOutputs(_ outputs: [F.Output]) {
        guard !outputs.isEmpty else {
            return
        }

        journal.append(.outputPublished(count: outputs.count))

        for output in outputs {
            for continuation in outputContinuations.values {
                continuation.yield(output)
            }
        }
    }

    private func finishStreams() {
        for continuation in stateContinuations.values {
            continuation.finish()
        }
        stateContinuations.removeAll(keepingCapacity: false)

        for continuation in outputContinuations.values {
            continuation.finish()
        }
        outputContinuations.removeAll(keepingCapacity: false)
    }

    /// Schedules an effect according to its policy.
    private func schedule(effect: F.Effect, originEpoch: UInt64) async {
        let policy = F.policy(for: effect)
        journal.append(.effectScheduled(effect, policy: policy, epoch: originEpoch))

        switch policy {
        case .concurrent:
            await launchEffect(effect, originEpoch: originEpoch, latestGeneration: nil, policy: policy)

        case .latest(let key):
            // Every latest submission increments generation. Only newest generation
            // feedback is accepted during completion.
            let generation = (latestGenerationByKey[key] ?? 0) &+ 1
            latestGenerationByKey[key] = generation
            await launchEffect(effect, originEpoch: originEpoch, latestGeneration: generation, policy: policy)

        case .queue(let key):
            var queue = queuedEffectsByKey[key, default: []]
            queue.append(.init(effect: effect, originEpoch: originEpoch, latestGeneration: nil))
            queuedEffectsByKey[key] = queue

            if runningEffectTokenByKey[key] == nil {
                await startNextQueuedEffect(for: key)
            }

        case .dropIfRunning(let key):
            if runningEffectTokenByKey[key] != nil {
                journal.append(.effectDropped(effect, reason: .alreadyRunning))
                return
            }

            await launchEffect(effect, originEpoch: originEpoch, latestGeneration: nil, policy: policy)

        case .restartable(let key):
            if let token = runningEffectTokenByKey[key] {
                await cancelManagedTask(token)
            }

            await launchEffect(effect, originEpoch: originEpoch, latestGeneration: nil, policy: policy)

        case .debounce(let key, let delay):
            if let token = debounceTokenByKey[key] {
                await cancelManagedTask(token)
            }

            await launchDebouncedEffect(effect, key: key, delay: delay, originEpoch: originEpoch)
        }
    }

    /// Starts next queued effect for key when lane is idle.
    private func startNextQueuedEffect(for key: EffectKey) async {
        guard runningEffectTokenByKey[key] == nil else {
            return
        }

        guard var queue = queuedEffectsByKey[key], !queue.isEmpty else {
            queuedEffectsByKey[key] = nil
            return
        }

        let next = queue.removeFirst()
        queuedEffectsByKey[key] = queue.isEmpty ? nil : queue

        await launchEffect(
            next.effect,
            originEpoch: next.originEpoch,
            latestGeneration: next.latestGeneration,
            policy: .queue(key)
        )
    }

    /// Launches a delayed debounce task that later starts actual effect execution.
    private func launchDebouncedEffect(
        _ effect: F.Effect,
        key: EffectKey,
        delay: TimeInterval,
        originEpoch: UInt64
    ) async {
        let token = UUID()
        let task = Task { [weak self] in
            do {
                try await Self.sleepForDebounce(delay)
            } catch {
                await self?.completeTask(token)
                return
            }

            guard let self else {
                return
            }

            await self.clearDebounceToken(token, for: key)
            await self.launchEffect(
                effect,
                originEpoch: originEpoch,
                latestGeneration: nil,
                policy: .debounce(key, delay)
            )
            await self.completeTask(token)
        }

        taskKindsByToken[token] = .debounce(key: key)
        debounceTokenByKey[key] = token

        await scope.register(token: token) {
            task.cancel()
        }
    }

    private func launchEffect(
        _ effect: F.Effect,
        originEpoch: UInt64,
        latestGeneration: UInt64?,
        policy: EffectPolicy
    ) async {
        let token = UUID()

        if let key = policy.key {
            runningEffectTokenByKey[key] = token
        }

        taskKindsByToken[token] = .effect(key: policy.key, policy: policy)

        let task = Task { [weak self] in
            await self?.runEffect(
                effect,
                originEpoch: originEpoch,
                latestGeneration: latestGeneration,
                token: token,
                policy: policy
            )
        }

        await scope.register(token: token) {
            task.cancel()
        }
    }

    /// Executes an effect and routes feedback into state machine loop.
    private func runEffect(
        _ effect: F.Effect,
        originEpoch: UInt64,
        latestGeneration: UInt64?,
        token: UUID,
        policy: EffectPolicy
    ) async {
        journal.append(.effectStarted(effect, epoch: originEpoch))

        do {
            let feedback = try await effectExecutor(effect, dependencies)

            if Task.isCancelled {
                journal.append(.effectCancelled(effect))
                await completeTask(token)
                return
            }

            // Drop stale feedback when feature requests stale protection.
            if F.staleStrategy(for: effect) == .drop, originEpoch != epoch {
                journal.append(.effectDropped(effect, reason: .staleEpoch))
                await completeTask(token)
                return
            }

            // For latest policy, only newest generation feedback can mutate state.
            if case .latest(let key) = policy,
               let generation = latestGeneration,
               latestGenerationByKey[key] != generation {
                journal.append(.effectDropped(effect, reason: .supersededByLatest))
                await completeTask(token)
                return
            }

            publishOutputs(feedback.outputs)
            for intent in feedback.intents {
                await send(intent)
            }

            journal.append(.effectCompleted(effect, epoch: originEpoch))
        } catch is CancellationError {
            journal.append(.effectCancelled(effect))
        } catch {
            journal.append(.effectFailed(effect, message: String(describing: error)))

            if let mappedIntent = F.mapEffectError(error, effect: effect) {
                await send(mappedIntent)
            }
        }

        await completeTask(token)
    }

    private func clearDebounceToken(_ token: UUID, for key: EffectKey) {
        guard debounceTokenByKey[key] == token else {
            return
        }
        debounceTokenByKey[key] = nil
    }

    private func cancelManagedTask(_ token: UUID) async {
        await scope.cancel(token: token)

        if let kind = taskKindsByToken[token] {
            switch kind {
            case .effect(let key, _):
                if let key, runningEffectTokenByKey[key] == token {
                    runningEffectTokenByKey[key] = nil
                }
            case .debounce(let key):
                if debounceTokenByKey[key] == token {
                    debounceTokenByKey[key] = nil
                }
            }
        }

        taskKindsByToken[token] = nil
        resumeIdleWaitersIfNeeded()
    }

    private func completeTask(_ token: UUID) async {
        await scope.unregister(token: token)

        guard let kind = taskKindsByToken.removeValue(forKey: token) else {
            return
        }

        switch kind {
        case .effect(let key, let policy):
            if let key, runningEffectTokenByKey[key] == token {
                runningEffectTokenByKey[key] = nil
            }

            if case .queue(let key) = policy {
                await startNextQueuedEffect(for: key)
            }

        case .debounce(let key):
            if debounceTokenByKey[key] == token {
                debounceTokenByKey[key] = nil
            }
        }

        resumeIdleWaitersIfNeeded()
    }

    /// Runtime is idle when there are no running or queued tasks left.
    private var isIdle: Bool {
        let hasQueuedEffects = queuedEffectsByKey.values.contains { !$0.isEmpty }
        return taskKindsByToken.isEmpty && !hasQueuedEffects
    }

    private func resumeIdleWaitersIfNeeded() {
        guard isShutDown || isIdle else {
            return
        }

        guard !idleWaiters.isEmpty else {
            return
        }

        let waiters = idleWaiters
        idleWaiters.removeAll(keepingCapacity: false)
        waiters.forEach { $0.resume() }
    }

    private static func sleepForDebounce(_ delay: TimeInterval) async throws {
        let normalizedDelay = max(0, delay)

        if #available(iOS 16.0, *) {
            let clock = ContinuousClock()
            try await clock.sleep(for: .seconds(normalizedDelay))
            return
        }

        let upperBound = TimeInterval(UInt64.max) / 1_000_000_000
        let clampedDelay = min(normalizedDelay, upperBound)
        let nanoseconds = UInt64(clampedDelay * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
