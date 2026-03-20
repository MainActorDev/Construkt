import Foundation

@available(iOS 16.0, *)
public extension EffectPolicy {
    /// Duration-based debounce convenience for modern call sites.
    static func debounce(_ key: EffectKey, for duration: Duration) -> EffectPolicy {
        .debounce(key, duration.construktTimeInterval)
    }
}

@available(iOS 16.0, *)
private extension Duration {
    /// Converts `Duration` into seconds as `TimeInterval`.
    var construktTimeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
