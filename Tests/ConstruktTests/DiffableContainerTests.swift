import Testing
import UIKit
@testable import ConstruktKit

@Suite("DiffableContainerView") @MainActor
struct DiffableContainerTests {

    @Test("initial emission adds all children")
    func initialEmissionAddsAllChildren() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("Hello")),
            TaggedView(id: "b", view: LabelView("World"))
        ])

        let container = DiffableContainerView(binding)
        let uiView = container.build()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)

        #expect(uiView.subviews.count == 2)
    }

    @Test("incremental insert adds new child without rebuilding existing")
    func incrementalInsert() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("First"))
        ])

        let container = DiffableContainerView(binding)
        let uiView = container.build()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)

        #expect(uiView.subviews.count == 1)

        let firstChild = uiView.subviews[0]

        // Emit a new array with an additional item
        binding.wrappedValue = [
            TaggedView(id: "a", view: LabelView("First")),
            TaggedView(id: "b", view: LabelView("Second"))
        ]

        #expect(uiView.subviews.count == 2)
        // The original child should be the same instance (not rebuilt)
        #expect(uiView.subviews[0] === firstChild)
    }

    @Test("incremental remove removes child and preserves surviving instance")
    func incrementalRemove() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("Alpha")),
            TaggedView(id: "b", view: LabelView("Beta"))
        ])

        let container = DiffableContainerView(binding)
        let uiView = container.build()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)

        #expect(uiView.subviews.count == 2)

        let survivingView = uiView.subviews[0] // "a" view

        // Remove "b"
        binding.wrappedValue = [
            TaggedView(id: "a", view: LabelView("Alpha"))
        ]

        #expect(uiView.subviews.count == 1)
        #expect(uiView.subviews[0] === survivingView)
    }

    @Test("unchanged items are preserved (same object identity)")
    func unchangedItemsPreserved() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "x", view: LabelView("Original X")),
            TaggedView(id: "y", view: LabelView("Original Y"))
        ])

        let container = DiffableContainerView(binding)
        let uiView = container.build()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)

        let viewX = uiView.subviews[0]
        let viewY = uiView.subviews[1]

        // Emit same IDs but with different view recipes — existing views must NOT be rebuilt
        binding.wrappedValue = [
            TaggedView(id: "x", view: LabelView("Changed X")),
            TaggedView(id: "y", view: LabelView("Changed Y"))
        ]

        #expect(uiView.subviews.count == 2)
        #expect(uiView.subviews[0] === viewX)
        #expect(uiView.subviews[1] === viewY)
    }

    @Test("full replacement removes old views and adds new ones")
    func fullReplacementWorks() {
        let binding = Property<[TaggedView]>([
            TaggedView(id: "a", view: LabelView("A")),
            TaggedView(id: "b", view: LabelView("B"))
        ])

        let container = DiffableContainerView(binding)
        let uiView = container.build()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(uiView)

        let oldViewA = uiView.subviews[0]
        let oldViewB = uiView.subviews[1]

        // Replace with entirely new IDs
        binding.wrappedValue = [
            TaggedView(id: "c", view: LabelView("C")),
            TaggedView(id: "d", view: LabelView("D"))
        ]

        #expect(uiView.subviews.count == 2)
        // Old views should no longer be in the hierarchy
        #expect(oldViewA.superview == nil)
        #expect(oldViewB.superview == nil)
        // New views should be different instances
        #expect(uiView.subviews[0] !== oldViewA)
        #expect(uiView.subviews[1] !== oldViewB)
    }
}
