import Foundation
import Testing
@testable import ConstruktKit

@Suite("RuntimeScope")
struct RuntimeScopeTests {

    @Test("child shutdown removes itself from parent children dictionary")
    func childShutdownRemovesFromParent() async {
        let parent = RuntimeScope.root()
        let child = await parent.makeChild()

        // Parent should have 1 child registered.
        let countBefore = await parent.childCount()
        #expect(countBefore == 1)

        // Shut down child independently (not via parent cascade).
        await child.shutdown()

        // Parent's children dictionary should no longer contain the child.
        let countAfter = await parent.childCount()
        #expect(countAfter == 0)

        // Parent is still functional — can create new children.
        let child2 = await parent.makeChild()
        let countWithNewChild = await parent.childCount()
        #expect(countWithNewChild == 1)

        // Clean up.
        await parent.shutdown()
        #expect(await child.terminated() == true)
        #expect(await child2.terminated() == true)
        #expect(await parent.terminated() == true)
    }

    @Test("parent shutdown still cascades to all children")
    func parentShutdownCascadesToChildren() async {
        let parent = RuntimeScope.root()
        let child1 = await parent.makeChild()
        let child2 = await parent.makeChild()

        #expect(await parent.childCount() == 2)

        await parent.shutdown()

        #expect(await child1.terminated() == true)
        #expect(await child2.terminated() == true)
        #expect(await parent.childCount() == 0)
    }

    @Test("multiple children can shut down independently without affecting siblings")
    func multipleChildrenShutdownIndependently() async {
        let parent = RuntimeScope.root()
        let child1 = await parent.makeChild()
        let child2 = await parent.makeChild()
        let child3 = await parent.makeChild()

        #expect(await parent.childCount() == 3)

        await child2.shutdown()
        #expect(await parent.childCount() == 2)
        #expect(await child2.terminated() == true)
        #expect(await child1.terminated() == false)
        #expect(await child3.terminated() == false)

        await child1.shutdown()
        #expect(await parent.childCount() == 1)

        await parent.shutdown()
        #expect(await child3.terminated() == true)
    }

    @Test("child is deallocated after independent shutdown")
    func childDeallocatedAfterShutdown() async {
        let parent = RuntimeScope.root()
        var child: RuntimeScope? = await parent.makeChild()
        weak var weakChild = child

        await child!.shutdown()
        child = nil

        // If parent no longer retains child, weakChild should be nil.
        #expect(weakChild == nil, "Parent should not retain shut-down child")

        await parent.shutdown()
    }

    @Test("double shutdown of child is idempotent")
    func doubleShutdownIsIdempotent() async {
        let parent = RuntimeScope.root()
        let child = await parent.makeChild()

        await child.shutdown()
        #expect(await parent.childCount() == 0)

        // Second shutdown should be a no-op.
        await child.shutdown()
        #expect(await parent.childCount() == 0)

        await parent.shutdown()
    }
}
