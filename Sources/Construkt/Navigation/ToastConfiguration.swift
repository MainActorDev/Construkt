//
//  ToastConfiguration.swift
//  Construkt
//

import UIKit

public enum ToastAnimation: Equatable {
    case fade
    case slide
    case slideAndFade
    case scale
    case scaleAndFade
    case bounce
    case pop
    case flip
    case none
}

public struct ToastConfiguration {
    
    public enum Position {
        case top(offset: CGFloat = 0)
        case bottom(offset: CGFloat = 0)
    }
    
    public var position: Position
    public var duration: TimeInterval
    public var enterAnimation: ToastAnimation
    public var exitAnimation: ToastAnimation
    public var animationDuration: TimeInterval
    public var springDamping: CGFloat
    public var dismissOnTap: Bool
    public var horizontalPadding: CGFloat
    public var spacingBetweenToasts: CGFloat
    public var ignoreSafeArea: Bool
    
    public init(
        position: Position = .bottom(offset: 0),
        duration: TimeInterval = 3.0,
        enterAnimation: ToastAnimation = .slideAndFade,
        exitAnimation: ToastAnimation = .slideAndFade,
        animationDuration: TimeInterval = 0.35,
        springDamping: CGFloat = 0.85,
        dismissOnTap: Bool = true,
        horizontalPadding: CGFloat = 16,
        spacingBetweenToasts: CGFloat = 8,
        ignoreSafeArea: Bool = true
    ) {
        self.position = position
        self.duration = duration
        self.enterAnimation = enterAnimation
        self.exitAnimation = exitAnimation
        self.animationDuration = animationDuration
        self.springDamping = springDamping
        self.dismissOnTap = dismissOnTap
        self.horizontalPadding = horizontalPadding
        self.spacingBetweenToasts = spacingBetweenToasts
        self.ignoreSafeArea = ignoreSafeArea
    }
    
    public static func top(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(position: .top(offset: offset))
    }
    
    public static func bottom(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(position: .bottom(offset: offset))
    }
    
    public static func topSlide(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .top(offset: offset),
            enterAnimation: .slide,
            exitAnimation: .slide
        )
    }
    
    public static func bottomSlide(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .bottom(offset: offset),
            enterAnimation: .slide,
            exitAnimation: .slide
        )
    }
    
    public static func topBounce(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .top(offset: offset),
            enterAnimation: .bounce,
            exitAnimation: .bounce,
            springDamping: 0.6
        )
    }
    
    public static func bottomBounce(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .bottom(offset: offset),
            enterAnimation: .bounce,
            exitAnimation: .bounce,
            springDamping: 0.6
        )
    }
    
    public static func topPop(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .top(offset: offset),
            enterAnimation: .pop,
            exitAnimation: .pop
        )
    }
    
    public static func bottomPop(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .bottom(offset: offset),
            enterAnimation: .pop,
            exitAnimation: .pop
        )
    }
    
    public static func topFade(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .top(offset: offset),
            enterAnimation: .fade,
            exitAnimation: .fade
        )
    }
    
    public static func bottomFade(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .bottom(offset: offset),
            enterAnimation: .fade,
            exitAnimation: .fade
        )
    }
    
    public static func topFlip(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .top(offset: offset),
            enterAnimation: .flip,
            exitAnimation: .flip
        )
    }
    
    public static func bottomFlip(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .bottom(offset: offset),
            enterAnimation: .flip,
            exitAnimation: .flip
        )
    }
    
    public static func topScale(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .top(offset: offset),
            enterAnimation: .scaleAndFade,
            exitAnimation: .scaleAndFade
        )
    }
    
    public static func bottomScale(offset: CGFloat = 0) -> ToastConfiguration {
        ToastConfiguration(
            position: .bottom(offset: offset),
            enterAnimation: .scaleAndFade,
            exitAnimation: .scaleAndFade
        )
    }
}

extension ToastConfiguration.Position: Equatable {
    public static func == (lhs: ToastConfiguration.Position, rhs: ToastConfiguration.Position) -> Bool {
        switch (lhs, rhs) {
        case (.top(let l), .top(let r)):
            return l == r
        case (.bottom(let l), .bottom(let r)):
            return l == r
        default:
            return false
        }
    }
}

extension ToastConfiguration.Position: Comparable {
    public static func < (lhs: ToastConfiguration.Position, rhs: ToastConfiguration.Position) -> Bool {
        switch (lhs, rhs) {
        case (.top, .bottom):
            return true
        case (.bottom, .top):
            return false
        default:
            return false
        }
    }
}

extension ToastConfiguration {
    var positionOrder: Int {
        switch position {
        case .top: return 0
        case .bottom: return 1
        }
    }
}

extension ToastConfiguration.Position {
    var isTop: Bool {
        if case .top = self { return true }
        return false
    }
    
    var isBottom: Bool {
        if case .bottom = self { return true }
        return false
    }
}
