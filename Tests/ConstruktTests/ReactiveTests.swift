import Testing
import UIKit
@testable import ConstruktKit

// MARK: - Property Tests

@Suite("Property")
struct PropertyTests {
    
    @Test("Initial value is accessible")
    func initialValue() {
        let property = Property<Int>(42)
        #expect(property.wrappedValue == 42)
    }
    
    @Test("Setting value updates the stored value")
    func setValue() {
        let property = Property<String>("hello")
        property.wrappedValue = "world"
        #expect(property.wrappedValue == "world")
    }
    
    @Test("Observer receives initial value on subscribe")
    func observerReceivesInitialValue() async {
        await confirmation { done in
            let property = Property<Int>(10)
            property.observe(on: nil) { value in
                #expect(value == 10)
                done()
            }.store(in: CancelBag())
        }
    }
    
    @Test("Observer receives updated value")
    func observerReceivesUpdate() async {
        let bag = CancelBag()
        let property = Property<Int>(0)
        var received: [Int] = []
        
        await confirmation { done in
            property.observe(on: nil) { value in
                received.append(value)
                if received.count == 2 {
                    #expect(received == [0, 99])
                    done()
                }
            }.store(in: bag)
            
            property.wrappedValue = 99
        }
    }
    
    @Test("Multiple observers all receive values")
    func multipleObservers() async {
        let bag = CancelBag()
        let property = Property<Int>(1)
        var receivedA: [Int] = []
        var receivedB: [Int] = []
        
        await confirmation(expectedCount: 2) { done in
            property.observe(on: nil) { value in
                receivedA.append(value)
                if receivedA.count == 2 { done() }
            }.store(in: bag)
            
            property.observe(on: nil) { value in
                receivedB.append(value)
                if receivedB.count == 2 { done() }
            }.store(in: bag)
            
            property.wrappedValue = 2
        }
        
        #expect(receivedA == [1, 2])
        #expect(receivedB == [1, 2])
    }
    
    @Test("Cancellation stops observation")
    func cancellation() {
        let property = Property<Int>(0)
        var received: [Int] = []
        
        let token = property.observe(on: nil) { value in
            received.append(value)
        }
        
        property.wrappedValue = 1
        token.cancel()
        property.wrappedValue = 2  // should not be received
        
        #expect(received == [0, 1])
    }
    
    @Test("CancelBag deinit stops observation")
    func cancelBagDeinit() {
        let property = Property<Int>(0)
        var received: [Int] = []
        
        do {
            let bag = CancelBag()
            property.observe(on: nil) { value in
                received.append(value)
            }.store(in: bag)
            
            property.wrappedValue = 1
            // bag deallocates here
        }
        
        property.wrappedValue = 2  // should not be received
        #expect(received == [0, 1])
    }
}

// MARK: - Signal Tests

@Suite("Signal")
struct SignalTests {
    
    @Test("Signal does not emit initial value")
    func noInitialValue() {
        let signal = Signal<Int>()
        var received: [Int] = []
        let bag = CancelBag()
        
        signal.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        #expect(received.isEmpty)
    }
    
    @Test("Signal forwards sent values")
    func sendsValues() {
        let signal = Signal<String>()
        var received: [String] = []
        let bag = CancelBag()
        
        signal.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        signal.send("a")
        signal.send("b")
        
        #expect(received == ["a", "b"])
    }
    
    @Test("Signal cancellation stops observation")
    func cancellation() {
        let signal = Signal<Int>()
        var received: [Int] = []
        
        let token = signal.observe(on: nil) { value in
            received.append(value)
        }
        
        signal.send(1)
        token.cancel()
        signal.send(2)
        
        #expect(received == [1])
    }
}

// MARK: - CancelBag Tests

@Suite("CancelBag")
struct CancelBagTests {
    
    @Test("Cancel bag cancels all tokens on cancel()")
    func cancelAll() {
        let bag = CancelBag()
        var cancelledA = false
        var cancelledB = false
        
        let tokenA = TestCancellable { cancelledA = true }
        let tokenB = TestCancellable { cancelledB = true }
        
        bag.insert(tokenA)
        bag.insert(tokenB)
        bag.cancel()
        
        #expect(cancelledA)
        #expect(cancelledB)
    }
    
    @Test("Cancel bag cancels all tokens on deinit")
    func cancelOnDeinit() {
        var cancelled = false
        
        do {
            let bag = CancelBag()
            bag.insert(TestCancellable { cancelled = true })
        }
        
        #expect(cancelled)
    }
}

// MARK: - Operator Tests

@Suite("Operators")
struct OperatorTests {
    
    // MARK: map
    
    @Test("map transforms values")
    func map() {
        let property = Property<Int>(5)
        let bag = CancelBag()
        var received: [String] = []
        
        property.map { "\($0)" }.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        property.wrappedValue = 10
        #expect(received == ["5", "10"])
    }
    
    // MARK: compactMap
    
