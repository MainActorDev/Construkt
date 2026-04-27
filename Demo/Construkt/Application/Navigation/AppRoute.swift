import Foundation


public enum AppRoute: Codable, Equatable, Hashable, Sendable {
    case home
    case explore
    case movieDetail(movieId: Int)
    case movieList(title: String, sectionTypeRaw: String, genreId: Int?, genreName: String?, allGenres: [Genre]?)
    case search
    case profile
    case web(url: URL)
    case tagCloud
    case back
    case bottomSheet
    case toast(message: String, position: ToastPosition)
}

public enum ToastPosition: String, Codable, Sendable {
    case top
    case bottom
}
