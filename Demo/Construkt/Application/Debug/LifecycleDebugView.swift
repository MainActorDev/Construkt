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
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(scrollContent)
        
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        contentView = scrollContent
    }
    
    private func buildContent() -> UIView {
        let header = buildHeader()
        let activeSection = buildActiveSection()
        let inactiveSection = buildInactiveSection()
        let actionBar = buildActionBar()
        
        let stack = UIStackView(arrangedSubviews: [header, activeSection, inactiveSection, actionBar])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        return stack
    }
    
    private func buildHeader() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "Lifecycle Debug"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        
        let icon = UIImageView(image: UIImage(systemName: "wrench.and.screwdriver"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        
        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshData), for: .touchUpInside)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.systemBlue, for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        doneButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, UIView(), refreshButton, doneButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        container.addSubview(stack)
        stack.pinToSuperviewEdges(insets: .init(top: 12, left: 16, bottom: 12, right: 16))
        
        return container
    }
    
    private func buildActiveSection() -> UIView {
        let indicator = UIView()
        indicator.backgroundColor = .systemGreen
        indicator.layer.cornerRadius = 4
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([indicator.widthAnchor.constraint(equalToConstant: 8), indicator.heightAnchor.constraint(equalToConstant: 8)])
        
        let title = UILabel()
        title.text = "ACTIVE (\(activeItems.count))"
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .systemGreen
        
        let headerStack = UIStackView(arrangedSubviews: [indicator, title])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        
        var items: [UIView] = [headerStack]
        
        if activeItems.isEmpty {
            items.append(buildEmptyState(icon: "checkmark.circle", message: "No active controllers"))
        } else {
            for item in activeItems.sorted(by: { $0.age > $1.age }) {
                items.append(buildActiveItemRow(item))
            }
        }
        
        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        container.layer.cornerRadius = 12
        container.addSubview(stack)
        stack.pinToSuperviewEdges(insets: .init(top: 12, left: 12, bottom: 12, right: 12))
        
        return container
    }
    
    private func buildActiveItemRow(_ item: ActiveControllerInfo) -> UIView {
        let severity = severityInfo(for: item)
        
        let icon = UIImageView(image: UIImage(systemName: severity.icon))
        icon.tintColor = severity.color
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 16), icon.heightAnchor.constraint(equalToConstant: 16)])
        
        let nameLabel = UILabel()
        nameLabel.text = item.label ?? "Unnamed"
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .white
        
        let sourceLabel = UILabel()
        sourceLabel.text = "\(item.sourceFile):\(item.sourceLine)"
        sourceLabel.font = .systemFont(ofSize: 12)
        sourceLabel.textColor = .gray
        
        let labelStack = UIStackView(arrangedSubviews: [nameLabel, sourceLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        
        let ageLabel = UILabel()
        ageLabel.text = formattedAge(item.age)
        ageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        ageLabel.textColor = severity.color
        
        let traceButton = UIButton(type: .system)
        traceButton.setTitle("Trace", for: .normal)
        traceButton.setTitleColor(.systemBlue, for: .normal)
        traceButton.titleLabel?.font = .systemFont(ofSize: 12)
        traceButton.tag = activeItems.firstIndex(where: { $0.id == item.id }) ?? 0
        traceButton.addTarget(self, action: #selector(showTrace(_:)), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [icon, labelStack, UIView(), ageLabel, traceButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        
        let container = UIView()
        container.addSubview(stack)
        stack.pinToSuperviewEdges(insets: .init(top: 8, left: 0, bottom: 8, right: 0))
        
        return container
    }
    
    private func buildInactiveSection() -> UIView {
        let indicator = UIView()
        indicator.backgroundColor = .gray
        indicator.layer.cornerRadius = 4
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([indicator.widthAnchor.constraint(equalToConstant: 8), indicator.heightAnchor.constraint(equalToConstant: 8)])
        
        let title = UILabel()
        title.text = "INACTIVE (\(inactiveItems.count))"
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .gray
        
        let headerStack = UIStackView(arrangedSubviews: [indicator, title])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        
        var items: [UIView] = [headerStack]
        
        if inactiveItems.isEmpty {
            items.append(buildEmptyState(icon: "archivebox", message: "No deallocated controllers"))
        } else {
            for item in inactiveItems.sorted(by: { $0.deallocatedAt > $1.deallocatedAt }) {
                items.append(buildInactiveItemRow(item))
            }
        }
        
        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        container.layer.cornerRadius = 12
        container.addSubview(stack)
        stack.pinToSuperviewEdges(insets: .init(top: 12, left: 12, bottom: 12, right: 12))
        
        return container
    }
    
    private func buildInactiveItemRow(_ item: DeallocatedControllerInfo) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle"))
        icon.tintColor = .systemGreen
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 16), icon.heightAnchor.constraint(equalToConstant: 16)])
        
        let nameLabel = UILabel()
        nameLabel.text = item.label ?? "Unnamed"
        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .white
        
        let lifetimeLabel = UILabel()
        lifetimeLabel.text = "Lived: \(formattedLifetime(item.lifetime))"
        lifetimeLabel.font = .systemFont(ofSize: 12)
        lifetimeLabel.textColor = .gray
        
        let labelStack = UIStackView(arrangedSubviews: [nameLabel, lifetimeLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        
        let cvIcon = UIImageView(image: UIImage(systemName: item.contentViewDeallocated ? "checkmark.circle" : "exclamationmark.triangle"))
        cvIcon.tintColor = item.contentViewDeallocated ? .systemGreen : .systemOrange
        cvIcon.contentMode = .scaleAspectFit
        cvIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([cvIcon.widthAnchor.constraint(equalToConstant: 12), cvIcon.heightAnchor.constraint(equalToConstant: 12)])
        
        let cvLabel = UILabel()
        cvLabel.text = "CV"
        cvLabel.font = .systemFont(ofSize: 10)
        cvLabel.textColor = .gray
        
        let regIcon = UIImageView(image: UIImage(systemName: item.registryDeallocated ? "checkmark.circle" : "exclamationmark.triangle"))
        regIcon.tintColor = item.registryDeallocated ? .systemGreen : .systemOrange
        regIcon.contentMode = .scaleAspectFit
        regIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([regIcon.widthAnchor.constraint(equalToConstant: 12), regIcon.heightAnchor.constraint(equalToConstant: 12)])
        
        let regLabel = UILabel()
        regLabel.text = "Reg"
        regLabel.font = .systemFont(ofSize: 10)
        regLabel.textColor = .gray
        
        let cvStack = UIStackView(arrangedSubviews: [cvIcon, cvLabel])
        cvStack.axis = .horizontal
        cvStack.spacing = 2
        
        let regStack = UIStackView(arrangedSubviews: [regIcon, regLabel])
        regStack.axis = .horizontal
        regStack.spacing = 2
        
        let depsStack = UIStackView(arrangedSubviews: [cvStack, regStack])
        depsStack.axis = .horizontal
        depsStack.spacing = 8
        
        let stack = UIStackView(arrangedSubviews: [icon, labelStack, UIView(), depsStack])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        
        let container = UIView()
        container.addSubview(stack)
        stack.pinToSuperviewEdges(insets: .init(top: 8, left: 0, bottom: 8, right: 0))
        
        return container
    }
    
    private func buildEmptyState(icon: String, message: String) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .gray
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([iconView.widthAnchor.constraint(equalToConstant: 32), iconView.heightAnchor.constraint(equalToConstant: 32)])
        
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gray
        
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        
        let container = UIView()
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])
        
        return container
    }
    
    private func buildActionBar() -> UIView {
        let forceCheckButton = buildActionButton(title: "Force Check", color: .systemOrange, action: #selector(forceCheck))
        let exportButton = buildActionButton(title: "Export", color: .systemBlue, action: #selector(exportData))
        let clearButton = buildActionButton(title: "Clear", color: .systemRed, action: #selector(clearHistory))
        
        let stack = UIStackView(arrangedSubviews: [forceCheckButton, exportButton, clearButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        
        return stack
    }
    
    private func buildActionButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = color
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([button.heightAnchor.constraint(equalToConstant: 44)])
        return button
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
    
    @objc private func refreshData() {
        activeItems = LifecycleHostTracker.shared.activeControllerInfos
        inactiveItems = LifecycleHostTracker.shared.inactiveControllerInfos
        
        let newContent = buildContent()
        contentView?.removeFromSuperview()
        view.addSubview(newContent)
        newContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newContent.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            newContent.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newContent.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        contentView = newContent
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    @objc private func showTrace(_ sender: UIButton) {
        let index = sender.tag
        guard index < activeItems.count else { return }
        let item = activeItems[index]
        
        let stackTrace = item.stackTrace.prefix(10).joined(separator: "\n")
        let alert = UIAlertController(title: item.label ?? "Stack Trace", message: stackTrace, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy", style: .default, handler: { _ in
            UIPasteboard.general.string = stackTrace
        }))
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func forceCheck() {
        let warnings = LifecycleHostTracker.shared.checkForLeaks()
        refreshData()
        
        let message = warnings.isEmpty ? "No leaks detected ✓" : "Found \(warnings.count) potential leak(s)"
        showAlert(title: "Check Complete", message: message)
    }
    
    @objc private func exportData() {
        let data = LifecycleDebugExport.generate()
        LifecycleDebugExport.copyToClipboard(data)
        showAlert(title: "Exported", message: "Copied \(data.active.count) active, \(data.inactive.count) inactive to clipboard")
    }
    
    @objc private func clearHistory() {
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

private extension UIView {
    func pinToSuperviewEdges(insets: UIEdgeInsets = .zero) {
        guard let superview = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -insets.bottom),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -insets.right)
        ])
    }
}
