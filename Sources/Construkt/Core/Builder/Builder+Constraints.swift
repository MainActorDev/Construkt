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

/// Provides declarative layout bindings (e.g., width, height, priorities) mapping to AutoLayout constraints.
extension ModifiableView {
    
    /// Sets the compression resistance priority for the specified axis.
    ///
    /// - Parameters:
    ///   - priority: The layout priority.
    ///   - axis: The axis (`.horizontal` or `.vertical`).
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func contentCompressionResistancePriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.setContentCompressionResistancePriority(priority, for: axis) }
    }
    
    /// Sets the content hugging priority for the specified axis.
    ///
    /// - Parameters:
    ///   - priority: The layout priority.
    ///   - axis: The axis (`.horizontal` or `.vertical`).
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func contentHuggingPriority(_ priority: UILayoutPriority, for axis: NSLayoutConstraint.Axis) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.setContentHuggingPriority(priority, for: axis)
        }
    }
    
    /// Applies exact width and height constraints to the view.
    ///
    /// - Parameters:
    ///   - height: The optional explicit height.
    ///   - width: The optional explicit width.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func frame(height: CGFloat? = nil, width: CGFloat? = nil) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            if let height = height {
                $0.heightAnchor
                    .constraint(equalToConstant: height)
                    .priority(UILayoutPriority(rawValue: 999))
                    .identifier("height")
                    .activate()
            }
            if let width = width {
                $0.widthAnchor
                    .constraint(equalToConstant: width)
                    .priority(UILayoutPriority(rawValue: 999))
                    .identifier("width")
                    .activate()
            }
        }
    }
    
    /// Constrains the height of the view exactly to the specified constant.
    ///
    /// - Parameter height: The height constant.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func height(_ height: CGFloat) -> ViewModifier<Base> {
        self.height(height, priority: UILayoutPriority(999))
    }
    
    /// Constrains both the width and height of the view to exact constants.
    @discardableResult
    public func size(width: CGFloat, height: CGFloat) -> ViewModifier<Base> {
        self.width(width).height(height)
    }
    
    /// Constrains the height of the view at a specific priority (float form).
    @discardableResult
    public func height(_ height: CGFloat, priority: Float) -> ViewModifier<Base> {
        self.height(height, priority: UILayoutPriority(priority))
    }
    
    /// Constrains the height of the view at a specific `UILayoutPriority`.
    @discardableResult
    public func height(_ height: CGFloat, priority: UILayoutPriority) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.heightAnchor
                .constraint(equalToConstant: height)
                .priority(priority)
                .identifier("height")
                .activate()
        }
    }
    
    /// Constrains the view to a minimum height.
    @discardableResult
    public func height(min height: CGFloat, priority: UILayoutPriority = UILayoutPriority(rawValue: 999)) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.heightAnchor
                .constraint(greaterThanOrEqualToConstant: height)
                .priority(priority)
                .identifier("minheight")
                .activate()
        }
    }
    
    /// Constrains the view to a maximum height.
    @discardableResult
    public func height(max height: CGFloat, priority: UILayoutPriority = UILayoutPriority(rawValue: 999)) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.heightAnchor
                .constraint(lessThanOrEqualToConstant: height)
                .priority(priority)
                .identifier("maxheight")
                .activate()
        }
    }
    
    /// Constrains the width of the view to an exact constant.
    ///
    /// - Parameter width: The defined width.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func width(_ width: CGFloat) -> ViewModifier<Base> {
        self.width(width, priority: UILayoutPriority(999))
    }
    
    /// Constrains the width of the view to a constant at a specific priority (float form).
    ///
    /// - Parameters:
    ///   - width: The width constant.
    ///   - priority: The layout priority raw value.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func width(_ width: CGFloat, priority: Float) -> ViewModifier<Base> {
        self.width(width, priority: UILayoutPriority(priority))
    }
    
    /// Constrains the width of the view to a constant at a specific constraint priority.
    ///
    /// - Parameters:
    ///   - width: The defined width.
    ///   - priority: An explicit `UILayoutPriority`.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func width(_ width: CGFloat, priority: UILayoutPriority) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.widthAnchor
                .constraint(equalToConstant: width)
                .priority(priority)
                .identifier("width")
                .activate()
        }
    }
    
    /// Restricts the view bounds horizontally enforcing a minimum width.
    ///
    /// - Parameters:
    ///   - width: The minimum width constant.
    ///   - priority: The layout priority, defaulting to 999.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func width(min width: CGFloat, priority: UILayoutPriority = UILayoutPriority(rawValue: 999)) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.widthAnchor
                .constraint(greaterThanOrEqualToConstant: width)
                .priority(priority)
                .identifier("minwidth")
                .activate()
        }
    }
    
    /// Constrains the view to a maximum width.
    @discardableResult
    public func width(max width: CGFloat, priority: UILayoutPriority = UILayoutPriority(rawValue: 999)) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.widthAnchor
                .constraint(lessThanOrEqualToConstant: width)
                .priority(priority)
                .identifier("maxwidth")
                .activate()
        }
    }
    
    /// Sets the z-axis position of the view's layer, controlling visual stacking order.
    @discardableResult
    public func zIndex(_ position: CGFloat) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.layer.zPosition = position }
    }
}

extension UIView {
    
    public enum EmbedPosition {
        case fill
        case top
        case topLeft
        case topCenter
        case topRight
        case left
        case center
        case centerLeft
        case centerRight
        case right
        case bottom
        case bottomLeft
        case bottomCenter
        case bottomRight
    }
    
    public func embed(_ view: View, padding: UIEdgeInsets? = nil, safeArea: Bool = false) {
        addConstrainedSubview(view(), position: .fill, padding: padding ?? .zero, safeArea: safeArea)
    }
    
