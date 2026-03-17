//
//  LifecycleDebugExport.swift
//  Construkt Demo
//

import Foundation
import UIKit
import ConstruktKit

struct SystemInfo: Codable {
    let os: String
    let device: String
    let appVersion: String
    let buildNumber: String
    let debug: Bool
}

struct Summary: Codable {
    let active: Int
    let inactive: Int
    let suspectedLeaks: Int
    let likelyLeaks: Int
    let confirmedLeaks: Int
}

struct ActiveItemExport: Codable {
    let id: String
    let label: String?
    let age: TimeInterval
    let severity: String
    let source: String
    let createdAt: Date
    let stackTrace: [String]
}

struct InactiveItemExport: Codable {
    let id: String
    let label: String?
    let lifetime: TimeInterval
    let contentViewDeallocated: Bool
    let registryDeallocated: Bool
    let createdAt: Date
    let deallocatedAt: Date
}

struct LifecycleDebugExportData: Codable {
    let exportedAt: Date
    let system: SystemInfo
    let summary: Summary
    let active: [ActiveItemExport]
    let inactive: [InactiveItemExport]
}

enum LifecycleDebugExport {
    static func generate() -> LifecycleDebugExportData {
        let activeInfos = LifecycleHostTracker.shared.activeControllerInfos
        let inactiveInfos = LifecycleHostTracker.shared.inactiveControllerInfos
        
        let config = LifecycleHostTracker.shared.configuration
        let thresholds = config.severityThresholds
        
        var activeItems: [ActiveItemExport] = []
        var suspectedCount = 0
        var likelyCount = 0
        var confirmedCount = 0
        
        for info in activeInfos {
            let severity: String
            if info.age >= thresholds.confirmed {
                severity = "confirmed"
                confirmedCount += 1
            } else if info.age >= thresholds.likely {
                severity = "likely"
                likelyCount += 1
            } else if info.age >= thresholds.suspected {
                severity = "suspected"
                suspectedCount += 1
            } else {
                severity = "healthy"
            }
            
            activeItems.append(ActiveItemExport(
                id: info.id.uuidString,
                label: info.label,
                age: info.age,
                severity: severity,
                source: "\(info.sourceFile):\(info.sourceLine)",
                createdAt: info.createdAt,
                stackTrace: info.stackTrace
            ))
        }
        
        let inactiveItems = inactiveInfos.map { info in
            InactiveItemExport(
                id: info.id.uuidString,
                label: info.label,
                lifetime: info.lifetime,
                contentViewDeallocated: info.contentViewDeallocated,
                registryDeallocated: info.registryDeallocated,
                createdAt: info.createdAt,
                deallocatedAt: info.deallocatedAt
            )
        }
        
        let systemInfo = SystemInfo(
            os: UIDevice.current.systemVersion,
            device: UIDevice.current.model,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            debug: true
        )
        
        let summary = Summary(
            active: activeItems.count,
            inactive: inactiveItems.count,
            suspectedLeaks: suspectedCount,
            likelyLeaks: likelyCount,
            confirmedLeaks: confirmedCount
        )
        
        return LifecycleDebugExportData(
            exportedAt: Date(),
            system: systemInfo,
            summary: summary,
            active: activeItems,
            inactive: inactiveItems
        )
    }
    
    static func copyToClipboard(_ data: LifecycleDebugExportData) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let jsonData = try? encoder.encode(data) else { return }
        
        UIPasteboard.general.string = String(data: jsonData, encoding: .utf8)
    }
}
