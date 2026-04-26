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

/// Context provided when a builder view is tapped.
public struct BuilderTapGestureContext<Base:UIView>: ViewBuilderContextProvider {
    public var view: Base
    public var gesture: UIGestureRecognizer
}

/// Context provided when a builder view is swiped.
public struct BuilderSwipeGestureContext<Base:UIView>: ViewBuilderContextProvider {
    public var view: Base
    public var gesture: UISwipeGestureRecognizer
}

/// Provides declarative gesture recognizers (e.g., taps, swipes) for all builder views.
extension ModifiableView {

    /// Adds a tap gesture recognizer to the view, enabling interaction.
    ///
    /// - Parameters:
    ///   - numberOfTaps: The number of taps required to trigger the handler. Defaults to 1.
    ///   - handler: A closure to execute when the gesture is recognized.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func onTapGesture(numberOfTaps: Int = 1, _ handler: @escaping (_ context: BuilderTapGestureContext<Base>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
            let gesture = UITapGestureRecognizer()
            gesture.numberOfTapsRequired = numberOfTaps
            view.addGestureRecognizer(gesture)
            view.isUserInteractionEnabled = true
            
            let target = NativeGestureTarget(gesture: gesture) { [weak view, weak gesture] _ in
                guard let view = view, let gesture = gesture else { return }
                handler(BuilderTapGestureContext(view: view, gesture: gesture))
            }
            view.cancelBag.insert(target)
        }
    }

    /// Adds a swipe left gesture recognizer to the view.
    ///
    /// - Parameter handler: A closure to execute when the gesture is recognized.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func onSwipeLeft(_ handler: @escaping (_ context: BuilderSwipeGestureContext<Base>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
            let gesture = UISwipeGestureRecognizer()
            gesture.direction = .left
            view.addGestureRecognizer(gesture)
            view.isUserInteractionEnabled = true
            
            let target = NativeGestureTarget(gesture: gesture) { [weak view, weak gesture] _ in
                guard let view = view, let gesture = gesture else { return }
                handler(BuilderSwipeGestureContext(view: view, gesture: gesture))
            }
            view.cancelBag.insert(target)
        }
    }

    /// Adds a swipe right gesture recognizer to the view.
    ///
    /// - Parameter handler: A closure to execute when the gesture is recognized.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func onSwipeRight(_ handler: @escaping (_ context: BuilderSwipeGestureContext<Base>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
            let gesture = UISwipeGestureRecognizer()
            gesture.direction = .right
            view.addGestureRecognizer(gesture)
            view.isUserInteractionEnabled = true
            
            let target = NativeGestureTarget(gesture: gesture) { [weak view, weak gesture] _ in
                guard let view = view, let gesture = gesture else { return }
                handler(BuilderSwipeGestureContext(view: view, gesture: gesture))
            }
            view.cancelBag.insert(target)
        }
    }

    /// Adds a swipe up gesture recognizer to the view.
    ///
    /// - Parameter handler: A closure to execute when the gesture is recognized.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func onSwipeUp(_ handler: @escaping (_ context: BuilderSwipeGestureContext<Base>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
            let gesture = UISwipeGestureRecognizer()
            gesture.direction = .up
            view.addGestureRecognizer(gesture)
            view.isUserInteractionEnabled = true
            
            let target = NativeGestureTarget(gesture: gesture) { [weak view, weak gesture] _ in
                guard let view = view, let gesture = gesture else { return }
                handler(BuilderSwipeGestureContext(view: view, gesture: gesture))
            }
            view.cancelBag.insert(target)
        }
    }

    /// Adds a swipe down gesture recognizer to the view.
    ///
    /// - Parameter handler: A closure to execute when the gesture is recognized.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func onSwipeDown(_ handler: @escaping (_ context: BuilderSwipeGestureContext<Base>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
            let gesture = UISwipeGestureRecognizer()
            gesture.direction = .down
            view.addGestureRecognizer(gesture)
            view.isUserInteractionEnabled = true
            
            let target = NativeGestureTarget(gesture: gesture) { [weak view, weak gesture] _ in
                guard let view = view, let gesture = gesture else { return }
                handler(BuilderSwipeGestureContext(view: view, gesture: gesture))
            }
            view.cancelBag.insert(target)
        }
    }

    /// Adds a tap gesture recognizing background views to hide the keyboard.
    ///
    /// - Parameter cancelsTouchesInView: Whether the gesture should cancel underlying touches. Defaults to `true`.
    /// - Returns: A modified view wrapper.
    @discardableResult
    public func hideKeyboardOnBackgroundTap(cancelsTouchesInView: Bool = true) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
            let gesture = UITapGestureRecognizer()
            gesture.numberOfTapsRequired = 1
            gesture.cancelsTouchesInView = cancelsTouchesInView
            view.addGestureRecognizer(gesture)
            
            let target = NativeGestureTarget(gesture: gesture) { [weak view] _ in
                view?.endEditing(true)
            }
            view.cancelBag.insert(target)
        }
    }
}

private final class NativeGestureTarget<T: UIGestureRecognizer>: NSObject, AnyCancellableLifecycle {
    let handler: (T) -> Void
    var gesture: T?
    
    init(gesture: T, handler: @escaping (T) -> Void) {
        self.handler = handler
        self.gesture = gesture
        super.init()
        gesture.addTarget(self, action: #selector(handleGesture))
    }
    
    @objc func handleGesture(_ recognizer: UIGestureRecognizer) {
        if let g = recognizer as? T {
            handler(g)
        }
    }
    
    func cancel() {
        if let g = gesture {
            g.removeTarget(self, action: #selector(handleGesture))
        }
    }
}
