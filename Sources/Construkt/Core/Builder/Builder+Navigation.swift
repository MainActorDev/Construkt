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

/// Extends `UINavigationController` for simple SwiftUI-like push transitions.
extension UINavigationController {

    /// Pushes a declarative `View` onto the receiver’s stack.
    @discardableResult
    public func push(view: View, animated: Bool) -> Self {
        pushViewController(UIViewController(view), animated: animated)
        return self
    }

}

/// Standard modifiers for any `ModifiableView` allowing navigation attributes natively.
extension ModifiableView {

    /// Dynamically sets the navigation item's title when this view appears in a navigation stack.
    @discardableResult
    public func navigation(title: String?) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.builderAttributes()?.onAppearOnceHandlers.append({ context in
                context.navigationItem?.title = title
            })
        }
    }

}

/// Extends `UIBarButtonItem` to support modern, declarative initialization and reactive click bindings.
extension UIBarButtonItem {

    /// Creates a bar button item with a standard system item icon.
    convenience public init(barButtonSystemItem systemItem: UIBarButtonItem.SystemItem) {
        self.init(barButtonSystemItem: systemItem, target: nil, action: nil)
    }

    /// Creates a bar button item with a custom image.
    convenience public init(image: UIImage?, style: UIBarButtonItem.Style) {
        self.init(image: image, style: style, target: nil, action: nil)
    }

    /// Creates a bar button item with a text title.
    convenience public init(title: String?, style: UIBarButtonItem.Style) {
        self.init(title: title, style: style, target: nil, action: nil)
    }

    /// Attaches a native tap handler to the bar button item.
    @discardableResult
    public func onTap(_ handler: @escaping (_ item: UIBarButtonItem) -> Void) -> Self {
        let action = UIAction { [weak self] _ in
            guard let self = self else { return }
            handler(self)
        }
        self.primaryAction = action
        return self
    }

}
