import Foundation

/// UI-facing wrapper around `FeatureRuntime`.
///
/// Responsibilities:
/// - bridges async runtime state/output streams into reactive `Property`/`Signal`
/// - provides convenience intent APIs (`dispatch`, `sendAndWait`, `sendAndDrain`)
/// - serializes externally submitted intents to preserve ordering guarantees
/// - owns runtime lifecycle for feature scope
public final class FeatureStore<F: FeatureSpec> {
    /// Underlying actor runtime.
    public let runtime: FeatureRuntime<F>

    /// Observable state suitable for view bindings.
    public let state: Property<F.State>

    /// One-off output stream suitable for transient events.
    public let outputs: Signal<F.Output>

    private let deliveryQueue: DispatchQueue
    private let lifecycleLock = NSLock()
    private var bridgeReadyTask: Task<Void, Never>?

    private var streamTasks: [Task<Void, Never>] = []
    private var intentQueueTail: Task<Void, Never>?
    private var isShutDown = false

    public init(
        initialState: F.State = F.initialState,
        dependencies: F.Dependencies,
        scope: RuntimeScope = RuntimeScope.root(),
        configuration: RuntimeConfiguration = .init(),
        deliveryQueue: DispatchQueue = .main,
        effectExecutor: @escaping FeatureEffectExecutor<F>
    ) {
        self.runtime = FeatureRuntime(
            initialState: initialState,
            dependencies: dependencies,
            scope: scope,
            configuration: configuration,
            effectExecutor: effectExecutor
        )
        self.state = Property(initialState)
        self.outputs = Signal()
        self.deliveryQueue = deliveryQueue
        self.bridgeReadyTask = makeBridgeTask()
    }

    deinit {
        bridgeReadyTask?.cancel()

        let tasks = takeStreamTasks(markShutDown: true)
        tasks.forEach { $0.cancel() }

        let queuedIntents = takeIntentQueueTail()
        queuedIntents?.cancel()

        let runtime = self.runtime
        Task {
            await runtime.shutdown()
        }
    }

    /// Fire-and-forget intent dispatch.
    public func dispatch(_ intent: F.Intent) {
        _ = enqueueIntent(intent)
    }

    /// Sends intent and awaits runtime reducer processing for this intent.
    public func sendAndWait(_ intent: F.Intent) async {
        guard let task = enqueueIntent(intent) else {
            return
        }

        await task.value
    }

    /// Sends intent and waits until runtime is idle.
    ///
    /// Useful in tests and imperative call sites that need fully-settled state,
    /// including async effect feedback.
    public func sendAndDrain(_ intent: F.Intent) async {
        guard let task = enqueueIntent(intent) else {
            return
        }

        await task.value
        guard !hasShutDown else {
            return
        }

        await runtime.waitUntilIdle()
        guard !hasShutDown else {
            return
        }

        await synchronizeStateFromRuntime()
    }

    /// Subscribes to state changes, delivering updates on the specified queue.
    @discardableResult
    public func observeState(
        on queue: DispatchQueue? = .main,
        _ handler: @escaping (F.State) -> Void
    ) -> AnyCancellableLifecycle {
        state.observe(on: queue, handler)
    }

    /// Subscribes to one-off output events, delivering them on the specified queue.
    @discardableResult
    public func observeOutputs(
        on queue: DispatchQueue? = .main,
        _ handler: @escaping (F.Output) -> Void
    ) -> AnyCancellableLifecycle {
        outputs.observe(on: queue, handler)
    }

    /// Shuts down store streams and runtime.
    public func shutdown() async {
        bridgeReadyTask?.cancel()

        let tasks = takeStreamTasks(markShutDown: true)
        tasks.forEach { $0.cancel() }

        let queuedIntents = takeIntentQueueTail()
        queuedIntents?.cancel()
        await runtime.shutdown()
    }

    private var hasShutDown: Bool {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return isShutDown
    }

    private func appendTask(_ task: Task<Void, Never>) {
        lifecycleLock.lock()
        guard !isShutDown else {
            lifecycleLock.unlock()
            task.cancel()
            return
        }

        streamTasks.append(task)
        lifecycleLock.unlock()
    }

    private func takeStreamTasks(markShutDown: Bool) -> [Task<Void, Never>] {
        lifecycleLock.lock()
        if markShutDown {
            isShutDown = true
        }

        let tasks = streamTasks
        streamTasks.removeAll(keepingCapacity: false)
        lifecycleLock.unlock()
        return tasks
    }

    private func takeIntentQueueTail() -> Task<Void, Never>? {
        lifecycleLock.lock()
        let tail = intentQueueTail
        intentQueueTail = nil
        lifecycleLock.unlock()
        return tail
    }

    /// Serializes intent submission order, regardless of caller concurrency.
    private func enqueueIntent(_ intent: F.Intent) -> Task<Void, Never>? {
        lifecycleLock.lock()
        guard !isShutDown else {
            lifecycleLock.unlock()
            return nil
        }

        let previous = intentQueueTail
        let runtime = self.runtime
        let bridgeReadyTask = self.bridgeReadyTask

        let task = Task { [weak self] in
            _ = await previous?.result
            await bridgeReadyTask?.value

            guard let self, !self.hasShutDown else {
                return
            }

            await runtime.send(intent)
        }

        intentQueueTail = task
        lifecycleLock.unlock()
        return task
    }

    /// Starts stream bridge after runtime streams are available.
    private func makeBridgeTask() -> Task<Void, Never> {
        let runtime = self.runtime

        return Task { [weak self] in
            let stateStream = await runtime.stateStream()
            let outputStream = await runtime.outputStream()

            guard let self else {
                return
            }

            let stateTask = Task { [weak self] in
                for await nextState in stateStream {
                    guard let self else {
                        return
                    }

                    self.deliver {
                        self.state.wrappedValue = nextState
                    }
                }
            }
            self.appendTask(stateTask)

            let outputTask = Task { [weak self] in
                for await output in outputStream {
                    guard let self else {
                        return
                    }

                    self.deliver {
                        self.outputs.send(output)
                    }
                }
            }
            self.appendTask(outputTask)
        }
    }

    private func deliver(_ action: @escaping () -> Void) {
        if deliveryQueue === DispatchQueue.main, Thread.isMainThread {
            action()
        } else {
            deliveryQueue.async(execute: action)
        }
    }

    private func deliverAndWait(_ action: @escaping () -> Void) async {
        if deliveryQueue === DispatchQueue.main {
            await MainActor.run {
                action()
            }
            return
        }

        await withCheckedContinuation { continuation in
            deliveryQueue.async {
                action()
                continuation.resume()
            }
        }
    }

    /// Ensures store state mirrors runtime after explicit draining.
    private func synchronizeStateFromRuntime() async {
        let latestState = await runtime.currentState()
        await deliverAndWait {
            self.state.wrappedValue = latestState
        }
    }
}
