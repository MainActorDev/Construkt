import Foundation
import ConstruktKit

public struct MovieFeature: FeatureSpec {
    public struct State: Equatable, Sendable {
        public var nowPlaying: LoadableState<[Movie]> = .initial
        public var popular: LoadableState<[Movie]> = .initial
        public var upcoming: LoadableState<[Movie]> = .initial
        public var topRated: LoadableState<[Movie]> = .initial
        public var genres: LoadableState<[Genre]> = .initial
        public var selectedMovie: MovieDetail?
        public var casts: LoadableState<[Cast]> = .initial
        public var isDetailsLoading = false

        public var isAnyLoading: Bool {
            nowPlaying.isLoading || popular.isLoading || upcoming.isLoading || topRated.isLoading || genres.isLoading
        }

        public var isEmpty: Bool {
            (nowPlaying.value?.isEmpty == true) &&
            (popular.value?.isEmpty == true) &&
            (upcoming.value?.isEmpty == true) &&
            (topRated.value?.isEmpty == true) &&
            (genres.value?.isEmpty == true)
        }
    }

    public enum Intent: Sendable {
        case loadHomeData
        case nowPlayingLoaded([Movie])
        case popularLoaded([Movie])
        case upcomingLoaded([Movie])
        case topRatedLoaded([Movie])
        case genresLoaded([Genre])
        case genresFailed(String)
        case selectMovie(Movie)
        case movieDetailsLoaded(MovieDetail)
        case movieDetailsFailed
        case movieCastsLoaded([Cast])
        case movieCastsFailed(String)
    }

    public enum Effect: Sendable, Hashable {
        case fetchNowPlaying
        case fetchPopular
        case fetchUpcoming
        case fetchTopRated
        case fetchGenres
        case fetchMovieDetails(id: Int)
        case fetchMovieCasts(id: Int)
    }

    public enum Output: Sendable {
        case none
    }

    public struct Dependencies: Sendable {
        let gateway: MovieFeatureGateway
    }

    public static var initialState: State {
        .init()
    }

    public static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .loadHomeData:
            state.nowPlaying = .loading
            state.popular = .loading
            state.upcoming = .loading
            state.topRated = .loading
            state.genres = .loading
            return .init(
                effects: [
                    .fetchNowPlaying,
                    .fetchPopular,
                    .fetchUpcoming,
                    .fetchTopRated,
                    .fetchGenres,
                ]
            )

        case .nowPlayingLoaded(let movies):
            state.nowPlaying = .loaded(movies)
            return .none

        case .popularLoaded(let movies):
            state.popular = .loaded(movies)
            return .none

        case .upcomingLoaded(let movies):
            state.upcoming = .loaded(movies)
            return .none

        case .topRatedLoaded(let movies):
            state.topRated = .loaded(movies)
            return .none

        case .genresLoaded(let genres):
            state.genres = .loaded(genres)
            return .none

        case .genresFailed(let message):
            state.genres = .error(message)
            return .none

        case .selectMovie(let movie):
            state.isDetailsLoading = true
            state.casts = .loading
            return .init(effects: [.fetchMovieCasts(id: movie.id), .fetchMovieDetails(id: movie.id)])

        case .movieDetailsLoaded(let details):
            state.selectedMovie = details
            state.isDetailsLoading = false
            return .none

        case .movieDetailsFailed:
            state.isDetailsLoading = false
            return .none

        case .movieCastsLoaded(let casts):
            state.casts = .loaded(casts)
            return .none

        case .movieCastsFailed(let message):
            state.casts = .error(message)
            return .none
        }
    }

    public static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .fetchNowPlaying:
            return .latest("movie-home-now-playing")
        case .fetchPopular:
            return .latest("movie-home-popular")
        case .fetchUpcoming:
            return .latest("movie-home-upcoming")
        case .fetchTopRated:
            return .latest("movie-home-top-rated")
        case .fetchGenres:
            return .latest("movie-home-genres")
        case .fetchMovieDetails:
            return .latest("movie-details")
        case .fetchMovieCasts:
            return .latest("movie-casts")
        }
    }

    public static func staleStrategy(for effect: Effect) -> StaleEffectStrategy {
        .accept
    }
}

