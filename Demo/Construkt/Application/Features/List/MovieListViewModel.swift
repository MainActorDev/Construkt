import Foundation
import ConstruktKit

public struct MovieListFilterItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let isSelected: Bool
    public let genre: Genre?
}

public struct MovieListFeature: FeatureSpec {
    public struct State: Equatable, Sendable {
        public var title = ""
        public var sectionTypeRaw = HomeSection.categories.rawValue
        public var genres: [Genre] = []
        public var movies: [Movie] = []
        public var selectedGenre: Genre?
        public var isLoading = false
        public var error: String?
        public var paginationState = ListPaginationModel()
    }

    public enum Intent: Sendable {
        case loadInitial
        case selectGenre(Genre?)
        case loadMore
        case refresh
        case pageLoaded(results: [Movie], totalPages: Int, reset: Bool)
        case pageFailed(String)
    }

    public enum Effect: Hashable, Sendable {
        case fetchPage(page: Int, genreId: Int?, sectionTypeRaw: String, reset: Bool)
    }

    public enum Output: Sendable {
        case none
    }

    public struct Dependencies: Sendable {
        let gateway: MovieListFeatureGateway
    }

    public static var initialState: State {
        .init()
    }

    public static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .loadInitial, .refresh:
            state.movies = []
            state.error = nil
            state.isLoading = true
            state.paginationState = .init(currentPage: 1, isPaginating: false, isLastPage: false)
            return .init(
                effects: [
                    .fetchPage(
                        page: state.paginationState.currentPage,
                        genreId: state.selectedGenre?.id,
                        sectionTypeRaw: state.sectionTypeRaw,
                        reset: true
                    )
                ]
            )

        case .selectGenre(let genre):
            guard state.selectedGenre != genre else {
                return .none
            }

            state.selectedGenre = genre
            state.movies = []
            state.error = nil
            state.isLoading = true
            state.paginationState = .init(currentPage: 1, isPaginating: false, isLastPage: false)
            return .init(
                effects: [
                    .fetchPage(
                        page: state.paginationState.currentPage,
                        genreId: state.selectedGenre?.id,
                        sectionTypeRaw: state.sectionTypeRaw,
                        reset: true
                    )
                ]
            )

        case .loadMore:
            guard !state.paginationState.isPaginating, !state.paginationState.isLastPage else {
                return .none
            }

            state.paginationState = .init(
                currentPage: state.paginationState.currentPage,
                isPaginating: true,
                isLastPage: state.paginationState.isLastPage
            )
            state.error = nil
            return .init(
                effects: [
                    .fetchPage(
                        page: state.paginationState.currentPage,
                        genreId: state.selectedGenre?.id,
                        sectionTypeRaw: state.sectionTypeRaw,
                        reset: false
                    )
                ]
            )

        case .pageLoaded(let results, let totalPages, let reset):
            if reset {
                state.movies = results
            } else {
                state.movies.append(contentsOf: results)
            }

            let newPage = state.paginationState.currentPage + 1
            let isLastPage = newPage > totalPages
            state.paginationState = .init(
                currentPage: newPage,
                isPaginating: false,
                isLastPage: isLastPage
            )
            state.isLoading = false
            return .none

        case .pageFailed(let message):
            state.error = message
            state.paginationState = .init(
                currentPage: state.paginationState.currentPage,
                isPaginating: false,
                isLastPage: state.paginationState.isLastPage
            )
            state.isLoading = false
            return .none
        }
    }

    public static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .fetchPage(_, _, _, let reset):
            return reset ? .latest("movie-list-reset") : .dropIfRunning("movie-list-pagination")
        }
    }
}

public enum MovieListFeatureModule {
    static func makeStore(
        title: String,
        sectionType: HomeSection,
        genres: [Genre],
        selectedGenre: Genre?,
        service: MovieServiceProtocol = MovieService()
    ) -> FeatureStore<MovieListFeature> {
        FeatureStore(
            initialState: .init(
                title: title,
                sectionTypeRaw: sectionType.rawValue,
                genres: genres,
                movies: [],
                selectedGenre: selectedGenre,
                isLoading: false,
                error: nil,
                paginationState: .init()
            ),
            dependencies: .init(gateway: MovieListFeatureGateway(service: service))
        ) { effect, dependencies in
            switch effect {
            case .fetchPage(let page, let genreId, let sectionTypeRaw, let reset):
                do {
                    let response: MovieResponse
                    if let genreId {
                        response = try await dependencies.gateway.discoverMovies(page: page, genreId: genreId)
                    } else {
                        switch sectionTypeRaw {
                        case HomeSection.popular.rawValue:
                            response = try await dependencies.gateway.getPopularMovies(page: page)
                        case HomeSection.upcoming.rawValue:
                            response = try await dependencies.gateway.getNowPlayingMovies(page: page)
                        case HomeSection.topRated.rawValue:
                            response = try await dependencies.gateway.getTopRatedMovies(page: page)
                        default:
                            response = try await dependencies.gateway.getNowPlayingMovies(page: page)
                        }
                    }

                    return .init(
                        intents: [
                            .pageLoaded(
                                results: response.results,
                                totalPages: response.totalPages,
                                reset: reset
                            )
                        ]
                    )
                } catch {
                    return .init(intents: [.pageFailed(error.localizedDescription)])
                }
            }
        }
    }
}

public actor MovieListFeatureGateway {
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

    func discoverMovies(page: Int, genreId: Int?) async throws -> MovieResponse {
        try await service.discoverMovies(page: page, genreId: genreId)
    }
}

public extension FeatureStore where F == MovieListFeature {
    var title: String {
        state.wrappedValue.title
    }

    var moviesObservable: AnyViewBinding<[Movie]> {
        state.map { $0.movies }
    }

    var selectedGenreObservable: AnyViewBinding<Genre?> {
        state.map { $0.selectedGenre }
    }

    var filterItemsObservable: AnyViewBinding<[MovieListFilterItem]> {
        state.map { state in
            let allItem = MovieListFilterItem(id: -1, title: "All", isSelected: state.selectedGenre == nil, genre: nil)
            let items = state.genres.map { genre in
                MovieListFilterItem(
                    id: genre.id,
                    title: genre.name,
                    isSelected: state.selectedGenre?.id == genre.id,
                    genre: genre
                )
            }
            return [allItem] + items
        }
    }

    var paginationStateBinding: AnyViewBinding<ListPaginationModel> {
        state.map { $0.paginationState }
    }

    var isLoadingBinding: AnyViewBinding<Bool> {
        state.map { $0.isLoading }
    }

    func loadInitial() {
        dispatch(.loadInitial)
    }

    func selectGenre(_ genre: Genre?) {
        dispatch(.selectGenre(genre))
    }

    func loadMore() {
        dispatch(.loadMore)
    }

    func refresh() {
        dispatch(.refresh)
    }
}
