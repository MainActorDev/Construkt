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

/// A protocol representing a collection of `View` components that can be indexed and observed for updates.
public protocol AnyIndexableViewBuilder: ViewConvertable {
    /// The number of built views.
    var count: Int { get }
    /// An observable stream that emits whenever the underlying data structure reloads views.
    var updated: Signal<Void>? { get }
    /// Provides the constructed `View` at the specified index.
    func view(at index: Int) -> View?
}

/// A fixed-size builder collection wrapping statically defined declarative `View` structures.
public struct StaticViewBuilder: AnyIndexableViewBuilder {

    private var views: [View]

    public init(@ViewResultBuilder _ views: () -> ViewConvertable) {
        self.views = views().asViews()
    }

    public var count: Int { views.count }
    public var updated: Signal<Void>?

    public func view(at index: Int) -> View? {
        guard views.indices.contains(index) else { return nil }
        return views[index]
    }

    public func asViews() -> [View] {
        views
    }

}

/// A reactive builder component that maps an array of `Item` elements to a dynamic list of views.
/// Used commonly to bind datasets to standard `UIView` stacks or wrappers natively without a collection view.
public class DynamicItemViewBuilder<Item>: AnyIndexableViewBuilder {

    public var items: [Item] {
        didSet {
            updatePublisher.send(())
        }
    }

    public var count: Int { items.count }
    public var updated: Signal<Void>? { updatePublisher }

    private let updatePublisher = Signal<Void>()
    private let builder: (_ item: Item) -> View?

    public init(_ items: [Item]?, builder: @escaping (_ item: Item) -> View?) {
        self.items = items ?? []
        self.builder = builder
    }

    public func item(at index: Int) -> Item? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    public func view(at index: Int) -> View? {
        guard let item = item(at: index) else { return nil }
        return builder(item)
    }

    public func asViews() -> [View] {
        return items.compactMap { self.builder($0) }
    }

}

/// A reactive builder component that maps a `ViewBinding` emission to a dynamically rebuilt view.
public class DynamicObservableViewBuilder<Value>: AnyIndexableViewBuilder {

    public var count: Int { view == nil ? 0 : 1 }
    /// An observable stream that triggers upon the underlying generic observable changing state.
    public var updated: Signal<Void>? { updatePublisher }

    private let updatePublisher = Signal<Void>()
    private var view: View?
    private let cancelBag = CancelBag()

    /// Initializes a builder that tracks an observable property dynamically rendering it into a single `View`.
    public init<Binding:ViewBinding>(_ binding: Binding, builder: @escaping (_ value: Value) -> View?)
    where Binding.Value == Value {
        binding.observe(on: .main) { [weak self] value in
            self?.view = builder(value)
            self?.updatePublisher.send(())
        }.store(in: cancelBag)
    }

    public func view(at index: Int) -> View? {
        guard index == 0 else { return nil }
        return view
    }

    public func asViews() -> [View] {
        guard let view = view else { return [] }
        return [view]
    }

}

/// A reactive builder component that monitors a local `value` setter to trigger reactive downstream view rebuilds.
public class DynamicValueViewBuilder<Value>: AnyIndexableViewBuilder {

    public var value: Value {
        didSet {
            updatePublisher.send(())
        }
    }

    public var count: Int = 1
    public var updated: Signal<Void>? { updatePublisher }

    private let updatePublisher = Signal<Void>()
    private let builder: (_ value: Value) -> View

    public init(_ value: Value, builder: @escaping (_ value: Value) -> View) {
        self.value = value
        self.builder = builder
    }

    public func view(at index: Int) -> View? {
        guard index == 0 else { return nil }
        return builder(value)
    }

    public func asViews() -> [View] {
        return [builder(value)]
    }

}
