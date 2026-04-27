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

import Foundation
import UIKit

/// A builder component that wraps a `UITextField`, providing a declarative configuration interface
/// and bidirectional responsive bindings.
public struct TextField: ModifiableView {

    public let modifiableView: UITextField = Modified(UITextField()) {
        $0.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    public init(placeholder text: String?) {
        modifiableView.placeholder = text
    }

    public init(_ text: String?) {
        modifiableView.text = text
    }
    
    public init<Binding:ViewBinding>(_ binding: Binding) where Binding.Value == String? {
        text(bind: binding)
    }

    public init<Binding:MutableViewBinding>(_ binding: Binding) where Binding.Value == String {
        text(bidirectionalBind: binding)
    }

    public init<Binding:MutableViewBinding>(_ binding: Binding) where Binding.Value == String? {
        text(bidirectionalBind: binding)
    }

}


extension ModifiableView where Base: UITextField {

    /// Sets the auto-capitalization behavior.
    @discardableResult
    public func autocapitalizationType(_ type: UITextAutocapitalizationType) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.autocapitalizationType, value: type)
    }
    
    /// Sets the text color
    @discardableResult
    public func textColor(_ color: UIColor) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.textColor, value: color)
    }

    /// Sets the autocorrection behavior.
    @discardableResult
    public func autocorrectionType(_ type: UITextAutocorrectionType) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.autocorrectionType, value: type)
    }

    /// Prevents the return key until text is entered.
    @discardableResult
    public func enablesReturnKeyAutomatically(_ enabled: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.enablesReturnKeyAutomatically, value: enabled)
    }

    /// Provides a custom view to display in place of the standard system keyboard.
    @discardableResult
    public func inputView(_ view: UIView?) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.inputView, value: view)
    }

    /// Provides a custom accessory view acting as a toolbar above the system keyboard.
    @discardableResult
    public func inputAccessoryView(_ view: UIView?) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.inputAccessoryView, value: view)
    }

    /// Specifies the visual style of the keyboard layout.
    @discardableResult
    public func keyboardType(_ type: UIKeyboardType) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.keyboardType, value: type)
    }

    /// Sets the ghost text shown when the field is empty.
    @discardableResult
    public func placeholder(_ placeholder: String?) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.placeholder, value: placeholder)
    }

    @discardableResult
    public func returnKeyType(_ returnKeyType: UIReturnKeyType) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.returnKeyType, value: returnKeyType)
    }

    @discardableResult
    public func secureTextEntry(_ secure: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.isSecureTextEntry, value: secure)
    }

    @discardableResult
    public func textContentType(_ textContentType: UITextContentType) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.textContentType, value: textContentType)
    }

}

extension ModifiableView where Base: UITextField {

    @discardableResult
    public func text<Binding:ViewBinding>(bind binding: Binding) -> ViewModifier<Base> where Binding.Value == String? {
        ViewModifier(modifiableView, binding: binding, keyPath: \.text)
    }

    @discardableResult
    public func text<Binding:MutableViewBinding>(bidirectionalBind binding: Binding) -> ViewModifier<Base> where Binding.Value == String {
        ViewModifier(modifiableView) { textField in
            binding.observe(on: .main) { [weak textField] text in
                if textField?.text != text { textField?.text = text }
            }.store(in: textField.cancelBag)
            
            textField.addAction(UIAction { [weak textField] _ in
                let newText = textField?.text ?? ""
                if binding.wrappedValue != newText {
                    var mutableBinding = binding
                    mutableBinding.wrappedValue = newText
                }
            }, for: .editingChanged)
        }
    }

    @discardableResult
    public func text<Binding:MutableViewBinding>(bidirectionalBind binding: Binding) -> ViewModifier<Base> where Binding.Value == String? {
        ViewModifier(modifiableView) { textField in
            binding.observe(on: .main) { [weak textField] text in
                if textField?.text != text { textField?.text = text }
            }.store(in: textField.cancelBag)
            
            textField.addAction(UIAction { [weak textField] _ in
                let newText = textField?.text ?? ""
                if binding.wrappedValue != newText {
                    var mutableBinding = binding
                    mutableBinding.wrappedValue = newText
                }
            }, for: .editingChanged)
        }
    }
}


/// Extension providing declarative subscription mapping to `UITextField` control events.
extension ModifiableView where Base: UITextField {
    @discardableResult
    public func onControlEvent(_ event: UIControl.Event,
                               handler: @escaping (_ context: ViewBuilderValueContext<UITextField, String?>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { textField in
            textField.addAction(UIAction { [weak textField] _ in
                guard let view = textField else { return }
                handler(ViewBuilderValueContext(view: view, value: view.text))
            }, for: event)
        }
    }

    @discardableResult
    public func onChange(_ handler: @escaping (_ context: ViewBuilderValueContext<UITextField, String?>) -> Void) -> ViewModifier<Base> {
        onControlEvent(.editingChanged, handler: handler)
    }

    @discardableResult
    public func onEditingDidBegin(_ handler: @escaping (_ context: ViewBuilderValueContext<UITextField, String?>) -> Void) -> ViewModifier<Base> {
        onControlEvent(.editingDidBegin, handler: handler)
    }

    @discardableResult
    public func onEditingDidEnd(_ handler: @escaping (_ context: ViewBuilderValueContext<UITextField, String?>) -> Void) -> ViewModifier<Base> {
        onControlEvent(.editingDidEnd, handler: handler)
    }

    @discardableResult
    public func onEditingDidEndOnExit(_ handler: @escaping (_ context: ViewBuilderValueContext<UITextField, String?>) -> Void) -> ViewModifier<Base> {
        onControlEvent(.editingDidEndOnExit, handler: handler)
    }

}