public enum MovieFeatureModule {
    public static func makeStore(service: MovieServiceProtocol = MovieService()) -> FeatureStore<MovieFeature> {
        FeatureStore(
            dependencies: .init(gateway: MovieFeatureGateway(service: service))
        ) { effect, dependencies in
            switch effect {
            case .fetchNowPlaying:
                do {
                    let response = try await dependencies.gateway.getNowPlayingMovies(page: 1)
                    return .init(intents: [.nowPlayingLoaded(response.results)])
                } catch {
                    return .init(intents: [.nowPlayingLoaded([])])
                }

            case .fetchPopular:
                do {
                    let response = try await dependencies.gateway.getPopularMovies(page: 1)
                    return .init(intents: [.popularLoaded(response.results)])
                } catch {
                    return .init(intents: [.popularLoaded([])])
                }

            case .fetchUpcoming:
                do {
                    let response = try await dependencies.gateway.getPopularMovies(page: 2)
                    return .init(intents: [.upcomingLoaded(response.results)])
                } catch {
                    return .init(intents: [.upcomingLoaded([])])
                }

            case .fetchTopRated:
                do {
                    let response = try await dependencies.gateway.getTopRatedMovies(page: 1)
                    return .init(intents: [.topRatedLoaded(response.results)])
                } catch {
                    return .init(intents: [.topRatedLoaded([])])
                }

            case .fetchGenres:
                do {
                    let response = try await dependencies.gateway.getGenres()
                    return .init(intents: [.genresLoaded(response.genres)])
                } catch {
                    return .init(intents: [.genresFailed(error.localizedDescription)])
                }

            case .fetchMovieDetails(let id):
                do {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    let details = try await dependencies.gateway.getMovieDetails(id: id)
                    return .init(intents: [.movieDetailsLoaded(details)])
                } catch {
                    return .init(intents: [.movieDetailsFailed])
                }

            case .fetchMovieCasts(let id):
                do {
                    let response = try await dependencies.gateway.getMovieCredits(id: id)
                    return .init(intents: [.movieCastsLoaded(response.cast)])
                } catch {
                    return .init(intents: [.movieCastsFailed(error.localizedDescription)])
                }
            }
        }
    }
}

public actor MovieFeatureGateway {
    private let service: MovieServiceProtocol

    public init(service: MovieServiceProtocol) {
        self.service = service
    }

    func getPopularMovies(page: Int) async throws -> MovieResponse {
        try await service.getPopularMovies(page: page)
    }

    func getTopRatedMovies(page: Int) async throws -> MovieResponse {
        try await service.getTopRatedMovies(page: page)
    }

    func getNowPlayingMovies(page: Int) async throws -> MovieResponse {
        try await service.getNowPlayingMovies(page: page)
    }

    func getMovieDetails(id: Int) async throws -> MovieDetail {
        try await service.getMovieDetails(id: id)
    }

    func getMovieCredits(id: Int) async throws -> CreditsResponse {
        try await service.getMovieCredits(id: id)
    }

    func getGenres() async throws -> GenreResponse {
        try await service.getGenres()
    }
}

public extension FeatureStore where F == MovieFeature {
    var movieDetails: AnyViewBinding<MovieDetail?> {
        state.map { $0.selectedMovie }
    }

    var movieCasts: AnyViewBinding<[Cast]> {
        state.map { $0.casts }.mapItems()
    }

    var isCastsLoading: AnyViewBinding<Bool> {
        state.map { $0.casts }.mapLoading()
    }

    var isLoadingDetails: AnyViewBinding<Bool> {
        state.map { $0.isDetailsLoading }
    }

    var nowPlayingMovies: AnyViewBinding<[Movie]> {
        state.map { $0.nowPlaying }.mapItems()
    }

    var isNowPlayingLoading: AnyViewBinding<Bool> {
        state.map { $0.nowPlaying }.mapLoading()
    }

    var popularSectionMovies: AnyViewBinding<[Movie]> {
        state.map { $0.popular }.mapItems()
    }

    var isPopularSectionLoading: AnyViewBinding<Bool> {
        state.map { $0.popular }.mapLoading()
    }

    var upcomingMovies: AnyViewBinding<[Movie]> {
        state.map { $0.upcoming }.mapItems()
    }

    var isUpcomingLoading: AnyViewBinding<Bool> {
        state.map { $0.upcoming }.mapLoading()
    }

    var topRatedMovies: AnyViewBinding<[Movie]> {
        state.map { $0.topRated }.mapItems()
    }

    var isTopRatedLoading: AnyViewBinding<Bool> {
        state.map { $0.topRated }.mapLoading()
    }

    var genres: AnyViewBinding<[Genre]> {
        state.map { $0.genres }.mapItems()
    }

    var isLoadingGenres: AnyViewBinding<Bool> {
        state.map { $0.genres }.mapLoading()
    }

    var isEmptyObservable: AnyViewBinding<Bool> {
        state.map { !$0.isAnyLoading && $0.isEmpty }
    }

    var currentGenres: [Genre] {
        state.wrappedValue.genres.value ?? []
    }

    func loadHomeData() {
        dispatch(.loadHomeData)
    }

    func selectMovie(_ movie: Movie) {
        dispatch(.selectMovie(movie))
    }
}
