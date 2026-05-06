//
//  👨‍💻 Created by @thatswiftdev on 26/09/25.
//
//  © 2025, https://github.com/thatswiftdev. All rights reserved.
//
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import UIKit
import ObjectiveC.runtime

/// An internal `CAGradientLayer` configured to perform the continuous "shimmer" animation across bounds.
final class _ShimmerLayer: CAGradientLayer {
    private(set) var config: _ShimmerConfig = _ShimmerConfig()

    var isAnimating: Bool {
        animation(forKey: Self.animationKey) != nil
    }

    override init() {
        super.init()
        needsDisplayOnBoundsChange = true
        if #available(iOS 17.0, *) {
            rasterizationScale = UITraitCollection.current.displayScale
        } else {
            rasterizationScale = UIScreen.main.scale
        }
        shouldRasterize = false
        type = .axial
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func apply(config: _ShimmerConfig) {
        self.config = config
        cornerRadius = config.cornerRadius

        // Constant colors (no color animation).
        let bg = config.background.cgColor
        let hi = config.highlight.cgColor
        colors = [bg, hi, bg]

        // Direction affects the axis; locations anim handles the sweep.
        startPoint = Self.startPoint(for: config.direction)
        endPoint   = Self.endPoint(for: config.direction)

        // Set initial locations so the first frame has a consistent look.
        let (from, _) = Self.locations(width: Double(config.highlightWidth))
        locations = from
    }

    func start() {
        removeAnimation(forKey: Self.animationKey)

        // Animate only the 'locations' property.
        let (from, to) = Self.locations(width: Double(config.highlightWidth))
        let shimmer = CABasicAnimation(keyPath: "locations")
        shimmer.fromValue = from
        shimmer.toValue   = to
        shimmer.duration  = config.duration
        shimmer.repeatCount = .infinity
        shimmer.beginTime = CACurrentMediaTime() + config.loopDelay
        shimmer.isRemovedOnCompletion = false

        // Reverse for opposite directions so the visual motion matches.
        if Self.isReverse(config.direction) {
            shimmer.fromValue = to
            shimmer.toValue   = from
        }

        add(shimmer, forKey: Self.animationKey)

        if config.pausesOnBackground { observeAppLifecycle() }
    }

    func stop(removeFromSuperlayer: Bool) {
        removeAnimation(forKey: Self.animationKey)
        if removeFromSuperlayer { self.removeFromSuperlayer() }
        unobserveAppLifecycle()
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        // Keep corner radius in sync
        self.cornerRadius = config.cornerRadius
    }

    // MARK: - App lifecycle pause/resume
    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResign),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    private func unobserveAppLifecycle() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillResign() {
        let pausedTime = convertTime(CACurrentMediaTime(), from: nil)
        speed = 0
        timeOffset = pausedTime
    }

    @objc private func appDidBecomeActive() {
        let pausedTime = timeOffset
        speed = 1
        timeOffset = 0
        beginTime = 0
        let timeSincePause = convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        beginTime = timeSincePause
    }

    // MARK: - Helpers

    private static let animationKey = "shimmer.locations"

    /// Build "from" and "to" locations given a width fraction w (0.10...0.80).
    /// Example: w = 0.50 → from [-1, -0.5, 0], to [1, 1.5, 2]
    private static func locations(width w: Double) -> ([NSNumber], [NSNumber]) {
        let ww = max(0.10, min(0.80, w))
        let from: [NSNumber] = [NSNumber(value: -1.0), NSNumber(value: -1.0 + ww), NSNumber(value: 0.0)]
        let to:   [NSNumber] = [NSNumber(value:  1.0), NSNumber(value:  1.0 + ww), NSNumber(value: 2.0)]
        return (from, to)
    }

    private static func isReverse(_ dir: _ShimmerConfig.Direction) -> Bool {
        switch dir {
        case .rightToLeft, .bottomToTop: return true
        default: return false
        }
    }

    private static func startPoint(for dir: _ShimmerConfig.Direction) -> CGPoint {
        switch dir {
        case .leftToRight:  return CGPoint(x: 0.0, y: 0.5)
        case .rightToLeft:  return CGPoint(x: 1.0, y: 0.5)
        case .topToBottom:  return CGPoint(x: 0.5, y: 0.0)
        case .bottomToTop:  return CGPoint(x: 0.5, y: 1.0)
        }
    }
    private static func endPoint(for dir: _ShimmerConfig.Direction) -> CGPoint {
        switch dir {
        case .leftToRight:  return CGPoint(x: 1.0, y: 0.5)
        case .rightToLeft:  return CGPoint(x: 0.0, y: 0.5)
        case .topToBottom:  return CGPoint(x: 0.5, y: 1.0)
        case .bottomToTop:  return CGPoint(x: 0.5, y: 0.0)
        }
    }
}

private var shimmerLayerKey: UInt8 = 0
private var shimmerKVOKey: UInt8 = 0

extension UIView {
    var shimmerLayer: CAGradientLayer? {
        get { objc_getAssociatedObject(self, &shimmerLayerKey) as? CAGradientLayer }
        set { objc_setAssociatedObject(self, &shimmerLayerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func ensureLayoutObserver() {
        guard objc_getAssociatedObject(self, &shimmerKVOKey) == nil else { return }
        let obs = boundsObserver { [weak self] in
            guard let self = self, let layer = self.shimmerLayer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = self.bounds
            layer.cornerRadius = (layer as? _ShimmerLayer)?.config.cornerRadius ?? layer.cornerRadius
            CATransaction.commit()
        }
        addObserver(obs)
        objc_setAssociatedObject(self, &shimmerKVOKey, obs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func removeLayoutObserverIfNeeded() {
        if let obs = objc_getAssociatedObject(self, &shimmerKVOKey) as? NSKeyValueObservation {
            obs.invalidate()
            objc_setAssociatedObject(self, &shimmerKVOKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func boundsObserver(_ onChange: @escaping () -> Void) -> NSKeyValueObservation {
        observe(\.bounds, options: [.new]) { _, _ in onChange() }
    }

    func addObserver(_ obs: NSKeyValueObservation) {
        // KVO retained via associated object above.
    }
}
