import UIKit
import ConstruktKit

extension ModifiableView where Base: BuilderInternalTableView {
    /// Automatically handles smart updates for LoadableState by injecting new data into the builder.
    /// - Parameter type: The type of the items in the list (e.g. User.self)
    @discardableResult
    public func enableSmartUpdate<T: Equatable & Sendable>(_ type: T.Type) -> ViewModifier<Base> {
        ViewModifier(modifiableView) { view in
             view.updateHandler = { [weak view] state in
                 guard let view = view else { return }
                 // Smart Update Logic:
                 // 1. Check if state is LoadableState<[T]> and is .loaded
                 if let state = state as? LoadableState<[T]>,
                    case .loaded(let items) = state,
                    // 2. Check if builder is DynamicItemViewBuilder<T>
                    let builder = view.builder as? DynamicItemViewBuilder<T> {
                     // 3. Inject new data
                     builder.items = items
                     // 4. Trigger update
                     view.set(builder)
                 }
             }
        }
    }
}
