//
//  Created by @thatswiftdev on 11/02/26.
//

import Foundation
import ConstruktKit

/// A standard struct modeling pagination state, tailored for infinite scrolling within `CollectionListViewController`s.
public struct ListPaginationModel: Equatable, Sendable {
    public let currentPage: Int
    /// Set to true if a network request is currently in flight for the *next* page.
    public let isPaginating: Bool
    /// Set to true if there are no more pages to load.
    public let isLastPage: Bool
    
    public init(
        currentPage: Int = 1,
        isPaginating: Bool = false,
        isLastPage: Bool = false
    ) {
        self.currentPage = currentPage
        self.isPaginating = isPaginating
        self.isLastPage = isLastPage
    }
    
    public var nextPage: Int {
        return currentPage + 1
    }
}
