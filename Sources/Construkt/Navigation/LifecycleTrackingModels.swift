//
//  LifecycleTrackingModels.swift
//  Construkt
//

import Foundation
import UIKit

public enum LeakSeverity: Int, Comparable, Sendable {
    case suspected = 0
    case likely = 1
    case confirmed = 2
    
    public static func < (lhs: LeakSeverity, rhs: LeakSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ActiveControllerInfo: Sendable {
    public let id: UUID
    public let label: String?
    public let createdAt: Date
    public let stackTrace: [String]
    public let sourceFile: String
    public let sourceLine: Int
    
    public var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
    
    public init(
        id: UUID,
        label: String?,
        createdAt: Date,
        stackTrace: [String],
        sourceFile: String,
        sourceLine: Int
    ) {
        self.id = id
        self.label = label
        self.createdAt = createdAt
        self.stackTrace = stackTrace
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
    }
}

public struct DeallocatedControllerInfo: Sendable {
    public let id: UUID
    public let label: String?
    public let createdAt: Date
    public let deallocatedAt: Date
    public let contentViewDeallocated: Bool
    public let registryDeallocated: Bool
    public let stackTrace: [String]
    public let sourceFile: String
    public let sourceLine: Int
    
    public var lifetime: TimeInterval {
        deallocatedAt.timeIntervalSince(createdAt)
    }
    
    public init(
        id: UUID,
        label: String?,
        createdAt: Date,
        deallocatedAt: Date,
        contentViewDeallocated: Bool,
        registryDeallocated: Bool,
        stackTrace: [String],
        sourceFile: String,
        sourceLine: Int
    ) {
        self.id = id
        self.label = label
        self.createdAt = createdAt
        self.deallocatedAt = deallocatedAt
        self.contentViewDeallocated = contentViewDeallocated
        self.registryDeallocated = registryDeallocated
        self.stackTrace = stackTrace
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
    }
}

public struct LeakWarning: Sendable {
    public let controllerId: UUID
    public let label: String?
    public let age: TimeInterval
    public let stackTrace: [String]
    public let sourceFile: String
    public let sourceLine: Int
    public let severity: LeakSeverity
    public let contentViewHeld: Bool
    public let registryHeld: Bool
    
    public var displayName: String {
        label ?? "Unnamed Controller"
    }
    
    public var formattedAge: String {
        let minutes = Int(age) / 60
        let seconds = Int(age) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    public var debugDescription: String {
        let heldDependencies: [String] = [
            contentViewHeld ? "contentView" : nil,
            registryHeld ? "registry" : nil
        ].compactMap { $0 }
        
        let depsString = heldDependencies.isEmpty ? "" : " (dependencies held: \(heldDependencies.joined(separator: ", ")))"
        
        return """
        [CONSTRUKT] LEAK \(severityString): \(displayName) - alive for \(formattedAge)\(depsString)
          Created at: \(sourceFile):\(sourceLine)
          Stack trace:
        \(stackTrace.prefix(8).map { "    \($0)" }.joined(separator: "\n"))
        """
    }
    
    private var severityString: String {
        switch severity {
        case .suspected: return "SUSPECTED"
        case .likely: return "LIKELY"
        case .confirmed: return "CONFIRMED"
        }
    }
    
    public init(
        controllerId: UUID,
        label: String?,
        age: TimeInterval,
        stackTrace: [String],
        sourceFile: String,
        sourceLine: Int,
        severity: LeakSeverity,
        contentViewHeld: Bool,
        registryHeld: Bool
    ) {
        self.controllerId = controllerId
        self.label = label
        self.age = age
        self.stackTrace = stackTrace
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
        self.severity = severity
        self.contentViewHeld = contentViewHeld
        self.registryHeld = registryHeld
    }
}

struct ControllerTrackingContext {
    weak var controller: LifecycleHostController?
    let info: ActiveControllerInfo
    weak var contentView: UIView?
    weak var registry: ViewLifecycleRegistry?
    
    init(
        controller: LifecycleHostController,
        info: ActiveControllerInfo,
        contentView: UIView?,
        registry: ViewLifecycleRegistry?
    ) {
        self.controller = controller
        self.info = info
        self.contentView = contentView
        self.registry = registry
    }
}
