import UIKit
import ConstruktKit


@MainActor
protocol ScreenFactoryProtocol {
    func makeScreen(for route: AppRoute) -> ConstruktPresentable
}

@MainActor
final class ScreenFactory: ScreenFactoryProtocol {
    init() {}
    
    func makeScreen(for route: AppRoute) -> ConstruktPresentable {
        switch route {
        case .home:
            return HomeView().toPresentable()
        case .explore:
            return ExploreView().toPresentable()
        case .search:
            return SearchViewController()
        case .profile:
            return ProfileView().toPresentable(title: ProfileView.navigationTitle)
        case .movieDetail(let id):
            let movie = Movie(id: id)
            return MovieDetailView(movie: movie).toPresentable(trackingLabel: "Movie Detail")
            
        case .movieList(let title, let sectionTypeRaw, let genreId, let genreName, let allGenres):
            let sectionType = HomeSection(rawValue: sectionTypeRaw) ?? .categories
            var selectedGenre: Genre? = nil
            if let gId = genreId, let gName = genreName {
                selectedGenre = Genre(id: gId, name: gName)
            }

            let store = MovieListFeatureModule.makeStore(
                title: title,
                sectionType: sectionType,
                genres: allGenres ?? (selectedGenre != nil ? [selectedGenre!] : []),
                selectedGenre: selectedGenre
            )
            return MovieListViewController(store: store)
            
        case .web(let url):
            let vc = UIViewController()
            vc.title = url.absoluteString
            return vc
        default:
            return UIViewController()
        }
    }
}
