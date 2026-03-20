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
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN//
//  Builder+Bindings.swift
//  Construkt
//
//  Created for Construkt core.
//

import UIKit

// MARK: - ModifiableView Extensions

extension ViewModifier {
    
    /// Initializes a modifier that executes a generic closure whenever the provided sequence emits.
    public init<B:ViewBinding, T>(_ view: Base, binding: B, handler: @escaping (_ context: ViewBuilderValueContext<Base, T>) -> Void) where B.Value == T {
        self.modifiableView = view
        binding.observe(on: .main) { [weak view] value in
            if let view = view {
                handler(ViewBuilderValueContext(view: view, value: value))
            }
        }.store(in: view.cancelBag)
    }

    /// Initializes a modifier that executes a closure whenever the provided sequence emits,
    /// injecting an unretained target safely.
    public init<B:ViewBinding, T, Target: AnyObject>(_ view: Base, binding: B, on target: Target, handler: @escaping (_ target: Target, _ context: ViewBuilderValueContext<Base, T>) -> Void) where B.Value == T {
        self.modifiableView = view
        binding.observe(on: .main) { [weak view, weak target] value in
            guard let view = view, let target = target else { return }
            handler(target, ViewBuilderValueContext(view: view, value: value))
        }.store(in: view.cancelBag)
    }
        
    /// Initializes a modifier that binds a reactive sequence output directly into a property key path on the underlying view.
    public init<B:ViewBinding, T:Equatable>(_ view: Base, binding: B, keyPath: ReferenceWritableKeyPath<Base, T>) where B.Value == T {
        self.modifiableView = view
        binding.observe(on: .main) { [weak view] value in
            if let view = view, view[keyPath: keyPath] != value {
                view[keyPath: keyPath] = value
            }
        }.store(in: view.cancelBag)
    }

}

extension ModifiableView {

    /// Binds a reactive stream to a valid keypath on the underlying view.
    @discardableResult
    public func bind<B: ViewBinding, T: Equatable>(_ keyPath: ReferenceWritableKeyPath<Base, T>, to binding: B) -> ViewModifier<Base> where B.Value == T {
        ViewModifier(modifiableView, binding: binding, keyPath: keyPath)
    }

    /// Executes a generic closure contextually linked to the bounded view whenever an event is received on the specific stream.
    @discardableResult
    public func onReceive<B: ViewBinding, T>(_ binding: B, _ handler: @escaping (_ context: ViewBuilderValueContext<Base, T>) -> Void) -> ViewModifier<Base> where B.Value == T {
        ViewModifier(modifiableView, binding: binding, handler: handler)
    }

    /// Executes a generic closure contextually linked to the bounded view whenever an event is received,
    /// while injecting an unretained target safely.
    @discardableResult
    public func onReceive<B: ViewBinding, T, Target: AnyObject>(_ binding: B, on target: Target, _ handler: @escaping (_ target: Target, _ context: ViewBuilderValueContext<Base, T>) -> Void) -> ViewModifier<Base> where B.Value == T {
        ViewModifier(modifiableView, binding: binding, on: target, handler: handler)
    }

    /// Binds a structural toggle specifically mapping its `isHidden` trait onto an inverse boolean stream.
    @discardableResult
    public func hidden<B: ViewBinding>(when binding: B) -> ViewModifier<Base> where B.Value == Bool {
        ViewModifier(modifiableView, binding: binding, keyPath: \.isHidden)
    }
    
    /// Binds a structural toggle tracking an `isUserInteractionEnabled` trait onto an external logic stream.
    @discardableResult
    public func userInteractionEnabled<B: ViewBinding>(when binding: B) -> ViewModifier<Base> where B.Value == Bool {
        ViewModifier(modifiableView, binding: binding, keyPath: \.isUserInteractionEnabled)
    }
}
