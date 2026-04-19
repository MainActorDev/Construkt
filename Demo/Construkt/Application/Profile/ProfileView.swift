//
//  ProfileView.swift
//  Construkt
//

import UIKit
import ConstruktKit

enum ProfileSection: String, SectionConfigIdentifier {
    case hero
    case premium
    case general
    case account
    case version
    
    var uniqueId: String { rawValue }
}

struct ProfileView: ViewConvertable {
    static let navigationTitle = "Account"
    
    // MARK: - Body
    
    func asViews() -> [View] {
        Screen {
            CollectionView {
                heroSection
                premiumSection
                generalSettingsSection
                accountSettingsSection
                versionSection
            }
        }
        .backgroundColor(UIColor("#0A0A0A"))
        .asViews()
    }
    
    // MARK: - Sections
    
    private var heroSection: AnySection {
        AnySection(id: ProfileSection.hero) {
            AnyCell("hero", id: "hero") { _ in
                ProfileHeroSection()
            }
        }
        .layout {
            .list(itemHeight: .estimated(200))
            .insets(top: 80, leading: 24, bottom: 32, trailing: 24)
        }
    }
    
    private var premiumSection: AnySection {
        AnySection(id: ProfileSection.premium) {
            AnyCell("premium", id: "premium") { _ in
                ProfilePremiumBanner()
            }
        }
        .layout {
            .list(itemHeight: .estimated(80))
            .insets(top: 0, leading: 24, bottom: 32, trailing: 24)
        }
    }
    
    private var generalSettingsSection: AnySection {
        AnySection(id: ProfileSection.general) {
            Header {
                LabelView("GENERAL")
                    .color(UIColor("#737373"))
                    .font(.systemFont(ofSize: 12, weight: .medium))
            }
            
            AnyCell("downloads", id: "downloads") { _ in
                ProfileSettingsRow(
                    icon: "arrow.down.circle",
                    title: "Downloads",
                    rightView: HStackView {
                        VStackView {
                            LabelView("4.2 GB")
                                .color(UIColor("#737373"))
                                .font(.systemFont(ofSize: 10, weight: .regular))
                                .alignment(.right)
                            LabelView("used")
                                .color(UIColor("#525252"))
                                .font(.systemFont(ofSize: 10, weight: .regular))
                                .alignment(.right)
                        }
                        .spacing(0)
                        
                        ImageView(UIImage(systemName: "chevron.right"))
                            .tintColor(UIColor("#525252"))
                    }
                    .spacing(8),
                    isLast: false
                )
            }
            
            AnyCell("notifications", id: "notifications") { _ in
                ProfileSettingsToggle(icon: "bell", title: "Notifications", isOn: true, isLast: false)
            }
            
            AnyCell("darkMode", id: "darkMode") { _ in
                ProfileSettingsToggle(icon: "moon", title: "Dark Mode", isOn: false, isLast: true)
            }
        }
        .onSelect { (item: String) in
            switch item {
            case "downloads": print("Downloads tapped")
            case "notifications": print("Notifications tapped")
            case "darkMode": print("Dark Mode tapped")
            default: break
            }
        }
        .layout {
            .list(itemHeight: .estimated(56))
            .insets(.init(v: 24, h: 24))
            .supplementaryHeader(height: .estimated(30))
        }
        .backgroundDecoration(id: "general", insets: .init(top: 32, leading: 24, bottom: 24, trailing: 24)) {
            ContainerView()
                .backgroundColor(UIColor(white: 0.1, alpha: 0.3))
                .cornerRadius(16)
                .border(color: UIColor(white: 1, alpha: 0.05), lineWidth: 1)
        }
    }
    
    private var accountSettingsSection: AnySection {
        AnySection(id: ProfileSection.account) {
            Header {
                LabelView("ACCOUNT")
                    .color(UIColor("#737373"))
                    .font(.systemFont(ofSize: 12, weight: .medium))
            }
            
            AnyCell("payment", id: "payment") { _ in
                ProfileSettingsRow(
                    icon: "creditcard",
                    title: "Payment Methods",
                    rightView: ImageView(UIImage(systemName: "chevron.right"))
                        .tintColor(UIColor("#525252")),
                    isLast: false
                )
            }
            
            AnyCell("security", id: "security") { _ in
                ProfileSettingsRow(
                    icon: "exclamationmark.shield",
                    title: "Security",
                    rightView: ImageView(UIImage(systemName: "chevron.right"))
                        .tintColor(UIColor("#525252")),
                    isLast: false
                )
            }
            
            AnyCell("logout", id: "logout") { _ in
                ProfileSettingsRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Log Out",
                    titleColor: UIColor("#f43f5e"),
                    iconColor: UIColor("#f43f5e").withAlphaComponent(0.8),
                    rightView: nil,
                    isLast: true
                )
            }
        }
        .onSelect { (item: String) in
            switch item {
            case "payment": print("Payment Methods tapped")
            case "security": print("Security tapped")
            case "logout": print("Log Out tapped")
            default: break
            }
        }
        .layout {
            .list(itemHeight: .estimated(56))
            .insets(.init(v: 24, h: 24))
            .supplementaryHeader(height: .estimated(30))
        }
        .backgroundDecoration(id: "account", insets: .init(top: 32, leading: 24, bottom: 24, trailing: 24)) {
            ContainerView()
                .backgroundColor(UIColor(white: 0.1, alpha: 0.3))
                .cornerRadius(16)
                .border(color: UIColor(white: 1, alpha: 0.05), lineWidth: 1)
        }
    }
    
    private var versionSection: AnySection {
        AnySection(id: ProfileSection.version) {
            AnyCell("version", id: "version") { _ in
                ProfileVersionInfo()
            }
        }
        .layout {
            .list(itemHeight: .estimated(40))
            .insets(top: 0, leading: 24, bottom: 100, trailing: 24)
        }
    }
}
