//
//  ExploreView.swift
//  Construkt
//

import UIKit
import ConstruktKit

enum ExploreSection: String, SectionConfigIdentifier {
    case search
    case genres
    case collections
    case arrivals
    
    var uniqueId: String { rawValue }
}

struct ExploreView: ViewConvertable {
    private let store: FeatureStore<ExploreFeature>

    init(store: FeatureStore<ExploreFeature> = ExploreFeatureModule.makeStore()) {
        self.store = store
    }
    
    func asViews() -> [View] {
        Screen {
            // Background gradients
            CircleView()
                .backgroundColor(UIColor.systemIndigo.withAlphaComponent(0.05))
                .size(width: 250, height: 250)
                .position(.topLeft)
                .margins(top: 0, left: 40)
            
            CircleView()
                .backgroundColor(UIColor.systemPink.withAlphaComponent(0.05))
                .size(width: 320, height: 320)
                .position(.bottomRight)
                .margins(bottom: 160, right: 0)
            
            // Main Collection View
            CollectionView {
                genresSection
                collectionsSection
                arrivalsSection
            }
            .with {
                $0.collectionView.contentInset.top = 60
                $0.collectionView.showsVerticalScrollIndicator = false
            }
        }
        .navigationBar {
            headerOverlay
        }
        .backgroundColor(UIColor(white: 0.04, alpha: 1)) // Neutral 950
        .onHostDidLoad {
            store.dispatch(.loadData)
        }
        .asViews()
    }
    
    // MARK: - Sections
    
    private var genresSection: AnySection {
        AnySection(
            id: ExploreSection.genres,
            items: store.state.map { $0.genres },
            header: Header {
                ExploreHeader(title: "Browse Genres", subtitle: nil)
            }
        ) { genre in
            AnyCell(genre, id: genre.id) { genre in
                ExploreGenreCard(genre: genre)
            }
        }
        .onRoute { (genre: ExploreGenre) -> AppRoute? in
            guard let genreId = Int(genre.id) else { return nil }
            let allGenres = store.state.wrappedValue.allGenres.compactMap {
                guard let id = Int($0.id) else { return nil as Genre? }
                return Genre(id: id, name: $0.name)
            }
            return AppRoute.movieList(
                title: genre.name,
                sectionTypeRaw: "categories",
                genreId: genreId,
                genreName: genre.name,
                allGenres: allGenres
            )
        }
        .layout {
            .grid(
                itemHeight: .absolute(96),
                columns: 2,
                itemInsets: .init(top: 6, leading: 6, bottom: 6, trailing: 6)
            )
            .insets(top: 12, leading: 18, bottom: 24, trailing: 18)
            .supplementaryHeader(height: .estimated(50))
        }
    }
    
    private var collectionsSection: AnySection {
        AnySection(
            id: ExploreSection.collections,
            items: store.state.map { $0.collections },
            header: Header {
                ExploreHeader(title: "Curated Collections", subtitle: "Hand-picked by our editors")
            }
        ) { collection in
            AnyCell(collection, id: collection.id) { collection in
                ExploreCollectionCard(collection: collection)
            }
        }
        .onRoute { (collection: ExploreCollection) in
            AppRoute.movieDetail(movieId: collection.intId)
        }
        .layout {
            .carousel(
                itemWidth: .absolute(240),
                itemHeight: .absolute(140)
            )
            .spacing(16)
            .insets(top: 0, leading: 24, bottom: 24, trailing: 24)
            .supplementaryHeader(height: .estimated(60))
        }
    }
    
    private var arrivalsSection: AnySection {
        AnySection(
            id: ExploreSection.arrivals,
            items: store.state.map { $0.arrivals },
            header: Header {
                ExploreHeader(title: "Just Arrived", subtitle: "New titles this week")
            }
        ) { arrival in
            AnyCell(arrival, id: arrival.id) { arrival in
                ExploreArrivalRow(arrival: arrival)
            }
        }
        .onRoute { (arrival: ExploreArrival) in
            AppRoute.movieDetail(movieId: arrival.intId)
        }
        .layout {
            .list(itemHeight: .estimated(80))
            .spacing(8)
            .insets(top: 0, leading: 24, bottom: 24, trailing: 24)
            .supplementaryHeader(height: .estimated(60))
        }
    }
    
    // MARK: - Components
    
    private var headerOverlay: View {
        ZStackView {
            BlurView(style: .dark)
            HStackView {
                LabelView("Explore")
                    .font(.systemFont(ofSize: 32, weight: .semibold))
                    .color(.white)
                SpacerView()
                ImageView(UIImage(systemName: "magnifyingglass"))
                    .tintColor(.white)
                    .size(width: 24, height: 24)
                    .contentMode(.scaleAspectFit)
                    .onRoute(AppRoute.search)
            }
            .padding(insets: .init(top: 12, left: 24, bottom: 12, right: 24))
        }
        .border(color: UIColor(white: 1.0, alpha: 0.05), lineWidth: 1)
        .height(48)
        .safeArea(false)
        .zIndex(1000)
        .position(.top)
    }
}
