//
//  HomeView.swift
//  Construkt
//

import UIKit
import ConstruktKit

struct HomeView: ViewConvertable {
    
    // We bind the viewModel at initialization.
    private let viewModel = MovieViewModel()
    
    
    // MARK: - State
    
    /// Pure reactive data — observable, no UIKit dependency
    private class ScrollBinding {
        @Variable var offset: CGFloat = 0
    }
    
    /// Imperative UIKit handles — needed for layout callbacks only
    private class ViewHandles {
        weak var collectionView: UICollectionView?
    }
    
    private class AutoscrollController {
        let currentIndex = Property(0)
        var currentSection: Int = 0
        var workItem: DispatchWorkItem?
        
        func startTimer(collectionView: UICollectionView?, totalItems: Int) {
            stopTimer()
            guard let collectionView = collectionView, totalItems > 0 else { return }
            
            let item = DispatchWorkItem { [weak self, weak collectionView] in
                guard let self = self, let cv = collectionView else { return }
                let nextIndex = (self.currentIndex.wrappedValue + 1) % totalItems
                cv.scrollToItem(at: IndexPath(item: nextIndex, section: self.currentSection), at: .centeredHorizontally, animated: nextIndex != 0)
            }
            self.workItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: item)
        }
        
        func stopTimer() {
            workItem?.cancel()
            workItem = nil
        }
    }
    
    private let scrollBinding = ScrollBinding()
    private let handles = ViewHandles()
    private let autoscrollController = AutoscrollController()
    
    // MARK: - Layout Constants
    
    private enum Layout {
        static let navBarFadeDistance: CGFloat = 100
        static let heroOriginalHeight: CGFloat = 550
    }
    
    func asViews() -> [View] {
        Screen {
            CollectionView {
                heroSection
                genresSection
                popularSection
                upcomingSection
                topRatedSection
            }
            .emptyState(when: viewModel.isEmptyObservable) {
                EmptyView(
                    title: "No movies found",
                    subtitle: "Check your connection.",
                    buttonTitle: "Retry",
                    onAction: { [weak viewModel] in viewModel?.loadHomeData() }
                )
            }
            .backgroundColor(UIColor("#0A0A0A"))
            .with { [handles] view in
                view.collectionView.contentInsetAdjustmentBehavior = .never
                view.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                view.collectionView.showsVerticalScrollIndicator = false
                handles.collectionView = view.collectionView
            }
            .onRefresh(viewModel.isNowPlayingLoading) { [weak viewModel] in
                viewModel?.loadHomeData()
            }
            .onScroll { [scrollBinding] scrollView in
                scrollBinding.offset = scrollView.contentOffset.y
            }
        }
        .navigationBar {
            HomeNavigationBar(
                isLoading: viewModel.isNowPlayingLoading,
                scrollOffset: scrollBinding.$offset.eraseToAnyViewBinding(),
                onSearchTap: { sender in
                    sender.route(AppRoute.search, sender: nil)
                }
            )
        }
        .contentUnderNavBar(false)
        .margins(bottom: 100)
        .onHostDidLoad {
            viewModel.loadHomeData()
            // Show walkthrough after data loads
            showWalkthrough()
        }
        .onHostWillAppear { [handles, autoscrollController] _ in
            let totalItems = handles.collectionView?.numberOfItems(inSection: autoscrollController.currentSection) ?? 0
            autoscrollController.startTimer(collectionView: handles.collectionView, totalItems: totalItems)
        }
        .onHostWillDisappear { [autoscrollController] _ in
            autoscrollController.stopTimer()
        }
        .asViews()
    }
    
    // MARK: - Sections
    
    private var heroSection: AnySection {
        AnySection(id: HomeSection.hero, items: viewModel.nowPlayingMovies.map { Array($0.prefix(5)) }) { movie in
            AnyCell(movie, id: "hero-\(movie.id)") { movie in
                Modified(HeroContentView()) { view in
                    view.configure(with: movie)
                    view.accessibilityIdentifier = WalkthroughStepId.hero
                }
            }
        }
        // Direct event routing via ConstruktKit .onRoute modifier!
        .onRoute { (movie: Movie) in
            AppRoute.movieDetail(movieId: movie.id)
        }
        .layout { _ in
            let layout = HomeSection.hero.layout
            layout.visibleItemsInvalidationHandler = { (items, offset, env) in
                handleHeroScroll(items: items, offset: offset, env: env)
            }
            return layout
        }
        .footer { [weak autoscrollController, weak viewModel] in
            Footer(id: "page-control") {
                if let vm = viewModel, let ac = autoscrollController {
                    DynamicContainerView(vm.nowPlayingMovies.map { Array($0.prefix(5)) }) { movies in
                        if movies.count > 0 {
                            CustomPageControl(count: movies.count, currentIndex: ac.currentIndex)
                        } else {
                            ContainerView()
                        }
                    }
                } else {
                    ContainerView()
                }
            }
        }
        .shimmer(count: 1, when: viewModel.isNowPlayingLoading) {
            Modified(HeroContentView()) { $0.configure(with: .placeholder) }
        }
    }
    
    private var genresSection: AnySection {
        AnySection(
            id: HomeSection.categories,
            items: viewModel.genres,
            header: Header {
                StandardHeader(title: "Genres", actionTitle: nil, sectionId: WalkthroughStepId.genres)
            }
        ) { genre in
            AnyCell(genre, id: "genre-\(genre.id)") { genre in
                GenresCell(id: genre.id, genre: genre)
            }
        }
        .onRoute { (genre: Genre) in
            AppRoute.movieList(
                title: "Categories",
                sectionTypeRaw: HomeSection.categories.rawValue,
                genreId: genre.id,
                genreName: genre.name,
                allGenres: viewModel.currentGenres
            )
        }
        .shimmer(
            count: 6,
            when: viewModel.isLoadingGenres,
            includeSupplementary: true
        ) {
            GenresCell(id: -2, genre: .placeholder)
        }
        .layout { _ in
            HomeSection.categories.layout
        }
    }
    
    private var popularSection: AnySection {
        AnySection(
            id: HomeSection.popular,
            items: viewModel.popularSectionMovies,
            header: Header {
                StandardHeader(title: "Popular Now", actionTitle: "See All", sectionId: WalkthroughStepId.popular)
            }
        ) { movie in
            AnyCell(movie, id: "popular-\(movie.id)") { movie in
                PosterCell(movie: movie)
            }
        }
        .onRoute { (movie: Movie) in AppRoute.movieDetail(movieId: movie.id) }
        .backgroundDecoration(id: "popular_bg") {
            LinearGradient(colors: [
                UIColor.black.withAlphaComponent(0.3),
                UIColor.white.withAlphaComponent(0.2)
            ])
        }
        .layout { _ in
            HomeSection.popular.layout
        }
        .shimmer(
            count: 4,
            when: viewModel.isPopularSectionLoading,
            includeSupplementary: true
        ) {
            PosterCell(movie: .placeholder)
        }
    }
    
    private var upcomingSection: AnySection {
        AnySection(
            id: HomeSection.upcoming,
            items: viewModel.upcomingMovies.map { $0.asRenderItems() },
            header: Header {
                StandardHeader(title: "Upcoming", actionTitle: "See All", sectionId: WalkthroughStepId.upcoming)
            }
        ) { item in
            AnyCell(item, id: "upcoming-\(String(describing: item))") { item in
                UpcomingCell(item: item)
            }
        }
        .onRoute { (movie: Movie) in AppRoute.movieDetail(movieId: movie.id) }
        .layout { _ in
            HomeSection.upcoming.layout
        }
        .shimmer(
            count: 2,
            when: viewModel.isUpcomingLoading,
            includeSupplementary: true
        ) {
            UpcomingCell(item: .placeholder)
        }
    }
    
    private var topRatedSection: AnySection {
        AnySection(
            id: HomeSection.topRated,
            items: viewModel.topRatedMovies.map { Array($0.enumerated()) },
            header: Header {
                StandardHeader(title: "Top Rated", actionTitle: nil)
            }
        ) { (index, movie) in
            if index == 5 {
                AnyCell("This is an ad") { text in AdsCell(text: text) }
            }
            AnyCell(movie, id: "top-\(movie.id)") { movie in
                TopRatedCell(index: index + 1, movie: movie)
            }
        }
        .onRoute { (movie: Movie) in AppRoute.movieDetail(movieId: movie.id) }
        .onSelect { (ad: String) in
            print("Ad Selected: \(ad)")
        }
        .onRoute { (ad: String) in AppRoute.bottomSheet }
        .onRoute { (movie: Movie) in AppRoute.toast(message: "Selected: \(movie.title)", position: .bottom) }
        .layout { _ in
            HomeSection.topRated.layout
        }
        .shimmer(count: 3, when: viewModel.isTopRatedLoading) {
            TopRatedCell(index: 0, movie: .placeholder)
        }
    }
    
    // MARK: - Walkthrough
    
    private enum WalkthroughStepId {
        static let hero = "walkthrough-hero"
        static let genres = "walkthrough-genres"
        static let popular = "walkthrough-popular"
        static let upcoming = "walkthrough-upcoming"
        static let topRated = "walkthrough-topRated"
    }
    
    private var walkthroughSteps: [WalkthroughStep] {
        guard let cv = handles.collectionView else { return [] }
        return [
            WalkthroughStep(
                target: .view(id: WalkthroughStepId.hero),
                title: "Now Playing",
                description: "Swipe through movies currently playing in theaters. Tap any poster to see details.",
                tooltipPosition: .below,
                spotlightPadding: 0,
                prepare: {
                    await MainActor.run {  [weak handles] in
                        handles?.collectionView?.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .collectionViewSection(collectionView: cv, sectionIndex: 1),
                title: "Genres",
                description: "Browse movies by genre. Tap a category to explore its entire catalog.",
                tooltipPosition: .below,
                prepare: {
                    await MainActor.run {  [weak handles] in
                        handles?.collectionView?.scrollToItem(at: IndexPath(item: 0, section: 1), at: .centeredVertically, animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .collectionViewSection(collectionView: cv, sectionIndex: 2),
                title: "Popular Now",
                description: "Discover what's trending. Tap \"See All\" for the full list.",
                tooltipPosition: .below,
                prepare: {
                    await MainActor.run { [weak handles] in
                        handles?.collectionView?.scrollToItem(at: IndexPath(item: 0, section: 2), at: .centeredVertically, animated: true)
                    }
                }
            ),
            WalkthroughStep(
                target: .collectionViewSection(collectionView: cv, sectionIndex: 3),
                title: "Upcoming",
                description: "Stay ahead of the curve with upcoming releases.",
                tooltipPosition: .above,
                prepare: {
                    await MainActor.run { [weak handles] in
                        handles?.collectionView?.scrollToItem(at: IndexPath(item: 0, section: 3), at: .centeredVertically, animated: true)
                    }
                }
            ),
        ]
    }
    
    private func showWalkthrough() {
        guard !viewModel.walkthroughShown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let window = UIApplication.shared.firstKeyWindow else { return }
            
            let overlay = WalkthroughOverlayView(
                steps: walkthroughSteps,
                onDismiss: { [viewModel] in
                    viewModel.walkthroughShown = true
                })
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
    
    
    // MARK: - Handlers
    
    private func handleHeroScroll(
        items: [NSCollectionLayoutVisibleItem],
        offset: CGPoint,
        env: NSCollectionLayoutEnvironment
    ) {
        let containerWidth = env.container.contentSize.width
        let visibleRectCenter = offset.x + containerWidth / 2.0
        
        guard let collectionView = handles.collectionView else {
            return
        }
        
        for item in items {
            let distanceFromCenter = abs(item.center.x - visibleRectCenter)
            let progress = min(1.0, distanceFromCenter / (containerWidth / 2.0))
            
            if let cell = collectionView.cellForItem(at: item.indexPath),
               let heroView = findAllHeroViews(in: cell).first {
                heroView.setScrollProgress(progress)
            }
        }
        
        if let centeredItem = items.min(by: { abs($0.center.x - visibleRectCenter) < abs($1.center.x - visibleRectCenter) }) {
            let nextIndex = centeredItem.indexPath.item
            let nextSection = centeredItem.indexPath.section
            let totalItems = collectionView.numberOfItems(inSection: nextSection)
            
            let isNewIndex = autoscrollController.currentIndex.wrappedValue != nextIndex
            
            DispatchQueue.main.async { [weak autoscrollController] in
                if isNewIndex {
                    autoscrollController?.currentIndex.wrappedValue = nextIndex
                }
                autoscrollController?.currentSection = nextSection
                autoscrollController?.startTimer(collectionView: collectionView, totalItems: totalItems)
            }
        }
        
        // Stretchy Header Logic
        let y = offset.y
        if y < 0 {
            items.forEach { item in
                let newHeight = Layout.heroOriginalHeight + abs(y)
                let scale = newHeight / Layout.heroOriginalHeight
                
                let translationY = y / 2
                item.alpha = 1.0
                item.transform = CGAffineTransform(translationX: 0, y: translationY)
                    .scaledBy(x: 1, y: scale)
            }
        }
    }
    
    private func findAllHeroViews(in view: UIView) -> [HeroContentView] {
        var views: [HeroContentView] = []
        if let heroView = view as? HeroContentView { views.append(heroView) }
        for subview in view.subviews { views.append(contentsOf: findAllHeroViews(in: subview)) }
        return views
    }
    
}
