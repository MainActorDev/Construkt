//
//  SheetConfiguration.swift
//  Construkt
//

import UIKit

public struct SheetConfiguration {
    
    public enum Anchor: Equatable {
        case intrinsic(maxFraction: CGFloat? = 0.9)
        case absolute(CGFloat)
        case fraction(CGFloat)
    }
    
    public var backgroundColor: UIColor
    public var transitionStyle: SheetTransitionStyle
    
    public var anchors: [Anchor]
    public var cornerRadius: CGFloat
    public var showDragHandle: Bool
    public var tapToDismiss: Bool
    
    public var dimOpacity: CGFloat
    
    public var springDamping: CGFloat
    public var baseDuration: TimeInterval
    
    public var handleKeyboard: Bool
    
    public var coordinateScrollGestures: Bool
    
    public var pushWidthFraction: CGFloat
    
    public init(
        backgroundColor: UIColor = .systemBackground,
        transitionStyle: SheetTransitionStyle = .bottomSheet,
        tapToDismiss: Bool = false,
        anchors: [Anchor] = [.intrinsic()],
        cornerRadius: CGFloat = 16,
        showDragHandle: Bool = true,
        dimOpacity: CGFloat = 0.4,
        springDamping: CGFloat = 0.85,
        baseDuration: TimeInterval = 0.35,
        handleKeyboard: Bool = true,
        coordinateScrollGestures: Bool = true,
        pushWidthFraction: CGFloat = 1.0
    ) {
        self.backgroundColor = backgroundColor
        self.transitionStyle = transitionStyle
        self.tapToDismiss = tapToDismiss
        self.anchors = anchors
        self.cornerRadius = cornerRadius
        self.showDragHandle = showDragHandle
        self.dimOpacity = dimOpacity
        self.springDamping = springDamping
        self.baseDuration = baseDuration
        self.handleKeyboard = handleKeyboard
        self.coordinateScrollGestures = coordinateScrollGestures
        self.pushWidthFraction = pushWidthFraction
    }
    
    public static var bottomSheet: SheetConfiguration {
        SheetConfiguration(
            transitionStyle: .bottomSheet,
            showDragHandle: false
        )
    }
    
    public static var push: SheetConfiguration {
        SheetConfiguration(
            transitionStyle: .push,
            anchors: [.fraction(1.0)],
            cornerRadius: 0,
            showDragHandle: false,
            coordinateScrollGestures: false
        )
    }
}
