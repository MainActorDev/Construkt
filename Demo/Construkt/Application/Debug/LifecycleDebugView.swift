//
//  LifecycleDebugView.swift
//  Construkt Demo
//

import UIKit
import ConstruktKit

@MainActor
final class LifecycleDebugViewController: UIViewController {
    private var activeItems: [ActiveControllerInfo] = []
    private var inactiveItems: [DeallocatedControllerInfo] = []
    private let config: LifecycleTrackerConfiguration
    private var contentView: UIView?
    
    init(config: LifecycleTrackerConfiguration) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        refreshData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.08, alpha: 1.0)
        setupUI()
    }
    
    private func setupUI() {
        let scrollContent = buildContent()
        
        let scrollView = VerticalScrollView(scrollContent)
            .build()
        
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        contentView = scrollView
    }
    
    private func buildContent() -> UIView {
        VStackView(spacing: 16) {
            buildHeader()
            buildActiveSection()
            buildInactiveSection()
            buildActionBar()
        }
        .padding(16)
        .build()
    }
    
    private func buildHeader() -> UIView {
        HStackView(spacing: 12) {
            ImageView(systemName: "wrench.and.screwdriver")
                .tintColor(.white)
                .size(width: 24, height: 24)
            
            LabelView("Lifecycle Debug")
                .font(.systemFont(ofSize: 20, weight: .bold))
                .color(.white)
            
            SpacerView()
            
            ButtonView("Refresh") { [weak self] _ in
                self?.refreshData()
            }
            .font(.systemFont(ofSize: 14))
            .color(.white)
            
            ButtonView("Done") { [weak self] _ in
                self?.dismiss(animated: true)
            }
            .font(.systemFont(ofSize: 16, weight: .semibold))
            .color(.systemBlue)
        }
        .padding(h: 16, v: 12)
        .backgroundColor(UIColor(white: 0.15, alpha: 1.0))
        .build()
    }
    
    private func buildActiveSection() -> UIView {
        let headerStack = HStackView(spacing: 8) {
            ContainerView()
                .backgroundColor(.systemGreen)
                .cornerRadius(4)
                .size(width: 8, height: 8)
            
            LabelView("ACTIVE (\(activeItems.count))")
                .font(.systemFont(ofSize: 14, weight: .semibold))
                .color(.systemGreen)
        }
        
        var items: [ViewConvertable] = [headerStack]
        
        if activeItems.isEmpty {
            items.append(buildEmptyStateConvertible(icon: "checkmark.circle", message: "No active controllers"))
        } else {
            for item in activeItems.sorted(by: { $0.age > $1.age }) {
                items.append(buildActiveItemRowConvertible(item))
            }
        }
        
        return VStackView(items)
            .spacing(8)
            .padding(12)
            .backgroundColor(UIColor(white: 0.12, alpha: 1.0))
            .cornerRadius(12)
            .build()
    }
    
    private func buildActiveItemRow(_ item: ActiveControllerInfo) -> UIView {
        return buildActiveItemRowConvertible(item).asViews().first!.build()
    }
    
    private func buildActiveItemRowConvertible(_ item: ActiveControllerInfo) -> ViewConvertable {
        let severity = severityInfo(for: item)
        
        return HStackView(spacing: 12) {
            ImageView(systemName: severity.icon)
                .tintColor(severity.color)
                .size(width: 16, height: 16)
            
            VStackView(spacing: 2) {
                LabelView(item.label ?? "Unnamed")
                    .font(.systemFont(ofSize: 15, weight: .medium))
                    .color(.white)
                
                LabelView("\(item.sourceFile):\(item.sourceLine)")
                    .font(.systemFont(ofSize: 12))
                    .color(.gray)
            }
            
            SpacerView()
            
            LabelView(formattedAge(item.age))
                .font(.systemFont(ofSize: 14, weight: .medium))
                .color(severity.color)
            
            ButtonView("Trace") { [weak self] _ in
                self?.showTrace(for: item)
            }
            .font(.systemFont(ofSize: 12))
            .color(.systemBlue)
        }
        .padding(h: 0, v: 8)
    }
    
    private func buildInactiveSection() -> UIView {
        let headerStack = HStackView(spacing: 8) {
            ContainerView()
                .backgroundColor(.gray)
                .cornerRadius(4)
                .size(width: 8, height: 8)
            
            LabelView("INACTIVE (\(inactiveItems.count))")
                .font(.systemFont(ofSize: 14, weight: .semibold))
                .color(.gray)
        }
        
        var items: [ViewConvertable] = [headerStack]
        
        if inactiveItems.isEmpty {
            items.append(buildEmptyStateConvertible(icon: "archivebox", message: "No deallocated controllers"))
        } else {
            for item in inactiveItems.sorted(by: { $0.deallocatedAt > $1.deallocatedAt }) {
                items.append(buildInactiveItemRowConvertible(item))
            }
        }
        
        return VStackView(items)
            .spacing(8)
            .padding(12)
            .backgroundColor(UIColor(white: 0.12, alpha: 1.0))
            .cornerRadius(12)
            .build()
    }
    
    private func buildInactiveItemRow(_ item: DeallocatedControllerInfo) -> UIView {
        return buildInactiveItemRowConvertible(item).asViews().first!.build()
    }
    
    private func buildInactiveItemRowConvertible(_ item: DeallocatedControllerInfo) -> ViewConvertable {
        let cvIconName = item.contentViewDeallocated ? "checkmark.circle" : "exclamationmark.triangle"
        let cvColor: UIColor = item.contentViewDeallocated ? .systemGreen : .systemOrange
        
        let regIconName = item.registryDeallocated ? "checkmark.circle" : "exclamationmark.triangle"
        let regColor: UIColor = item.registryDeallocated ? .systemGreen : .systemOrange
        
        return HStackView(spacing: 12) {
            ImageView(systemName: "checkmark.circle")
                .tintColor(.systemGreen)
                .size(width: 16, height: 16)
            
            VStackView(spacing: 2) {
                LabelView(item.label ?? "Unnamed")
                    .font(.systemFont(ofSize: 15, weight: .medium))
                    .color(.white)
                
                LabelView("Lived: \(formattedLifetime(item.lifetime))")
                    .font(.systemFont(ofSize: 12))
                    .color(.gray)
            }
            
            SpacerView()
            
            HStackView(spacing: 8) {
                HStackView(spacing: 2) {
                    ImageView(systemName: cvIconName)
                        .tintColor(cvColor)
                        .size(width: 12, height: 12)
                    LabelView("CV")
                        .font(.systemFont(ofSize: 10))
                        .color(.gray)
                }
                
                HStackView(spacing: 2) {
                    ImageView(systemName: regIconName)
                        .tintColor(regColor)
                        .size(width: 12, height: 12)
                    LabelView("Reg")
                        .font(.systemFont(ofSize: 10))
                        .color(.gray)
                }
            }
        }
        .padding(h: 0, v: 8)
    }
    
    private func buildEmptyState(icon: String, message: String) -> UIView {
        return buildEmptyStateConvertible(icon: icon, message: message).asViews().first!.build()
    }
    
    private func buildEmptyStateConvertible(icon: String, message: String) -> ViewConvertable {
        VStackView(spacing: 8) {
            ImageView(systemName: icon)
                .tintColor(.gray)
                .size(width: 32, height: 32)
            
            LabelView(message)
                .font(.systemFont(ofSize: 14))
                .color(.gray)
        }
        .padding(h: 0, v: 24)
    }
    
    private func buildActionBar() -> UIView {
        HStackView(spacing: 12) {
            buildActionButton(title: "Force Check", color: .systemOrange) { [weak self] in
                self?.forceCheck()
            }
            
            buildActionButton(title: "Export", color: .systemBlue) { [weak self] in
                self?.exportData()
            }
            
            buildActionButton(title: "Clear", color: .systemRed) { [weak self] in
                self?.clearHistory()
            }
        }
        .distribution(.fillEqually)
        .build()
    }
    
    private func buildActionButton(title: String, color: UIColor, action: @escaping () -> Void) -> UIView {
        ButtonView(title) { _ in
            action()
        }
        .font(.systemFont(ofSize: 14, weight: .medium))
        .color(.white)
        .backgroundColor(color)
        .cornerRadius(8)
        .height(44)
        .build()
    }
    
    private func severityInfo(for item: ActiveControllerInfo) -> (icon: String, color: UIColor) {
        let thresholds = config.severityThresholds
        if item.age >= thresholds.confirmed {
            return ("xmark.octagon.fill", .systemRed)
        } else if item.age >= thresholds.likely {
            return ("exclamationmark.circle.fill", .systemRed)
        } else if item.age >= thresholds.suspected {
            return ("exclamationmark.triangle.fill", .systemOrange)
        }
        return ("checkmark.circle.fill", .systemGreen)
    }
    
    private func formattedAge(_ age: TimeInterval) -> String {
        let seconds = Int(age)
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
    
    private func formattedLifetime(_ lifetime: TimeInterval) -> String {
        let seconds = Int(lifetime)
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
    
    private func refreshData() {
        activeItems = LifecycleHostTracker.shared.activeControllerInfos
        inactiveItems = LifecycleHostTracker.shared.inactiveControllerInfos
        
        let newContent = buildContent()
        contentView?.removeFromSuperview()
        
        let scrollView = VerticalScrollView(newContent).build()
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        contentView = scrollView
    }
    
    private func showTrace(for item: ActiveControllerInfo) {
        let stackTrace = item.stackTrace.prefix(10).joined(separator: "\n")
        let alert = UIAlertController(title: item.label ?? "Stack Trace", message: stackTrace, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy", style: .default, handler: { _ in
            UIPasteboard.general.string = stackTrace
        }))
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }
    
    private func forceCheck() {
        let warnings = LifecycleHostTracker.shared.checkForLeaks()
        refreshData()
        
        let message = warnings.isEmpty ? "No leaks detected ✓" : "Found \(warnings.count) potential leak(s)"
        showAlert(title: "Check Complete", message: message)
    }
    
    private func exportData() {
        let data = LifecycleDebugExport.generate()
        LifecycleDebugExport.copyToClipboard(data)
        showAlert(title: "Exported", message: "Copied \(data.active.count) active, \(data.inactive.count) inactive to clipboard")
    }
    
    private func clearHistory() {
        LifecycleHostTracker.shared.clearHistory()
        refreshData()
        showAlert(title: "Cleared", message: "History cleared")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
