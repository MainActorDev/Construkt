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

/// Extension providing declarative subscription mapping to `UIControl` baseline configurations.
extension ModifiableView where Base: UIControl {

    /// Sets the horizontal alignment of the control's content.
    @discardableResult
    public func contentHorizontalAlignment(_ alignment: UIControl.ContentHorizontalAlignment) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.contentHorizontalAlignment, value: alignment)
    }

    /// Sets the vertical alignment of the control's content.
    @discardableResult
    public func contentVerticalAlignment(_ alignment: UIControl.ContentVerticalAlignment) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.contentVerticalAlignment, value: alignment)
    }

    /// Sets the `isEnabled` state of the control.
    @discardableResult
    public func enabled(_ enabled: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.isEnabled, value: enabled)
    }

    /// Sets the `isHighlighted` state of the control.
    @discardableResult
    public func highlighted(_ highlighted: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.isHighlighted, value: highlighted)
    }

    /// Sets the `isSelected` state of the control.
    @discardableResult
    public func selected(_ selected: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.isSelected, value: selected)
    }

}

/// Standard declarative ViewBindings for `UIControl` baseline state properties.
extension ModifiableView where Base: UIControl {

    /// Binds the `isEnabled` state to a reactive boolean stream.
    @discardableResult
    public func enabled<Binding:ViewBinding>(bind binding: Binding) -> ViewModifier<Base> where Binding.Value == Bool {
        ViewModifier(modifiableView, binding: binding) { $0.view.isEnabled = $0.value }
    }

    /// Binds the `isHighlighted` state to a reactive boolean stream.
    @discardableResult
    public func highlighted<Binding:ViewBinding>(bind binding: Binding) -> ViewModifier<Base> where Binding.Value == Bool {
        ViewModifier(modifiableView, binding: binding) { $0.view.isHighlighted = $0.value }
    }

    /// Binds the `isSelected` state to a reactive boolean stream.
    @discardableResult
    public func selected<Binding:ViewBinding>(bind binding: Binding) -> ViewModifier<Base> where Binding.Value == Bool {
        ViewModifier(modifiableView, binding: binding) { $0.view.isSelected = $0.value }
    }

}
