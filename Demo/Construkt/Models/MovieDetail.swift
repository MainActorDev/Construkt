import Foundation
import ConstruktKit

public struct MovieDetail: Decodable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let overview: String
    public let releaseDate: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double
    
    // Extended properties
    public let runtime: Int?
    public let genres: [Genre]?
    public let credits: CreditsResponse?
    public let similar: MovieResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case runtime
        case genres
        case credits
        case similar
    }
    
    public var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
    
    public var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(path)")
    }
    
    // Formatting helpers
    public var durationText: String {
        guard let runtime = runtime, runtime > 0 else { return "" }
        let hours = runtime / 60
        let minutes = runtime % 60
        return "\(hours)h \(minutes)m"
    }
    
    public var genreText: String {
        genres?.prefix(2).map { $0.name }.joined(separator: ", ") ?? ""
    }
    
    public var director: Crew? {
        credits?.crew.first(where: { $0.job == "Director" })
    }
}
