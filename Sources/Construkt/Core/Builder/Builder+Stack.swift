//
//  👨‍💻 Created by @thatswiftdev on 23/02/26.
//  © 2026, https://github.com/thatswiftdev. All rights reserved.
//
//  Originally created by Michael Long
//  https://github.com/hmlongco/Builder

//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit


/// A builder component that constructs a horizontal `UIStackView`.
///
/// Use `HStackView` to arrange its child views in a horizontal line, equivalent to SwiftUI's `HStack`.
public struct HStackView: ModifiableView {
    
    public let modifiableView = Modified(BuilderInternalUIStackView()) {
        $0.axis = .horizontal
        $0.distribution = .fill
        $0.alignment = .fill
        $0.spacing = UIStackView.spacingUseSystem
    }
    
    // lifecycle
    public init(spacing: CGFloat = UIStackView.spacingUseSystem, @ViewResultBuilder _ builder: () -> ViewConvertable) {
        modifiableView.spacing = spacing
        builder().asViews().forEach { modifiableView.addArrangedSubview($0) }
    }
    
    public init(_ convertableViews: [ViewConvertable]) {
        convertableViews.asViews().forEach { modifiableView.addArrangedSubview($0) }
     }

    public init(_ builder: AnyIndexableViewBuilder) {
        subscribe(to: builder)
    }
    
}

/// A builder component that constructs a vertical `UIStackView`.
///
/// Use `VStackView` to arrange its child views in a vertical column, equivalent to SwiftUI's `VStack`.
public struct VStackView: ModifiableView {
    
    public let modifiableView = Modified(BuilderInternalUIStackView()) {
        $0.axis = .vertical
        $0.distribution = .fill
        $0.alignment = .fill
        $0.spacing = UIStackView.spacingUseSystem
    }
    
    // lifecycle
    public init(spacing: CGFloat = UIStackView.spacingUseSystem, @ViewResultBuilder _ builder: () -> ViewConvertable) {
        modifiableView.spacing = spacing
        builder().asViews().forEach { modifiableView.addArrangedSubview($0) }
    }
    
    public init(_ convertableViews: [ViewConvertable]) {
        convertableViews.asViews().forEach { modifiableView.addArrangedSubview($0) }
     }

    public init(_ builder: AnyIndexableViewBuilder) {
        subscribe(to: builder)
    }

    public init<Binding:ViewBinding>(_ binding: Binding) where Binding.Value == [View] {
        onReceive(binding) { context in
            context.view.reset(to: context.value)
        }
    }
    
}

/// Standard modifiers for any `UIStackView` conforming to `ModifiableView`.
extension ModifiableView where Base: UIStackView {
    
    /// Sets the alignment of arranged subviews perpendicular to the stack's axis.
    @discardableResult
    public func alignment(_ alignment: UIStackView.Alignment) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.alignment, value: alignment)
    }
        
    /// Allows setting a custom background color underneath the stack view's layout.
    @discardableResult
    @available(iOS 14, *)
    public func backgroundColor(_ color: UIColor) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.backgroundColor, value: color)
    }

    /// Sets raw custom spacing value after the specified `UIView` directly.
    @discardableResult
    public func customSpacing(_ spacing: CGFloat, after: UIView) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.setCustomSpacing(spacing, after: after) }
    }
    
    /// Helper to find a specific subview by searching up the view chain, matching index paths or view instances, to apply custom trailing spacing.
    @discardableResult
    public func customSpacing(_ spacing: CGFloat, after: View) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            let view = after()
            for subview in $0.arrangedSubviews {
                if subview == view || subview.subviews.contains(view) {
                    $0.setCustomSpacing(spacing, after: subview)
                    break
                }
            }
        }
    }

    /// Sets the distribution determining the sizing and sizing logic of items along the stack's axis.
    @discardableResult
    public func distribution(_ distribution: UIStackView.Distribution) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.distribution, value: distribution)
    }
    
    /// Toggles whether `layoutMargins` are treated as relative to the safe area or directly from the frame edge.
    @discardableResult
    public func layoutMarginsRelativeArrangement(_ value: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.isLayoutMarginsRelativeArrangement, value: value)
    }
    
    /// Sets the basic spacing distance between children inside the stack view.
    @discardableResult
    public func spacing(_ spacing: CGFloat) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.spacing, value: spacing)
    }
    
    @discardableResult
    func subscribe(to builder: AnyIndexableViewBuilder) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            // set initial views and...
            modifiableView.reset(to: builder.asViews())
            // subscribe for updates
            builder.updated?
                .observe(on: .main) { [weak modifiableView] _ in
                    modifiableView?.reset(to: builder.asViews())
                }
                .store(in: $0.cancelBag)
        }
    }

}

// Custom UIStackView modifiers
extension UIStackView: ViewBuilderPaddable {
    
    public func setPadding(_ padding: UIEdgeInsets) {
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = padding
    }
    
}

extension UIStackView {
    
    public func addArrangedSubview(_ view: View) {
        addArrangedSubview(view())
    }
    
    public func addArrangedSubviews(_ views: View?...) {
        self.addArrangedSubviews(views)
    }

    public func addArrangedSubviews(_ views: [View?]) {
        for view in views {
            if let view = view {
                self.addArrangedSubview(view)
            }
        }
    }

    public func addViews(@ViewResultBuilder _ builder: () -> ViewConvertable) {
        builder().asViews().forEach { self.addArrangedSubview($0()) }
    }

    public func reset(to view: View) {
        empty()
        addArrangedSubview(view)
    }

    public func reset(to views: [View]) {
        empty()
        addArrangedSubviews(views)
    }
}

/// A custom subclass of `UIStackView` designed to interface smoothly with `ViewBuilder` lifecycle
/// events and handle custom padding safely.
public class BuilderInternalUIStackView: UIStackView, ViewBuilderRouteReceiving {

    override public func didMoveToWindow() {
        optionalBuilderAttributes()?.commonDidMoveToWindow(self)
    }

}
