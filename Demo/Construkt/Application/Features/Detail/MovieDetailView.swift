import UIKit
import ConstruktKit

// MARK: - Unused
public enum MovieDetailRoute {
    case back
}

struct MovieDetailView: ViewConvertable {
    
    // MARK: - Properties
    private let viewModel = MovieViewModel()
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
    init(movie: Movie) {
        self.movie = movie
    }
    
    // MARK: - Body
    func asViews() -> [View] {
        let details = viewModel.movieDetails.compactMap { $0 }
        let casts = viewModel.movieCasts
        
        return Screen {
            ZStackView {
                ImageView(nil)
                    .contentMode(.scaleAspectFill)
                    .clipsToBounds(true)
                    .onReceive(details.map { $0.backdropURL ?? $0.posterURL }) { context in
                        context.view.setImage(from: context.value)
                    }
                    .onReceive(viewModel.isLoadingDetails) { context in
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
                                .accessibilityIdentifier(WalkthroughStepId.hero)
                            
                            VStackView(spacing: 24) {
                                ContainerView {
                                    actionButtons
                                }
                                .accessibilityIdentifier(WalkthroughStepId.actions)
                                MovieStoryline(details: details)
                                    .accessibilityIdentifier(WalkthroughStepId.storyline)
                                MovieCast(casts: casts) { cast in
                                    print("Tapped on cast: \(cast.name)")
                                }
                                .accessibilityIdentifier(WalkthroughStepId.cast)
                                MovieSimilar(details: details) { [scrollBinding, weak viewModel] movie in
                                    scrollBinding.scrollToTopTrigger += 1
                                    viewModel?.selectMovie(movie)
                                }
                                .accessibilityIdentifier(WalkthroughStepId.similar)
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
                    .onReceive(viewModel.isLoadingDetails) { context in
                        context.view.isHidden = context.value
                    }
                    
                    // Loading Indicator
                    LoadingView()
                        .visible(false)
                        .onReceive(viewModel.isLoadingDetails) { context in
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
        .onReceive(viewModel.isLoadingDetails.skip(1)) { [walkthroughSteps] context in
            // Wait for loading to finish (false) before showing walkthrough
            guard !context.value else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let window = UIApplication.shared.firstKeyWindow else { return }
                
                // Don't show if already showing
                if window.subviews.contains(where: { $0 is WalkthroughOverlayView }) { return }
                
                let overlay = WalkthroughOverlayView(steps: walkthroughSteps, onDismiss: nil)
                overlay.translatesAutoresizingMaskIntoConstraints = false
                window.addSubview(overlay)
                NSLayoutConstraint.activate([
                    overlay.topAnchor.constraint(equalTo: window.topAnchor),
                    overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                    overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                    overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                ])
            }
        }
        .onHostDidLoad {
            viewModel.selectMovie(movie)
        }
        .asViews()
    }
    
    // MARK: - Walkthrough
    
    private enum WalkthroughStepId: String {
        case hero = "detail-hero"
        case actions = "detail-actions"
        case storyline = "detail-storyline"
        case cast = "detail-cast"
        case similar = "detail-similar"
    }
    
    private var walkthroughSteps: [WalkthroughStep] {
        guard let scrollView = handles.scrollView else { return [] }
        return [
            WalkthroughStep(
                target: .view(id: WalkthroughStepId.hero.rawValue),
                title: "Movie Metadata",
                description: "View the movie's title, rating, release year, and genres.",
                tooltipPosition: .below,
                spotlightPadding: 0,
                prepare: { [scrollView] in
                    await MainActor.run {
                        scrollView.setContentOffset(.zero, animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .view(id: WalkthroughStepId.actions.rawValue),
                title: "Quick Actions",
                description: "Jump right into watching or download it for offline viewing.",
                tooltipPosition: .below,
                prepare: { [weak scrollView] in
                    await MainActor.run {
                        guard let sv = scrollView else { return }
                        // Scroll to ~400 points to reveal buttons + storyline
                        let targetY = min(400.0, sv.contentSize.height - sv.bounds.height)
                        sv.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .view(id: WalkthroughStepId.storyline.rawValue),
                title: "Storyline",
                description: "Read the synopsis to see what the movie is all about.",
                tooltipPosition: .below,
                prepare: { [weak scrollView] in
                    await MainActor.run {
                        // Keep the same offset as actions since they're close
                        guard let sv = scrollView else { return }
                        let targetY = min(400.0, sv.contentSize.height - sv.bounds.height)
                        sv.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .view(id: WalkthroughStepId.cast.rawValue),
                title: "Cast & Crew",
                description: "Discover the actors who brought this movie to life.",
                tooltipPosition: .above,
                prepare: { [weak scrollView] in
                    await MainActor.run {
                        guard let sv = scrollView else { return }
                        let targetY = min(600.0, sv.contentSize.height - sv.bounds.height)
                        sv.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .view(id: WalkthroughStepId.similar.rawValue),
                title: "Similar Movies",
                description: "Loved this one? Explore these related recommendations.",
                tooltipPosition: .above,
                prepare: { [weak scrollView] in
                    await MainActor.run {
                        guard let sv = scrollView else { return }
                        let targetY = max(0, sv.contentSize.height - sv.bounds.height)
                        sv.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
                    }
                }
            )
        ]
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
