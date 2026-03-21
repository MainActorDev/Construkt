//
//  LifecycleHostController.swift
//  Construkt
//

import UIKit

/// A specialized structure designed exclusively to bind Builder Host lifecycle events to declarative closures.
public class ViewLifecycleRegistry {
    var onLoad: (() -> Void)?
    var onAppear: ((Bool) -> Void)?
    var onDisappear: ((Bool) -> Void)?

    func clearCallbacks() {
        onLoad = nil
        onAppear = nil
        onDisappear = nil
    }
}

private struct AssociatedKeys {
    static var lifecycleKey: UInt8 = 0
}

/// Specialized ViewModifier extension to capture true UIViewController lifecycles
extension ModifiableView {
    
    // Uses an internal associated object to store the closures before the view is mounted to the host
    private func getRegistry() -> ViewLifecycleRegistry {
        if let registry = objc_getAssociatedObject(self.modifiableView, &AssociatedKeys.lifecycleKey) as? ViewLifecycleRegistry {
            return registry
        }
        let registry = ViewLifecycleRegistry()
        objc_setAssociatedObject(self.modifiableView, &AssociatedKeys.lifecycleKey, registry, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return registry
    }

    /// Triggers when the mounting UIViewController fires `viewDidLoad`
    @discardableResult
    public func onHostDidLoad(_ action: @escaping () -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.getRegistry().onLoad = action }
    }

    /// Triggers when the mounting UIViewController fires `viewDidLoad` while weakly referencing a target.
    @discardableResult
    public func onHostDidLoad<Target: AnyObject>(on target: Target, _ action: @escaping (_ target: Target) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.getRegistry().onLoad = { [weak target] in
                guard let target else { return }
                action(target)
            }
        }
    }

    /// Triggers when the mounting UIViewController fires `viewWillAppear`
    @discardableResult
    public func onHostWillAppear(_ action: @escaping (_ animated: Bool) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.getRegistry().onAppear = action }
    }

    /// Triggers when the mounting UIViewController fires `viewWillAppear` while weakly referencing a target.
    @discardableResult
    public func onHostWillAppear<Target: AnyObject>(on target: Target, _ action: @escaping (_ target: Target, _ animated: Bool) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.getRegistry().onAppear = { [weak target] animated in
                guard let target else { return }
                action(target, animated)
            }
        }
    }
    
    /// Triggers when the mounting UIViewController fires `viewWillDisappear`
    @discardableResult
    public func onHostWillDisappear(_ action: @escaping (_ animated: Bool) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { $0.getRegistry().onDisappear = action }
    }

    /// Triggers when the mounting UIViewController fires `viewWillDisappear` while weakly referencing a target.
    @discardableResult
    public func onHostWillDisappear<Target: AnyObject>(on target: Target, _ action: @escaping (_ target: Target, _ animated: Bool) -> Void) -> ViewModifier<Base> {
        ViewModifier(modifiableView) {
            $0.getRegistry().onDisappear = { [weak target] animated in
                guard let target else { return }
                action(target, animated)
            }
        }
    }
}

/// The actual View Controller that catches genuine UIKit lifecycles and forwards them to the declarative View
open class LifecycleHostController: UIViewController {
    private let contentView: UIView
    private weak var trackedContentView: UIView?
    private weak var trackedRegistry: ViewLifecycleRegistry?
    internal var trackingId: UUID?
    internal var hadParent: Bool = false
    private var trackingLabel: String?
    
    public convenience init(contentView: UIView, trackingLabel: String? = nil) {
        self.init(contentView: contentView, trackingLabel: trackingLabel, file: #file, line: #line)
    }
    
    internal init(contentView: UIView, trackingLabel: String?, file: String, line: Int) {
        self.contentView = contentView
        self.trackingLabel = trackingLabel
        
        super.init(nibName: nil, bundle: nil)
        
        guard let trackingLabel = trackingLabel else { return }
        
        let registry = objc_getAssociatedObject(contentView, &AssociatedKeys.lifecycleKey) as? ViewLifecycleRegistry
        LifecycleHostTracker.shared.register(
            self,
            label: trackingLabel,
            contentView: contentView,
            registry: registry,
            file: file,
            line: line
        )
        
        if LifecycleHostTracker.shared.configuration.isEnabled {
            trackedContentView = contentView
            trackedRegistry = registry
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if LifecycleHostTracker.shared.configuration.isEnabled, trackingId != nil {
            LifecycleHostTracker.shared.reportDealloc(self)
        }
    }
    
    public override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        if parent != nil {
            hadParent = true
        }
        
        if parent == nil && hadParent && trackingId != nil {
            LifecycleHostTracker.shared.scheduleImmediateCheck(after: 2.0)
        }

        if parent == nil && hadParent {
            clearLifecycleRegistry()
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: self.view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        let registry = objc_getAssociatedObject(contentView, &AssociatedKeys.lifecycleKey) as? ViewLifecycleRegistry
        registry?.onLoad?()
        registry?.onLoad = nil
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let registry = objc_getAssociatedObject(contentView, &AssociatedKeys.lifecycleKey) as? ViewLifecycleRegistry
        registry?.onAppear?(animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let registry = objc_getAssociatedObject(contentView, &AssociatedKeys.lifecycleKey) as? ViewLifecycleRegistry
        registry?.onDisappear?(animated)
    }

    private func clearLifecycleRegistry() {
        guard let registry = objc_getAssociatedObject(contentView, &AssociatedKeys.lifecycleKey) as? ViewLifecycleRegistry else { return }
        registry.clearCallbacks()
        objc_setAssociatedObject(contentView, &AssociatedKeys.lifecycleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

/// Allows ANY pure Construkt declarative View struct to be pushed directly onto a Navigation stack.
extension ViewConvertable {
    /// Packages the declarative view into a `LifecycleHostController`, returning it as a UIViewController.
    /// - Parameters:
    ///   - title: The title for the view controller.
    ///   - trackingLabel: Optional label for memory leak tracking. If nil, memory tracking is disabled for this instance.
    /// - Returns: A UIViewController ready for presentation.
    public func toPresentable(title: String? = nil, trackingLabel: String? = nil) -> UIViewController {
        toPresentable(title: title, trackingLabel: trackingLabel, file: #file, line: #line)
    }
    
    internal func toPresentable(title: String?, trackingLabel: String?, file: String, line: Int) -> UIViewController {
        let views = self.asViews()
        let view: UIView
        if views.count == 1 {
            view = views[0].build()
        } else {
            view = UIView()
            views.forEach { abstractView in
                let uiView = abstractView.build()
                uiView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(uiView)
                NSLayoutConstraint.activate([
                    uiView.topAnchor.constraint(equalTo: view.topAnchor),
                    uiView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    uiView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    uiView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                ])
            }
        }
        let host = LifecycleHostController(contentView: view, trackingLabel: trackingLabel, file: file, line: line)
        host.title = title
        return host
    }
}
