import UIKit
import ConstruktKit

enum LeakWarningToast {
    @MainActor
    static func show(_ warning: LeakWarning) {
        guard let window = keyWindow() else { return }
        
        let severityColor: UIColor
        let severityIcon: String
        switch warning.severity {
        case .suspected:
            severityColor = .systemOrange
            severityIcon = "exclamationmark.triangle.fill"
        case .likely:
            severityColor = .systemRed
            severityIcon = "exclamationmark.circle.fill"
        case .confirmed:
            severityColor = .systemRed
            severityIcon = "xmark.octagon.fill"
        }
        
        let heldDeps: [String] = [
            warning.contentViewHeld ? "contentView" : nil,
            warning.registryHeld ? "registry" : nil
        ].compactMap { $0 }
        
        let depsText = heldDeps.isEmpty ? "" : " [\(heldDeps.joined(separator: ", "))]"
        let message = "⚠️ LEAK: \(warning.displayName) (\(warning.formattedAge))\(depsText)"
        
        let config = ToastConfiguration.topPop()
        let content = ViewPresentable {
            HStackView(spacing: 10) {
                ImageView(systemName: severityIcon)
                    .tintColor(severityColor)
                    .size(width: 20, height: 20)
                
                LabelView(message)
                    .font(.systemFont(ofSize: 13, weight: .medium))
                    .color(.white)
                    .numberOfLines(2)
            }
            .padding(h: 14, v: 12)
            .backgroundColor(UIColor(white: 0.15, alpha: 0.95))
            .cornerRadius(10)
            .clipsToBounds(true)
        }
        
        ToastManager.shared.show(content: content.toPresentable(), config: config, in: window)
    }
    
    @MainActor
    private static func keyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
}
