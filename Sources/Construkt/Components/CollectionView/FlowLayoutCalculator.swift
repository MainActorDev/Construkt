import UIKit

/// Computes wrapping flow-layout frames for variable-width items within a fixed container width.
/// Used by `CollectionLayoutSectionBuilder.flow()` to feed `NSCollectionLayoutGroup.custom`.
public enum FlowLayoutCalculator {

    /// Returns an array of `CGRect` frames, one per item, laid out left-to-right with line wrapping.
    ///
    /// - Parameters:
    ///   - itemSizes: The pre-measured size of each item.
    ///   - containerWidth: The available width for laying out items.
    ///   - horizontalSpacing: Horizontal gap between items on the same line.
    ///   - lineSpacing: Vertical gap between lines.
    /// - Returns: An array of frames in the same order as `itemSizes`.
    public static func computeFrames(
        itemSizes: [CGSize],
        containerWidth: CGFloat,
        horizontalSpacing: CGFloat,
        lineSpacing: CGFloat
    ) -> [CGRect] {
        guard !itemSizes.isEmpty else { return [] }

        var frames: [CGRect] = []
        frames.reserveCapacity(itemSizes.count)

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in itemSizes {
            let itemWidth = min(size.width, containerWidth)

            // Wrap to next line if item doesn't fit (unless line is empty).
            // Note: currentX already includes horizontalSpacing from the previous item.
            if currentX > 0 && currentX + itemWidth > containerWidth {
                currentY += lineHeight + lineSpacing
                currentX = 0
                lineHeight = 0
            }

            let x = currentX
            let frame = CGRect(x: x, y: currentY, width: itemWidth, height: size.height)
            frames.append(frame)

            currentX = x + itemWidth + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        return frames
    }

    /// The total height of the laid-out content (max Y + last line height).
    public static func totalHeight(for frames: [CGRect]) -> CGFloat {
        guard let last = frames.last else { return 0 }
        return last.maxY
    }
}