    @Test("compactMap filters nil values")
    func compactMap() {
        let property = Property<String>("1")
        let bag = CancelBag()
        var received: [Int] = []
        
        property.compactMap { Int($0) }.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        property.wrappedValue = "abc"  // nil — filtered
        property.wrappedValue = "42"
        
        #expect(received == [1, 42])
    }
    
    // MARK: filter
    
    @Test("filter only forwards matching values")
    func filter() {
        let property = Property<Int>(1)
        let bag = CancelBag()
        var received: [Int] = []
        
        property.filter { $0 % 2 == 0 }.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        property.wrappedValue = 2
        property.wrappedValue = 3
        property.wrappedValue = 4
        
        #expect(received == [2, 4])
    }
    
    // MARK: skip
    
    @Test("skip ignores first N values")
    func skip() {
        let property = Property<Int>(0)
        let bag = CancelBag()
        var received: [Int] = []
        
        property.skip(2).observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        property.wrappedValue = 1
        property.wrappedValue = 2
        property.wrappedValue = 3
        
        // initial(0) skipped, 1 skipped, 2 forwarded, 3 forwarded
        #expect(received == [2, 3])
    }
    
    // MARK: scan
    
    @Test("scan accumulates values")
    func scan() {
        let property = Property<Int>(1)
        let bag = CancelBag()
        var received: [Int] = []
        
        property.scan(0) { acc, val in acc + val }.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        property.wrappedValue = 2
        property.wrappedValue = 3
        
        // 0+1=1, 1+2=3, 3+3=6
        #expect(received == [1, 3, 6])
    }
    
    // MARK: distinctUntilChanged
    
    @Test("distinctUntilChanged filters consecutive duplicates")
    func distinctUntilChanged() {
        let property = Property<Int>(1)
        let bag = CancelBag()
        var received: [Int] = []
        
        property.distinctUntilChanged().observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        property.wrappedValue = 1  // duplicate
        property.wrappedValue = 2
        property.wrappedValue = 2  // duplicate  
        property.wrappedValue = 3
        
        #expect(received == [1, 2, 3])
    }
    
    // MARK: removeDuplicates(by:)
    
    @Test("removeDuplicates uses custom comparator")
    func removeDuplicates() {
        let property = Property<String>("hello")
        let bag = CancelBag()
        var received: [String] = []
        
        // Case insensitive comparison
        property.removeDuplicates { $0.lowercased() == $1.lowercased() }
            .observe(on: nil) { value in
                received.append(value)
            }.store(in: bag)
        
        property.wrappedValue = "HELLO"  // duplicate (case insensitive)
        property.wrappedValue = "world"
        
        #expect(received == ["hello", "world"])
    }
    
    // MARK: merge
    
    @Test("merge combines two bindings")
    func merge() {
        let a = Signal<Int>()
        let b = Signal<Int>()
        let bag = CancelBag()
        var received: [Int] = []
        
        a.merge(with: b).observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        a.send(1)
        b.send(2)
        a.send(3)
        
        #expect(received == [1, 2, 3])
    }
    
    // MARK: just
    
    @Test("just emits a single value immediately")
    func just() {
        let bag = CancelBag()
        var received: [Int] = []
        
        AnyViewBinding.just(42).observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)
        
