import Foundation
import Testing
@testable import ConstruktKit

@Suite("RuntimeJournal")
struct RuntimeJournalTests {

    @Test("journal ring buffer evicts oldest and preserves order")
    func journalRingBuffer() {
        var journal = RuntimeJournal<String, String>(capacity: 3)

        journal.append(.intentReceived("a"))
        journal.append(.intentReceived("b"))
        journal.append(.intentReceived("c"))

        // At capacity — next append evicts "a"
        journal.append(.intentReceived("d"))

        let snapshot = journal.snapshot()
        #expect(snapshot.count == 3)

        // Verify order: b, c, d (oldest "a" evicted)
        if case .intentReceived(let v) = snapshot[0].event { #expect(v == "b") }
        if case .intentReceived(let v) = snapshot[1].event { #expect(v == "c") }
        if case .intentReceived(let v) = snapshot[2].event { #expect(v == "d") }
    }

    @Test("journal snapshot is empty initially")
    func journalEmptySnapshot() {
        let journal = RuntimeJournal<String, String>(capacity: 5)
        #expect(journal.snapshot().isEmpty)
    }

    @Test("journal respects capacity of 1")
    func journalCapacityOne() {
        var journal = RuntimeJournal<String, String>(capacity: 1)
        journal.append(.intentReceived("first"))
        journal.append(.intentReceived("second"))

        let snapshot = journal.snapshot()
        #expect(snapshot.count == 1)
        if case .intentReceived(let v) = snapshot[0].event { #expect(v == "second") }
    }
}
