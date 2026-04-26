import Testing
@testable import ConstruktKit
import CoreGraphics

@Suite("FlowLayoutCalculator")
struct FlowLayoutCalculatorTests {

    @Test("single row when all items fit")
    func singleRow() {
        let sizes: [CGSize] = [
            CGSize(width: 60, height: 30),
            CGSize(width: 80, height: 30),
            CGSize(width: 100, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 300,
            horizontalSpacing: 8,
            lineSpacing: 8
        )

        #expect(frames.count == 3)
        // First item at origin
        #expect(frames[0].origin.x == 0)
        #expect(frames[0].origin.y == 0)
        #expect(frames[0].size == sizes[0])
        // Second item after first + spacing
        #expect(frames[1].origin.x == 68) // 60 + 8
        #expect(frames[1].origin.y == 0)
        // Third item after second + spacing
        #expect(frames[2].origin.x == 156) // 68 + 80 + 8
        #expect(frames[2].origin.y == 0)
    }
}
