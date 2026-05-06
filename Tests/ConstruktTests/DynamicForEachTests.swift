import Testing
import UIKit
@testable import ConstruktKit

private struct TestItem: Identifiable, Equatable {
    let id: String
    let label: String
}

@Suite("DynamicForEachChangeset")
struct DynamicForEachChangesetTests {

    @Test("diff insert only")
    func diffInsertOnly() {
        let old = [TestItem(id: "a", label: "A")]
        let new = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        let changeset = DynamicForEachChangeset.diff(old: old, new: new)

        #expect(changeset.inserts == [1])
        #expect(changeset.removes == [])
        #expect(changeset.moves == [])
    }

    @Test("diff remove only")
    func diffRemoveOnly() {
        let old = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        let new = [TestItem(id: "a", label: "A")]
        let changeset = DynamicForEachChangeset.diff(old: old, new: new)

        #expect(changeset.removes == [1])
        #expect(changeset.inserts == [])
        #expect(changeset.moves == [])
    }

    @Test("diff move detected")
    func diffMoveDetected() {
        let old = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B"), TestItem(id: "c", label: "C")]
        let new = [TestItem(id: "c", label: "C"), TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        let changeset = DynamicForEachChangeset.diff(old: old, new: new)

        #expect(changeset.removes == [])
        #expect(changeset.inserts == [])
        let expectedMove = DynamicForEachChangeset.Move(from: 2, to: 0)
        #expect(changeset.moves.contains(expectedMove))
    }
}

@Suite("DynamicForEach") @MainActor
struct DynamicForEachTests {

    @Test("initial items produce correct view count")
    func initialItemsProduceCorrectViewCount() {
        let items = [
            TestItem(id: "a", label: "A"),
            TestItem(id: "b", label: "B"),
            TestItem(id: "c", label: "C")
        ]
        let forEach = DynamicForEach(items) { item in
            LabelView(item.label)
        }

        #expect(forEach.count == 3)
        #expect(forEach.asViews().count == 3)
    }

    @Test("update signal fires on items change")
    func updateSignalFires() {
        let items = [TestItem(id: "a", label: "A")]
        let forEach = DynamicForEach(items) { item in
            LabelView(item.label)
        }

        var signalFired = false
        let cancelBag = CancelBag()
        forEach.updated?.observe(on: .none) { _ in
            signalFired = true
        }.store(in: cancelBag)

        forEach.items = [TestItem(id: "a", label: "A"), TestItem(id: "b", label: "B")]
        #expect(signalFired == true)
    }

    @Test("applyChangeset inserts to stack")
    func applyChangesetInsertsToStack() {
        let items = [
            TestItem(id: "a", label: "A"),
            TestItem(id: "b", label: "B")
        ]
        let forEach = DynamicForEach(items) { item in
            LabelView(item.label)
        }

        let stack = UIStackView()
        forEach.asViews().forEach { stack.addArrangedSubview($0.build()) }
        #expect(stack.arrangedSubviews.count == 2)

        forEach.items = [
            TestItem(id: "a", label: "A"),
            TestItem(id: "b", label: "B"),
            TestItem(id: "c", label: "C")
        ]
        forEach.applyChangeset(to: stack)
        #expect(stack.arrangedSubviews.count == 3)
    }

    @Test("applyChangeset removes from stack preserving instances")
    func applyChangesetRemovesFromStack() {
        let items = [
            TestItem(id: "a", label: "A"),
            TestItem(id: "b", label: "B"),
            TestItem(id: "c", label: "C")
        ]
        let forEach = DynamicForEach(items) { item in
            LabelView(item.label)
        }

        let stack = UIStackView()
        forEach.asViews().forEach { stack.addArrangedSubview($0.build()) }
        #expect(stack.arrangedSubviews.count == 3)

        let survivingView = stack.arrangedSubviews[0] // "a" view

        forEach.items = [
            TestItem(id: "a", label: "A"),
            TestItem(id: "c", label: "C")
        ]
        forEach.applyChangeset(to: stack)
        #expect(stack.arrangedSubviews.count == 2)
        #expect(stack.arrangedSubviews[0] === survivingView)
    }
}
