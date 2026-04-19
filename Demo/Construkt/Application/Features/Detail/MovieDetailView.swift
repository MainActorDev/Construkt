import UIKit
import ConstruktKit

// MARK: - Unused
public enum MovieDetailRoute {
    case back
}

struct MovieDetailView: ViewConvertable {
    
    // MARK: - Properties
    private let store: FeatureStore<MovieFeature>
    private let movie: Movie
    private let heroHeight: CGFloat = 450
    
    // MARK: - State
    
    /// Pure reactive data — observable, no UIKit dependency
    private class ScrollBinding {
        @Variable var offset: CGFloat = 0
        @Variable var scrollToTopTrigger: UInt = 0
    }
    
    /// Imperative UIKit handles — needed for layout & scroll only
    private class ViewHandles {
        weak var heroHeightConstraint: NSLayoutConstraint?
        weak var scrollView: UIScrollView?
    }
    
    private let scrollBinding = ScrollBinding()
    private let handles = ViewHandles()
    
    // MARK: - Init
    init(movie: Movie, store: FeatureStore<MovieFeature> = MovieFeatureModule.makeStore()) {
        self.movie = movie
        self.store = store
    }
    
    // MARK: - Body
    func asViews() -> [View] {
        let details = store.movieDetails.compactMap { $0 }
        let casts = store.movieCasts
        
        return Screen {
            ZStackView {
                ImageView(nil)
                    .contentMode(.scaleAspectFill)
                    .clipsToBounds(true)
                    .onReceive(details.map { $0.backdropURL ?? $0.posterURL }) { context in
                        context.view.setImage(from: context.value)
                    }
                    .onReceive(store.isLoadingDetails) { context in
                        context.view.isHidden = context.value
                    }
                    .customConstraints { [handles, heroHeight] view in
                        guard let superview = view.superview else { return }
                        view.translatesAutoresizingMaskIntoConstraints = false
                        let heightConstraint = view.heightAnchor.constraint(equalToConstant: heroHeight)
                        handles.heroHeightConstraint = heightConstraint
                        NSLayoutConstraint.activate([
                            view.topAnchor.constraint(equalTo: superview.topAnchor),
                            view.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                            view.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                            heightConstraint
                        ])
                    }
                    .onReceive(scrollBinding.$offset) { context in
                         let yOffset = context.value
                         guard let constraint = handles.heroHeightConstraint else { return }
                         if yOffset < 0 {
                             constraint.constant = heroHeight + abs(yOffset)
                         } else {
                             constraint.constant = max(0, heroHeight - yOffset)
                         }
                    }
                
                // Layer 2: Scroll Content
                ContainerView {
                    VerticalScrollView {
                        VStackView(spacing: 24) {
                            // Transparent Header Space + Content Overlay
                            MovieDetailHero(details: details, height: self.heroHeight)
                            
                            VStackView(spacing: 24) {
                                ContainerView {
                                    actionButtons
                                }
                                MovieStoryline(details: details)
                                MovieCast(casts: casts) { cast in
                                    print("Tapped on cast: \(cast.name)")
                                }
                                MovieSimilar(details: details) { [scrollBinding, weak store] movie in
                                    scrollBinding.scrollToTopTrigger += 1
                                    store?.selectMovie(movie)
                                }
                            }
                            .padding(top: 0, left: 20, bottom: 0, right: 20)
                            
                            // Spacer
                            SpacerView(h: 40)
                        }
                    }
                    .onDidScroll { context in
                        scrollBinding.offset = context.view.contentOffset.y
                    }
                    .with { [handles] scrollView in
                        scrollView.contentInsetAdjustmentBehavior = .never
                        scrollView.backgroundColor = .clear
                        handles.scrollView = scrollView
                    }
                    .onReceive(scrollBinding.$scrollToTopTrigger.skip(1)) { [handles] _ in
                        handles.scrollView?.setContentOffset(.zero, animated: true)
                    }
                    .onReceive(store.isLoadingDetails) { context in
                        context.view.isHidden = context.value
                    }
                    
                    // Loading Indicator
                    LoadingView()
                        .visible(false)
                        .onReceive(store.isLoadingDetails) { context in
                            context.view.isHidden = !context.value
                        }
                        .backgroundColor(.black.withAlphaComponent(0.5))
                }
            }
        }
        .navigationBar {
            MovieDetailNavBar(
                title: details.compactMap { $0.title },
                scrollOffset: scrollBinding.$offset.eraseToAnyViewBinding(),
                onBack: { sender in
                    sender.route(AppRoute.back, sender: self)
                }
            )
        }
        .contentUnderNavBar(false)
        .backgroundColor(UIColor("#0A0A0A"))
        .onHostDidLoad {
            store.selectMovie(movie)
        }
        .asViews()
    }
    
    // MARK: - Subviews
    private var actionButtons: View {
        HStackView(spacing: 16) {
            ButtonView("Watch Now")
                .backgroundColor(.white, for: .normal)
                .color(.black, for: .normal)
                .font(UIFont.systemFont(ofSize: 16, weight: .bold))
                .cornerRadius(24)
                .height(56)
                .with {
                    $0.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    $0.tintColor = .black
                    $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
                }
            ButtonView("Download")
                .backgroundColor(UIColor("#1A1A1A"), for: .normal)
                .color(.white, for: .normal)
                .font(UIFont.systemFont(ofSize: 16, weight: .medium))
                .cornerRadius(24)
                .height(56)
                .with {
                    $0.setImage(UIImage(systemName: "arrow.down.to.line"), for: .normal)
                    $0.tintColor = .white
                    $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
                }
        }
        .distribution(.fillEqually)
    }
}