        #expect(received == [42])
    }
    
    // MARK: combineLatest (2-ary)
    
    @Test("combineLatest emits when both have values")
    func combineLatest() {
        let a = Property<Int>(1)
        let b = Property<String>("x")
        let bag = CancelBag()
        var received: [(Int, String)] = []
        
        AnyViewBinding.combineLatest(a, b).observe(on: nil) { pair in
            received.append(pair)
        }.store(in: bag)
        
        a.wrappedValue = 2
        b.wrappedValue = "y"
        
        // (1,"x") initial, (2,"x") after a=2, (2,"y") after b="y"
        #expect(received.count == 3)
        #expect(received[0].0 == 1 && received[0].1 == "x")
        #expect(received[1].0 == 2 && received[1].1 == "x")
        #expect(received[2].0 == 2 && received[2].1 == "y")
    }
    
    // MARK: combineLatestBindings (array)
    
    @Test("combineLatestBindings flattens arrays")
    func combineLatestBindings() {
        let a = Property<[Int]>([1, 2])
        let b = Property<[Int]>([3])
        let bag = CancelBag()
        var received: [[Int]] = []
        
        ConstruktKit.combineLatestBindings([a.map { $0 }, b.map { $0 }])
            .observe(on: nil) { value in
                received.append(value)
            }.store(in: bag)
        
        // Both have initial values, so first emission is [1,2,3]
        #expect(received.last == [1, 2, 3])
    }
    
    // MARK: debounce
    
    @Test("debounce waits for quiet period")
    func debounce() async throws {
        let signal = Signal<String>()
        let bag = CancelBag()
        let testQueue = DispatchQueue(label: "test.debounce")
        let expectation = DispatchSemaphore(value: 0)
        var received: [String] = []
        let lock = NSLock()
        
        signal.debounce(for: 0.1, on: testQueue)
            .observe(on: testQueue) { value in
                lock.lock()
                received.append(value)
                lock.unlock()
                expectation.signal()
            }.store(in: bag)
        
        // Rapid-fire updates — only the last should make it through
        signal.send("a")
        signal.send("b")
        signal.send("final")
        
        // Wait for the debounce to fire (with timeout)
        let result = expectation.wait(timeout: .now() + 1.0)
        #expect(result == .success)
        
        lock.lock()
        let values = received
        lock.unlock()
        #expect(values == ["final"])
    }
    
    // MARK: throttle
    
    @Test("throttle rate-limits emissions")
    func throttle() async {
        let signal = Signal<Int>()
        let bag = CancelBag()
        var received: [Int] = []
        let expectation = DispatchSemaphore(value: 0)
        
        signal.throttle(for: 0.2, latest: false)
            .observe(on: nil) { value in
                received.append(value)
            }.store(in: bag)
        
        // First value should get through, rest should be dropped within the window
        signal.send(1)
        signal.send(2)
        signal.send(3)
        
        _ = expectation.wait(timeout: .now() + 0.05)
        
        // Only the first should have gotten through
        #expect(received == [1])
        
        // After the window expires, next value should get through
        _ = expectation.wait(timeout: .now() + 0.25)
        signal.send(4)
        
        _ = expectation.wait(timeout: .now() + 0.05)
        #expect(received == [1, 4])
    }
    
    // MARK: delay
    
    @Test("delay schedules on specified queue")
    func delaySchedulesOnSpecifiedQueue() async throws {
        let property = Property<Int>(0)
        var received: [Int] = []
        let lock = NSLock()
        let bag = CancelBag()
        
        let delayQueue = DispatchQueue(label: "test.delay.queue")
        let delayed = property.delay(0.05, on: delayQueue)
        
        delayed.observe(on: nil) { value in
            lock.lock()
            received.append(value)
            lock.unlock()
        }.store(in: bag)
        
        // Initial value (0) should be delayed
        lock.lock()
        let immediateValues = received
        lock.unlock()
        #expect(immediateValues.isEmpty, "Value should not arrive immediately")
        
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        lock.lock()
        let afterDelay = received
        lock.unlock()
        #expect(afterDelay == [0], "Delayed value should arrive after interval")
        
        property.wrappedValue = 42
        lock.lock()
        let afterSet = received
        lock.unlock()
        #expect(afterSet == [0], "New value should not arrive immediately")
        
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        lock.lock()
        let finalValues = received
        lock.unlock()
        #expect(finalValues == [0, 42], "New value should arrive after delay")
    }
    
    // MARK: flatMapLatest
    
    @Test("flatMapLatest cancels previous inner subscription")
    func flatMapLatestCancelsPrevious() {
        let source = Property<Int>(0)
        let bag = CancelBag()
        var received: [String] = []

        let mapped = source.flatMapLatest { value -> AnyViewBinding<String> in
            let inner = Property<String>("inner-\(value)")
            return inner.eraseToAnyViewBinding()
        }

        mapped.observe(on: nil) { value in
            received.append(value)
        }.store(in: bag)

        // Initial: source emits 0, flatMapLatest subscribes to inner Property("inner-0")
        #expect(received == ["inner-0"])

        source.wrappedValue = 1
        #expect(received == ["inner-0", "inner-1"])

        source.wrappedValue = 2
        #expect(received == ["inner-0", "inner-1", "inner-2"])
    }
}

// MARK: - EraseToAnyViewBinding Tests

@Suite("EraseToAnyViewBinding Tests")
@MainActor
struct EraseToAnyViewBindingTests {
    @Test("eraseToAnyViewBinding preserves values")
    func erasedBindingPreservesValues() {
        let property = Property<Int>(0)
        let erased = property.eraseToAnyViewBinding()
        var received: [Int] = []
        let cancellable = erased.observe(on: nil) { received.append($0) }
        property.wrappedValue = 1
        property.wrappedValue = 2
        #expect(received == [0, 1, 2])
        cancellable.cancel()
    }

    @Test("eraseToAnyViewBinding works with operators")
    func erasedBindingWorksWithOperators() {
        let property = Property<Int>(0)
        let erased = property.map { $0 * 2 }.eraseToAnyViewBinding()
        var received: [Int] = []
        let cancellable = erased.observe(on: nil) { received.append($0) }
        property.wrappedValue = 5
        #expect(received == [0, 10])
        cancellable.cancel()
    }

    @Test("eraseToAnyViewBinding cancellation works")
    func erasedBindingCancellation() {
        let property = Property<Int>(0)
        let erased = property.eraseToAnyViewBinding()
        var received: [Int] = []
        let cancellable = erased.observe(on: nil) { received.append($0) }
        property.wrappedValue = 1
        cancellable.cancel()
        property.wrappedValue = 2
        #expect(received == [0, 1])
    }
}

// MARK: - Test Helpers

private final class TestCancellable: AnyCancellableLifecycle {
    private let onCancel: () -> Void
    
    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }
    
    func cancel() {
        onCancel()
    }
}
