//
//  LifecycleTrackerConfiguration.swift
//  Construkt
//

import Foundation

public enum DebugTrigger: String, Sendable, CaseIterable {
    case shake
    case threeFingerLongPress
    case disabled
}

public struct LifecycleTrackerConfiguration: Sendable {
    public var isEnabled: Bool
    public var leakThreshold: TimeInterval
    public var checkInterval: TimeInterval
    public var retainHistoryCount: Int
    public var logToConsole: Bool
    public var assertOnLeak: Bool
    public var debugTrigger: DebugTrigger
    public var onLeakDetected: (@Sendable (LeakWarning) -> Void)?
    
    public init(
        isEnabled: Bool = false,
        leakThreshold: TimeInterval = 5,
        checkInterval: TimeInterval = 10,
        retainHistoryCount: Int = 50,
        logToConsole: Bool = true,
        assertOnLeak: Bool = true,
        debugTrigger: DebugTrigger = .shake,
        onLeakDetected: (@Sendable (LeakWarning) -> Void)? = nil
    ) {
        self.isEnabled = isEnabled
        self.leakThreshold = leakThreshold
        self.checkInterval = checkInterval
        self.retainHistoryCount = retainHistoryCount
        self.logToConsole = logToConsole
        self.assertOnLeak = assertOnLeak
        self.debugTrigger = debugTrigger
        self.onLeakDetected = onLeakDetected
    }
    
    public static let disabled = LifecycleTrackerConfiguration(isEnabled: false)
    
    public static let enabled = LifecycleTrackerConfiguration(
        isEnabled: true,
        leakThreshold: 5,
        checkInterval: 10,
        retainHistoryCount: 50,
        logToConsole: true,
        assertOnLeak: true,
        debugTrigger: .shake,
        onLeakDetected: nil
    )
    
    public static func enabled(
        leakThreshold: TimeInterval = 5,
        checkInterval: TimeInterval = 10,
        retainHistoryCount: Int = 50,
        logToConsole: Bool = true,
        assertOnLeak: Bool = false,
        debugTrigger: DebugTrigger = .shake,
        onLeakDetected: (@Sendable (LeakWarning) -> Void)? = nil
    ) -> LifecycleTrackerConfiguration {
        LifecycleTrackerConfiguration(
            isEnabled: true,
            leakThreshold: leakThreshold,
            checkInterval: checkInterval,
            retainHistoryCount: retainHistoryCount,
            logToConsole: logToConsole,
            assertOnLeak: assertOnLeak,
            debugTrigger: debugTrigger,
            onLeakDetected: onLeakDetected
        )
    }
}

extension LifecycleTrackerConfiguration {
    public var severityThresholds: (suspected: TimeInterval, likely: TimeInterval, confirmed: TimeInterval) {
        (
            suspected: leakThreshold,
            likely: leakThreshold * 2,
            confirmed: leakThreshold * 3
        )
    }
}
