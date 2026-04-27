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


/// A declarative builder component that constructs a multidirectional `UIScrollView`.
public struct ScrollView: ModifiableView {
    
    public var modifiableView = Modified(BuilderInternalScrollView(frame: UIScreen.main.bounds)) {
        $0.delegate = $0
    }

    public init(_ view: View?, padding: UIEdgeInsets? = nil, safeArea: Bool = false) {
        guard let view = view else { return }
        modifiableView.views = [view]
        modifiableView.padding = padding ?? .zero
        modifiableView.safeArea = safeArea
    }

    public init(padding: UIEdgeInsets? = nil, safeArea: Bool = false, @ViewResultBuilder _ builder: () -> ViewConvertable) {
        modifiableView.views = builder()
        modifiableView.padding = padding ?? .zero
        modifiableView.safeArea = safeArea
    }

}

extension ModifiableView where Base: BuilderInternalScrollView {

    /// Automatically binds to keyboard notifications to squeeze the scroll view insets appropriately.
    @discardableResult
    @available(iOS 12, *)
    public func automaticallyAdjustForKeyboard() -> ViewModifier<Base> {
        ViewModifier(modifiableView) { scrollView in
            let center = NotificationCenter.default
            
            let hideObserver = center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak scrollView] _ in
                scrollView?.contentInset = .zero
                scrollView?.scrollIndicatorInsets = .zero
            }
            
            let showObserver = center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak scrollView] notification in
                guard let scrollView = scrollView else { return }
                guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

                let keyboardScreenEndFrame = keyboardValue.cgRectValue
                let keyboardViewEndFrame = scrollView.convert(keyboardScreenEndFrame, from: scrollView.window)
                let bottom = keyboardViewEndFrame.height - scrollView.safeAreaInsets.bottom
                let oldInsets = scrollView.contentInset

                scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
                scrollView.scrollIndicatorInsets = scrollView.contentInset

                if oldInsets.bottom == 0, let textfield = scrollView.firstSubview(where: { $0 is UITextField && $0.isFirstResponder }) {
                    DispatchQueue.main.async {
                        textfield.scrollIntoView()
                    }
                }
            }
            
            scrollView.cancelBag.insert(NotificationToken(token: hideObserver))
            scrollView.cancelBag.insert(NotificationToken(token: showObserver))
        }
    }

    /// Sets whether the scroll view bounces past the edge of content and back again.
    @discardableResult
    public func bounces(_ bounce: Bool) -> ViewModifier<Base> {
        ViewModifier(modifiableView, keyPath: \.bounces, value: bounce)
    }

    /// Handler triggered dynamically whenever the scroll view updates its internal offset.
    @discardableResult
    public func onDidScroll(_ handler: @escaping (_ context: ViewBuilderContext<UIScrollView>) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.scrollViewDidScrollHandler = handler }
    }
  
    /// Sets whether the vertical scroll indicator is visible.
    @discardableResult
    public func showVerticalIndicator(_ show: Bool) -> ViewModifier<Base> {
      ViewModifier(modifiableView, keyPath: \.showsVerticalScrollIndicator, value: show)
    }

    /// Sets whether the horizontal scroll indicator is visible.
    @discardableResult
    public func showHorizontalIndicator(_ show: Bool) -> ViewModifier<Base> {
      ViewModifier(modifiableView, keyPath: \.showsHorizontalScrollIndicator, value: show)
    }

}

/// A declarative builder component that constructs a `UIScrollView` locked to vertical scrolling.
///
/// It implicitly ensures its child views match the scroll view's width.
public struct VerticalScrollView: ModifiableView {
    
    public var modifiableView = Modified(BuilderVerticalScrollView(frame: UIScreen.main.bounds)) {
        $0.delegate = $0
    }

    public init(_ view: View?, padding: UIEdgeInsets? = nil, safeArea: Bool = false) {
        guard let view = view else { return }
        modifiableView.embed(view, padding: padding, safeArea: safeArea)
    }

    public init(padding: UIEdgeInsets? = nil, safeArea: Bool = false, @ViewResultBuilder _ builder: () -> ViewConvertable) {
        modifiableView.views = builder()
        modifiableView.padding = padding ?? .zero
        modifiableView.safeArea = safeArea
    }

}

public class BuilderInternalScrollView: UIScrollView, UIScrollViewDelegate {

    public var scrollViewDidScrollHandler: ((_ context: ViewBuilderContext<UIScrollView>) -> Void)?

    fileprivate var views: ViewConvertable?
    fileprivate var padding: UIEdgeInsets = .zero
    fileprivate var position: EmbedPosition = .fill
    fileprivate var safeArea: Bool = false

    @objc public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewDidScrollHandler?(ViewBuilderContext(view: self))
    }

    override public func didMoveToWindow() {
        optionalBuilderAttributes()?.commonDidMoveToWindow(self)
    }

    override public func didMoveToSuperview() {
        embed(views?.asViews() ?? [], padding: padding, safeArea: safeArea)
        super.didMoveToSuperview()
    }

}

public class BuilderVerticalScrollView: BuilderInternalScrollView {

    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        subviews.forEach { superview?.widthAnchor.constraint(equalTo: $0.widthAnchor).isActive = true }
    }

}

private struct NotificationToken: AnyCancellableLifecycle {
    let token: NSObjectProtocol
    func cancel() { NotificationCenter.default.removeObserver(token) }
}
