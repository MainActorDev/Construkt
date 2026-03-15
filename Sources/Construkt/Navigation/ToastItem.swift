//
//  ToastItem.swift
//  Construkt
//

import UIKit

final class ToastItem {
    
    let id = UUID()
    let contentViewController: UIViewController
    let config: ToastConfiguration
    private var dismissWorkItem: DispatchWorkItem?
    
    var onDismiss: (() -> Void)?
    
    var view: UIView {
        contentViewController.view
    }
    
    init(content: UIViewController, config: ToastConfiguration) {
        self.contentViewController = content
        self.config = config
    }
    
    func scheduleAutoDismiss(after duration: TimeInterval, action: @escaping () -> Void) {
        dismissWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            action()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
    
    func cancelAutoDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }
}

extension ToastItem: Hashable {
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class ToastItemView: UIView {
    
    private let containerView = UIView()
    private let contentContainer = UIView()
    private var contentViewController: UIViewController?
    
    var onTap: (() -> Void)?
    
    init(config: ToastConfiguration) {
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        backgroundColor = .clear
        
        contentContainer.backgroundColor = .clear
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.layer.cornerRadius = 12
        contentContainer.clipsToBounds = true
        addSubview(contentContainer)
        
        NSLayoutConstraint.activate([
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            contentContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentContainer.topAnchor.constraint(equalTo: topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }
    
    func setContent(_ viewController: UIViewController, in parent: UIViewController?) {
        contentViewController?.view.removeFromSuperview()
        contentViewController?.removeFromParent()
        
        contentViewController = viewController
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(viewController.view)
        
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        parent?.addChild(viewController)
        viewController.didMove(toParent: parent)
    }
    
    @objc private func handleTap() {
        onTap?()
    }
}
