//
//  LifecycleHostTracker.swift
//  Construkt
//

import Foundation
import UIKit

public final class LifecycleHostTracker: @unchecked Sendable {
    public static let shared = LifecycleHostTracker()
    
    private var _configuration: LifecycleTrackerConfiguration = .disabled
    private let configurationLock = NSLock()
    
    public var configuration: LifecycleTrackerConfiguration {
        get {
            configurationLock.lock()
            defer { configurationLock.unlock() }
            return _configuration
        }
        set {
            let shouldStart: Bool
            let shouldStop: Bool
            
            configurationLock.lock()
            let wasEnabled = _configuration.isEnabled
            _configuration = newValue
            shouldStart = newValue.isEnabled && !wasEnabled
            shouldStop = !newValue.isEnabled && wasEnabled
            configurationLock.unlock()
            
            if shouldStart {
                startMonitoring()
            } else if shouldStop {
                stopMonitoring()
            }
        }
    }
    
    private var contexts: [UUID: ControllerTrackingContext] = [:]
    private var inactiveControllers: [DeallocatedControllerInfo] = []
    private let dataLock = NSLock()
    
    private var checkTimer: Timer?
    private let timerLock = NSLock()
    
    private init() {}
    
    public var activeControllerInfos: [ActiveControllerInfo] {
        dataLock.lock()
        defer { dataLock.unlock() }
        return contexts.values.map { $0.info }
    }
    
    public var inactiveControllerInfos: [DeallocatedControllerInfo] {
        dataLock.lock()
        defer { dataLock.unlock() }
        return inactiveControllers
    }
    
    public var activeCount: Int {
        dataLock.lock()
        defer { dataLock.unlock() }
        return contexts.count
    }
    
    public var inactiveCount: Int {
        dataLock.lock()
        defer { dataLock.unlock() }
        return inactiveControllers.count
    }
    
    internal func register(
        _ controller: LifecycleHostController,
        label: String?,
        contentView: UIView?,
        registry: ViewLifecycleRegistry?,
        file: String,
        line: Int
    ) {
        guard configuration.isEnabled, let label = label else { return }
        
        let id = UUID()
        let info = ActiveControllerInfo(
            id: id,
            label: label,
            createdAt: Date(),
            stackTrace: Thread.callStackSymbols,
            sourceFile: file,
            sourceLine: line
        )
        
        let context = ControllerTrackingContext(
            controller: controller,
            info: info,
            contentView: contentView,
            registry: registry
        )
        
        dataLock.lock()
        defer { dataLock.unlock() }
        contexts[id] = context
        
        controller.trackingId = id
    }
    
    internal func reportDealloc(_ controller: LifecycleHostController) {
        guard configuration.isEnabled else { return }
        
        dataLock.lock()
        defer { dataLock.unlock() }
        
        guard let id = controller.trackingId,
              let context = contexts.removeValue(forKey: id) else {
            return
        }
        
        let info = DeallocatedControllerInfo(
            id: id,
            label: context.info.label,
            createdAt: context.info.createdAt,
            deallocatedAt: Date(),
            contentViewDeallocated: context.contentView == nil,
            registryDeallocated: context.registry == nil,
            stackTrace: context.info.stackTrace,
            sourceFile: context.info.sourceFile,
            sourceLine: context.info.sourceLine
        )
        
        inactiveControllers.append(info)
        
        trimHistoryIfNeeded()
    }
    
    public func checkForLeaks() -> [LeakWarning] {
        guard configuration.isEnabled else { return [] }
        
        let config = configuration
        let thresholds = config.severityThresholds
        
        dataLock.lock()
        var warnings: [LeakWarning] = []
        var idsToRemove: [UUID] = []
        
        for (id, context) in contexts {
            if context.controller == nil {
                idsToRemove.append(id)
                continue
            }
            
            let age = context.info.age
            
            guard age >= thresholds.suspected else { continue }
            
            let severity: LeakSeverity
            if age >= thresholds.confirmed {
                severity = .confirmed
            } else if age >= thresholds.likely {
                severity = .likely
            } else {
                severity = .suspected
            }
            
            let warning = LeakWarning(
                controllerId: id,
                label: context.info.label,
                age: age,
                stackTrace: context.info.stackTrace,
                sourceFile: context.info.sourceFile,
                sourceLine: context.info.sourceLine,
                severity: severity,
                contentViewHeld: context.contentView != nil,
                registryHeld: context.registry != nil
            )
            
            warnings.append(warning)
        }
        
        for id in idsToRemove {
            contexts.removeValue(forKey: id)
        }
        
        dataLock.unlock()
        
        handleWarnings(warnings, config: config)
        
        return warnings
    }
    
    public func scheduleImmediateCheck(after delay: TimeInterval = 2.0) {
        guard configuration.isEnabled else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            _ = self?.checkForLeaks()
        }
    }
    
    private func handleWarnings(_ warnings: [LeakWarning], config: LifecycleTrackerConfiguration) {
        guard !warnings.isEmpty else { return }
        
        if config.logToConsole {
            for warning in warnings.sorted(by: { $0.severity > $1.severity }) {
                print(warning.debugDescription)
            }
        }
        
        if config.assertOnLeak {
            #if DEBUG
            let confirmedCount = warnings.filter { $0.severity == .confirmed }.count
            if confirmedCount > 0 {
                assertionFailure("[CONSTRUKT] \(confirmedCount) confirmed memory leak(s) detected. Check console for details.")
            }
            #endif
        }
        
        if let handler = config.onLeakDetected {
            DispatchQueue.main.async {
                for warning in warnings {
                    handler(warning)
                }
            }
        }
    }
    
    public func clearHistory() {
        dataLock.lock()
        defer { dataLock.unlock() }
        inactiveControllers.removeAll()
    }
    
    public func clearAll() {
        stopMonitoring()
        
        dataLock.lock()
        defer { dataLock.unlock() }
        
        contexts.removeAll()
        inactiveControllers.removeAll()
    }
    
    public func startMonitoring() {
        timerLock.lock()
        defer { timerLock.unlock() }
        
        guard configuration.isEnabled else { return }
        
        stopMonitoringInternal()
        
        let interval = configuration.checkInterval
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            _ = self?.checkForLeaks()
        }
        RunLoop.main.add(checkTimer!, forMode: .common)
    }
    
    public func stopMonitoring() {
        timerLock.lock()
        defer { timerLock.unlock() }
        stopMonitoringInternal()
    }
    
    private func stopMonitoringInternal() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    private func trimHistoryIfNeeded() {
        let maxCount = configuration.retainHistoryCount
        guard inactiveControllers.count > maxCount else { return }
        
        let removeCount = inactiveControllers.count - maxCount
        inactiveControllers.removeFirst(removeCount)
    }
    
    public func reset() {
        stopMonitoring()
        
        dataLock.lock()
        defer { dataLock.unlock() }
        
        contexts.removeAll()
        inactiveControllers.removeAll()
    }
}
