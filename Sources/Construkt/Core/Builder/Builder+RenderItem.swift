import Foundation
import UIKit

/// Wraps data to allow a clean fallback to a shimmer placeholder state.
/// This allows declarative views to switch between real data and placeholder shimmers
/// without needing massive mock objects.
public enum RenderItem<T> {
    case data(T)
    case placeholder
}

// MARK: - Cell Content Wrapping

extension RenderItem: CellContentWrapper {
    public var originalModel: Any {
        switch self {
        case .data(let value):
            // Return the unboxed internal model for Event Routing modifiers.
            return value
        case .placeholder:
            return self
        }
    }
}

// MARK: - Equatable & Hashable Conformance

extension RenderItem: Equatable where T: Equatable {
    public static func == (lhs: RenderItem, rhs: RenderItem) -> Bool {
        switch (lhs, rhs) {
        case (.data(let l), .data(let r)):
            return l == r
        case (.placeholder, .placeholder):
            return true
        default:
            return false
        }
    }
}

extension RenderItem: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .data(let value):
            hasher.combine(0)
            hasher.combine(value)
        case .placeholder:
            hasher.combine(1)
        }
    }
}

// MARK: - Array Extension for Sections

public extension Array {
    /// Converts an array of `T` to exactly `[RenderItem<T>]`
    func asRenderItems() -> [RenderItem<Element>] {
        self.map { .data($0) }
    }
}

// MARK: - View Modifiers

public extension ModifiableView {
    
    /// Applies data to a view if available, or configures it as a shimmer placeholder.
    ///
    /// - Parameters:
    ///   - item: The `RenderItem<T>` controlling this view.
    ///   - onData: A closure that configures the view with the real data `T`.
    ///   - onPlaceholder: A closure that configures the view's dummy shape/text for the shimmer.
    @discardableResult
    func render<T>(
        for item: RenderItem<T>,
        onData: (Base, T) -> Void,
        onPlaceholder: ((Base) -> Void)? = nil
    ) -> ViewModifier<Base> {
        
        switch item {
        case .data(let realData):
            onData(modifiableView, realData)
            return self.shimmerable(false)
            
        case .placeholder:
            onPlaceholder?(modifiableView)
            return self.shimmerable(true)
        }
    }
}

// MARK: - Specialized LabelView Modifier

public extension ModifiableView where Base: UILabel {
    
    /// Binds actual text if available, or a dummy string if in placeholder mode.
    ///
    /// - Parameters:
    ///   - item: The `RenderItem` driving this view.
    ///   - placeholder: The dummy text the layout engine should use to size the shimmer box.
    ///   - textMapper: Extracts the real string from the data model.
    @discardableResult
    func render<T>(
        for item: RenderItem<T>,
        placeholder: String = "Placeholder Text",
        textMapper: (T) -> String?
    ) -> ViewModifier<Base> {
        
        switch item {
        case .data(let realData):
            return ViewModifier(modifiableView, keyPath: \.text, value: textMapper(realData))
                .shimmerable(false)
            
        case .placeholder:
            return ViewModifier(modifiableView, keyPath: \.text, value: placeholder)
                .shimmerable(true)
        }
    }
}

// MARK: - Specialized ImageView Modifier

public extension ModifiableView where Base: UIImageView {
    
    /// Loads a remote image if data is available, or shows a shimmer placeholder.
    ///
    /// - Parameters:
    ///   - item: The `RenderItem` driving this view.
    ///   - placeholder: An optional placeholder image shown while loading.
    ///   - urlMapper: Extracts the remote `URL?` from the data model.
    @discardableResult
    func render<T>(
        for item: RenderItem<T>,
        placeholder: UIImage? = nil,
        urlMapper: (T) -> URL?
    ) -> ViewModifier<Base> {
        
        switch item {
        case .data(let realData):
            modifiableView.setImage(from: urlMapper(realData), placeholder: placeholder)
            return self.shimmerable(false)
            
        case .placeholder:
            modifiableView.image = placeholder
            return self.shimmerable(true)
        }
    }
}