    public func embed(_ views: [View], padding: UIEdgeInsets? = nil, safeArea: Bool = false) {
        views.forEach { self.addConstrainedSubview($0(), position: .fill, padding: padding ?? .zero, safeArea: safeArea) }
    }
    
    public func addConstrainedSubview(_ view: UIView, position: EmbedPosition, padding: UIEdgeInsets, safeArea: Bool = false) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        addConstraints(view, position: position, padding: padding, safeArea: safeArea)
    }
    
    public func insertConstrainedSubview(_ view: UIView, at index: Int, position: EmbedPosition, padding: UIEdgeInsets, safeArea: Bool = false) {
        view.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(view, at: index)
        addConstraints(view, position: position, padding: padding, safeArea: safeArea)
    }
    
    // all embedding and inserts flow here...
    
    private func addConstraints(_ view: UIView, position: EmbedPosition, padding: UIEdgeInsets, safeArea: Bool) {
        // check for builder overrides
        let attributes = view.optionalBuilderAttributes()
        if let constraints = attributes?.customConstraints {
            constraints(view)
        } else {
            let position = attributes?.position ?? position
            let padding = attributes?.insets ?? padding
            let safeArea = attributes?.safeArea ?? safeArea
            addVerticalConstraints(view, position: position, padding: padding, safeArea: safeArea)
            addHorizontalConstraints(view, position: position, padding: padding, safeArea: safeArea)
        }
    }
    
    private func addVerticalConstraints(_ view: UIView, position: EmbedPosition, padding: UIEdgeInsets, safeArea: Bool) {
        let guides: UIViewAnchoring = safeArea ? safeAreaLayoutGuide : self
        
        if [EmbedPosition.center, .centerLeft, .centerRight].contains(position) {
            view.centerYAnchor.constraint(equalTo: guides.centerYAnchor)
                .identifier("centerY")
                .activate()
        } else {
            // top
            if [EmbedPosition.fill, .top, .left, .right, .topLeft, .topCenter, .topRight].contains(position) {
                view.topAnchor.constraint(equalTo: guides.topAnchor, constant: padding.top)
                    .identifier("top")
                    .activate()
            } else {
                view.topAnchor.constraint(lessThanOrEqualTo: guides.topAnchor, constant: padding.top)
                    .priority(.defaultHigh)
                    .identifier("top")
                    .activate()
            }
            
            // bottom
            if [EmbedPosition.fill, .bottom, .left, .right, .bottomLeft, .bottomCenter, .bottomRight].contains(position) {
                view.bottomAnchor.constraint(equalTo: guides.bottomAnchor, constant: -padding.bottom)
                    .identifier("bottom")
                    .activate()
            } else {
                view.bottomAnchor.constraint(greaterThanOrEqualTo: guides.bottomAnchor, constant: -padding.bottom)
                    .priority(.defaultHigh)
                    .identifier("bottom")
                    .activate()
            }
        }
    }
    
    private func addHorizontalConstraints(_ view: UIView, position: EmbedPosition, padding: UIEdgeInsets, safeArea: Bool = false) {
        let guides: UIViewAnchoring = safeArea ? safeAreaLayoutGuide : self
        
        if [EmbedPosition.center, .topCenter, .bottomCenter].contains(position) {
            view.centerXAnchor.constraint(equalTo: guides.centerXAnchor)
                .identifier("centerX")
                .activate()
        } else {
            // left
            if [EmbedPosition.fill, .left, .top, .bottom, .topLeft, .centerLeft, .bottomLeft].contains(position) {
                view.leftAnchor.constraint(equalTo: guides.leftAnchor, constant: padding.left)
                    .identifier("left")
                    .activate()
            } else {
                view.leftAnchor.constraint(lessThanOrEqualTo: guides.leftAnchor, constant: padding.left)
                    .priority(.defaultHigh)
                    .identifier("left")
                    .activate()
            }
            
            // right
            if [EmbedPosition.fill, .right, .top, .bottom, .topRight, .centerRight, .bottomRight].contains(position) {
                view.rightAnchor.constraint(equalTo: guides.rightAnchor, constant: -padding.right)
                    .identifier("right")
                    .activate()
            } else {
                view.rightAnchor.constraint(greaterThanOrEqualTo: guides.rightAnchor, constant: -padding.right)
                    .priority(.defaultHigh)
                    .identifier("right")
                    .activate()
            }
        }
    }
    
}

private protocol UIViewAnchoring {
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var leftAnchor: NSLayoutXAxisAnchor { get }
    var rightAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var widthAnchor: NSLayoutDimension { get }
    var heightAnchor: NSLayoutDimension { get }
    var centerXAnchor: NSLayoutXAxisAnchor { get }
    var centerYAnchor: NSLayoutYAxisAnchor { get }
}

extension UILayoutGuide: UIViewAnchoring {}
extension UIView: UIViewAnchoring {}

extension NSLayoutConstraint {
    /// Activates or deactivates this constraint and returns `self` for chaining.
    @discardableResult
    public func activate(_ isActive: Bool = true) -> Self {
        self.isActive = isActive
        return self
    }
    /// Sets a debug identifier on this constraint and returns `self` for chaining.
    @discardableResult
    public func identifier(_ identifier: String?) -> Self {
        self.identifier = identifier
        return self
    }
    /// Sets the layout priority on this constraint and returns `self` for chaining.
    @discardableResult
    public func priority(_ priority: UILayoutPriority) -> Self {
        self.priority = priority
        return self
    }
    /// Sets the layout priority using a raw float value and returns `self` for chaining.
    @discardableResult
    public func priority(_ priority: Float) -> Self {
        self.priority = UILayoutPriority(rawValue: priority)
        return self
    }
}
