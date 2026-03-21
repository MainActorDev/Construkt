import Foundation
import ConstruktKit

public struct Cast: Decodable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let character: String
    public let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
    }
    
    public var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
}

public struct Crew: Decodable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let job: String
    public let department: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case job
        case department
    }
}

public struct CreditsResponse: Decodable, Equatable, Sendable {
    public let cast: [Cast]
    public let crew: [Crew]
}
