import UIKit
import ConstruktKit


@available(iOS 15.0, *)
@MainActor
final class HomeCoordinator: BaseCoordinator, RouteHandlingCoordinator {
 
    let router: any ConstruktRouter
    private let factory: ScreenFactoryProtocol
    
    var onSwitchToExplore: (() -> Void)?
    
    init(router: any ConstruktRouter, factory: ScreenFactoryProtocol) {
        self.router = router
        self.factory = factory
        super.init()
    }
    
    override func start() {
        let homeVC = factory.makeScreen(for: .home)
        router.setRoot(homeVC, hideBar: false, animated: false, receiver: self)
    }
    
    func canReceive(_ event: AppRoute, sender: Any?) -> Bool {
        switch event {
        case .back:
            router.pop(animated: true)
            
        case .movieDetail(let movieId):
            let screen = factory.makeScreen(for: .movieDetail(movieId: movieId))
            router.push(screen, animated: true, hideTabBar: true, receiver: self)
            
        case .movieList(let title, let sectionTypeRaw, let genreId, let genreName, let allGenres):
            let screen = factory.makeScreen(for: .movieList(title: title, sectionTypeRaw: sectionTypeRaw, genreId: genreId, genreName: genreName, allGenres: allGenres))
            router.push(screen, animated: true, completion: nil, receiver: self)
            
        case .search:
            onSwitchToExplore?()
            
        case .bottomSheet:
            router.present(
                ViewPresentable {
                    VStackView(spacing: 16) {
                        LabelView("Bottom Sheet Demo")
                            .font(.systemFont(ofSize: 20, weight: .bold))
                        LabelView("This is a configurable bottom sheet powered by Construkt Router")
                            .color(.secondaryLabel)
                            .alignment(.center)
                            .numberOfLines(0)
                    }
                    .padding(h: 24, v: 24)
                },
                style: .configurable(.init(backgroundColor: .white, anchors: [.fraction(1.0)]))
            )
            
        case .toast(let message, let position):
            let config: ToastConfiguration = position == .top ? .topPop() : .bottomBounce()
            router.showToast(
                ViewPresentable {
                    ZStackView {
                        HStackView(spacing: 12) {
                            ImageView(systemName: position == .top ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                                .tintColor(position == .top ? .systemBlue : .systemGreen)
                                .contentMode(.scaleAspectFit)
                                .size(width: 24, height: 24)
                            LabelView(message)
                                .font(.systemFont(ofSize: 15, weight: .medium))
                                .color(.white)
                        }
                        .padding(h: 16, v: 14)
                        .backgroundColor(UIColor.black.withAlphaComponent(0.85))
                        .cornerRadius(12)
                        .clipsToBounds(true)
                        .alignment(.center)
                    }
                },
                config: config
            )
            
        default: return false
        }
        
        return true
    }
}
