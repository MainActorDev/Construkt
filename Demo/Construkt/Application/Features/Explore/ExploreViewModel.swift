import Foundation
import ConstruktKit

public struct ExploreGenre: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let colorHex: String
}

public struct ExploreCollection: Hashable, Identifiable, Sendable {
    public let id: String
    public let topic: String
    public let title: String
    public let imageURL: String

    var intId: Int {
        Int(id) ?? 0
    }
}

public struct ExploreArrival: Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let imageURL: String

    var intId: Int {
        Int(id) ?? 0
    }
}

public struct ExploreFeature: FeatureSpec {
    public struct State: Equatable, Sendable {
        public var searchQuery = ""
        public var isSearching = false
        public var genres: [ExploreGenre] = []
        public var allGenres: [ExploreGenre] = []
        public var collections: [ExploreCollection] = []
        public var arrivals: [ExploreArrival] = []
    }

    public enum Intent: Sendable {
        case loadData
        case genresLoaded(genres: [ExploreGenre], allGenres: [ExploreGenre])
        case collectionsLoaded([ExploreCollection])
        case arrivalsLoaded([ExploreArrival])
    }

    public enum Effect: Hashable, Sendable {
        case fetchGenres
        case fetchCollections
        case fetchArrivals
    }

    public enum Output: Sendable {
        case none
    }

    public struct Dependencies: Sendable {
        let gateway: ExploreFeatureGateway
    }

    public static var initialState: State {
        .init()
    }

    public static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .loadData:
            return .init(effects: [.fetchGenres, .fetchCollections, .fetchArrivals])

        case .genresLoaded(let genres, let allGenres):
            state.genres = genres
            state.allGenres = allGenres
            return .none

        case .collectionsLoaded(let collections):
            state.collections = collections
            return .none

        case .arrivalsLoaded(let arrivals):
            state.arrivals = arrivals
            return .none
        }
    }

    public static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .fetchGenres:
            return .latest("explore-genres")
        case .fetchCollections:
            return .latest("explore-collections")
        case .fetchArrivals:
            return .latest("explore-arrivals")
        }
    }

    public static func staleStrategy(for effect: Effect) -> StaleEffectStrategy {
        .accept
    }
}

public enum ExploreFeatureModule {
    public static func makeStore(service: MovieServiceProtocol = MovieService()) -> FeatureStore<ExploreFeature> {
        FeatureStore(
            dependencies: .init(gateway: ExploreFeatureGateway(service: service))
        ) { effect, dependencies in
            switch effect {
            case .fetchGenres:
                do {
                    let genreResponse = try await dependencies.gateway.getGenres()
                    let colors = ["#FF3B30", "#5AC8FA", "#FF9500", "#AF52DE"]
                    let allGenres = genreResponse.genres.enumerated().map { index, genre in
                        ExploreGenre(
                            id: String(genre.id),
                            name: genre.name,
                            colorHex: colors[index % colors.count]
                        )
                    }
                    let genres = Array(allGenres.prefix(4))
                    return .init(intents: [.genresLoaded(genres: genres, allGenres: allGenres)])
                } catch {
                    return .none
                }

            case .fetchCollections:
                do {
                    let popular = try await dependencies.gateway.getPopularMovies(page: 1)
                    let collections = popular.results.prefix(5).map { movie in
                        ExploreCollection(
                            id: String(movie.id),
                            topic: "TRENDING",
                            title: movie.title,
                            imageURL: movie.backdropURL?.absoluteString ?? ""
                        )
                    }
                    return .init(intents: [.collectionsLoaded(collections)])
                } catch {
                    return .none
                }

            case .fetchArrivals:
                do {
                    let nowPlaying = try await dependencies.gateway.getNowPlayingMovies(page: 1)
                    let arrivals = nowPlaying.results.prefix(10).map { movie in
                        ExploreArrival(
                            id: String(movie.id),
                            title: movie.title,
                            subtitle: "Score: \(String(format: "%.1f", movie.voteAverage)) • \(movie.releaseDate ?? "Recently Added")",
                            imageURL: movie.backdropURL?.absoluteString ?? ""
                        )
                    }
                    return .init(intents: [.arrivalsLoaded(arrivals)])
                } catch {
                    return .none
                }
            }
        }
    }
}

public actor ExploreFeatureGateway {
    private let service: MovieServiceProtocol

    public init(service: MovieServiceProtocol) {
        self.service = service
    }

    func getGenres() async throws -> GenreResponse {
        try await service.getGenres()
    }

    func getPopularMovies(page: Int) async throws -> MovieResponse {
        try await service.getPopularMovies(page: page)
    }

    func getNowPlayingMovies(page: Int) async throws -> MovieResponse {
        try await service.getNowPlayingMovies(page: page)
    }
}
