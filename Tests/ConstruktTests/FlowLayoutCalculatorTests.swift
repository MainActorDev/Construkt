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

    @Test("wraps to second row when items exceed container width")
    func wrapsToSecondRow() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 250,
            horizontalSpacing: 8,
            lineSpacing: 12
        )

        #expect(frames.count == 4)
        // Row 1: items 0, 1 (100 + 8 + 100 = 208 <= 250)
        #expect(frames[0].origin == CGPoint(x: 0, y: 0))
        #expect(frames[1].origin == CGPoint(x: 108, y: 0))
        // Row 2: items 2, 3 (100 + 8 + 100 = 208 <= 250)
        #expect(frames[2].origin == CGPoint(x: 0, y: 42)) // 30 + 12
        #expect(frames[3].origin == CGPoint(x: 108, y: 42))
    }

    @Test("mixed heights uses tallest item per row")
    func mixedHeights() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 20),
            CGSize(width: 100, height: 40),
            CGSize(width: 100, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 250,
            horizontalSpacing: 8,
            lineSpacing: 8
        )

        // Row 1: items 0, 1 — line height = 40
        #expect(frames[0].origin.y == 0)
        #expect(frames[1].origin.y == 0)
        // Row 2: item 2 starts at y = 40 + 8 = 48
        #expect(frames[2].origin.y == 48)
    }

    @Test("empty input returns empty frames")
    func emptyInput() {
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: [],
            containerWidth: 300,
            horizontalSpacing: 8,
            lineSpacing: 8
        )
        #expect(frames.isEmpty)
        #expect(FlowLayoutCalculator.totalHeight(for: frames) == 0)
    }

    @Test("oversized item is clamped to container width")
    func oversizedItem() {
        let sizes: [CGSize] = [
            CGSize(width: 500, height: 30)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 300,
            horizontalSpacing: 8,
            lineSpacing: 8
        )

        #expect(frames.count == 1)
        #expect(frames[0].size.width == 300)
        #expect(frames[0].origin.x == 0)
    }

    @Test("totalHeight returns correct value")
    func totalHeightCalculation() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 30),
            CGSize(width: 100, height: 40)
        ]
        let frames = FlowLayoutCalculator.computeFrames(
            itemSizes: sizes,
            containerWidth: 250,
            horizontalSpacing: 8,
            lineSpacing: 10
        )
        // Row 1: height 30, Row 2: height 40, gap 10
        // Total = 30 + 10 + 40 = 80
        #expect(FlowLayoutCalculator.totalHeight(for: frames) == 80)
    }
}
