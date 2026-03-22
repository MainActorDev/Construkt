import Foundation
import ConstruktKit

public struct SearchFeature: FeatureSpec {
    public struct State: Equatable, Sendable {
        public var query = ""
        public var searchResults: LoadableState<[Movie]> = .initial
    }

    public enum Intent: Sendable {
        case queryChanged(String)
        case resultsLoaded([Movie])
        case resultsFailed(String)
    }

    public enum Effect: Hashable, Sendable {
        case search(query: String)
    }

    public enum Output: Sendable {
        case none
    }

    public struct Dependencies: Sendable {
        let gateway: SearchFeatureGateway
    }

    public static var initialState: State {
        .init()
    }

    public static func reduce(state: inout State, intent: Intent) -> ReduceResult<Effect, Output> {
        switch intent {
        case .queryChanged(let query):
            state.query = query
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                state.searchResults = .initial
                return .none
            }

            state.searchResults = .loading
            return .init(effects: [.search(query: trimmed)])

        case .resultsLoaded(let movies):
            state.searchResults = .loaded(movies)
            return .none

        case .resultsFailed(let message):
            state.searchResults = .error(message)
            return .none
        }
    }

    public static func policy(for effect: Effect) -> EffectPolicy {
        switch effect {
        case .search:
            return .debounce("search-query", 0.5)
        }
    }
}

public enum SearchFeatureModule {
    public static func makeStore(service: MovieServiceProtocol = MovieService()) -> FeatureStore<SearchFeature> {
        FeatureStore(
            dependencies: .init(gateway: SearchFeatureGateway(service: service))
        ) { effect, dependencies in
            switch effect {
            case .search(let query):
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    let result = try await dependencies.gateway.searchMovies(query: query, page: 1)
                    return .init(intents: [.resultsLoaded(result.results)])
                } catch {
                    return .init(intents: [.resultsFailed(error.localizedDescription)])
                }
            }
        }
    }
}

public actor SearchFeatureGateway {
    private let service: MovieServiceProtocol

    public init(service: MovieServiceProtocol) {
        self.service = service
    }

    func searchMovies(query: String, page: Int) async throws -> MovieResponse {
        try await service.searchMovies(query: query, page: page)
    }
}

public extension FeatureStore where F == SearchFeature {
    var moviesObservable: AnyViewBinding<[Movie]> {
        state.map { $0.searchResults }.mapItems()
    }

    var isLoadingObservable: AnyViewBinding<Bool> {
        state.map { $0.searchResults.isLoading }
    }

    var isEmptyObservable: AnyViewBinding<Bool> {
        state.map {
            !$0.searchResults.isLoading && $0.searchResults.value?.isEmpty == true && !$0.query.isEmpty
        }
    }

    var isInitialObservable: AnyViewBinding<Bool> {
        state.map {
            if case .initial = $0.searchResults {
                return true
            }
            return false
        }
    }

    func updateSearchQuery(_ query: String) {
        dispatch(.queryChanged(query))
    }
}
