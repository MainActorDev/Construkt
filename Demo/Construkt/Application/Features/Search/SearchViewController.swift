import UIKit
import ConstruktKit

public class SearchViewController: UIViewController {

    private let store: FeatureStore<SearchFeature>
    @Variable private var searchQuery: String = ""

    public init(store: FeatureStore<SearchFeature> = SearchFeatureModule.makeStore()) {
        self.store = store
        self.searchQuery = store.state.wrappedValue.query
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor("#0A0A0A")
        view.embed(body)
    }

    private var body: View {
        ZStackView {
            VStackView(spacing: 16) {
                // Search Bar
                searchBar

                // Search Results
                ZStackView {
                    // Empty State
                    LabelView("No movies")
                        .color(.lightGray)
                        .alignment(.center)
                        .font(.systemFont(ofSize: 16, weight: .medium))
                        .visible(false)
                        .onReceive(store.isInitialObservable) { context in
                            context.view.isHidden = !context.value
                        }

                    LabelView("No results found.")
                        .color(.lightGray)
                        .alignment(.center)
                        .font(.systemFont(ofSize: 16, weight: .medium))
                        .visible(false)
                        .onReceive(store.isEmptyObservable) { context in
                            context.view.isHidden = !context.value
                        }


                    // List
                    CollectionView {
                        AnySection(id: SearchSection.results, items: store.moviesObservable) { movie in
                            AnyCell(movie, id: movie.id) { movie in
                                MovieSearchRow(movie: movie)
                            }
                        }
                        .onSelect(on: self) { (self, movie: Movie) in
                            self.view.route(AppRoute.movieDetail(movieId: movie.id), sender: nil)
                        }
                        .shimmer(count: 8, when: store.isLoadingObservable) {
                            MovieSearchRow(movie: .placeholder)
                        }
                        .layout {
                            .list(itemHeight: .absolute(120))
                            .spacing(16)
                            .insets(.init(v: 16, h: 15))
                        }
                    }
                    .backgroundColor(.clear)
                }
                .backgroundColor(UIColor("#0A0A0A"))
            }
        }
    }

    private var searchBar: View {
        HStackView(spacing: 8) {
            ImageView(systemName: "chevron.left")
                .tintColor(.white)
                .size(width: 24, height: 24)
                .contentMode(.scaleAspectFit)
                .onTapGesture { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }

            ImageView(UIImage(systemName: "magnifyingglass"))
                .tintColor(.lightGray)
                .size(width: 20, height: 20)
            
            TextField("Search for a movie...")
                .text(bidirectionalBind: $searchQuery)
                .onChange { [weak self] context in
                    self?.store.updateSearchQuery(context.value ?? "")
                }
                .with { tf in
                    tf.font = .systemFont(ofSize: 16, weight: .regular)
                    tf.textColor = .white
                    tf.attributedPlaceholder = NSAttributedString(
                        string: "Search for a movie...",
                        attributes: [.foregroundColor: UIColor.lightGray]
                    )
                }
        }
        .padding(insets: .init(top: 12, left: 16, bottom: 12, right: 16))
        .cornerRadius(12)
        .backgroundColor(UIColor("#0A0A0A"))
        .zIndex(100)
        .height(48)
    }
}

// MARK: - Row View

struct MovieSearchRow: ViewBuilder {
    
    let movie: Movie
    
    var body: View {
        HStackView(spacing: 16) {
            ImageView(url: movie.posterURL, placeholder: UIImage(systemName: "film.fill"))
                .contentMode(movie.posterURL == nil ? .center : .scaleAspectFill)
                .backgroundColor(.darkGray)
                .tintColor(.white)
                .height(120)
                .contentCompressionResistancePriority(.required, for: .horizontal)
                .contentHuggingPriority(.required, for: .horizontal)
                .with { view in
                    let aspectConstraint = view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: 80.0/120.0)
                    aspectConstraint.priority = .required
                    aspectConstraint.isActive = true
                }
                .cornerRadius(8)
                .clipsToBounds(true)
                .shimmerable(true)

            VStackView(spacing: 4) {
                LabelView(movie.title)
                    .font(.systemFont(ofSize: 16, weight: .bold))
                    .color(.white)
                    .numberOfLines(2)
                    .shimmerable(true)
                
                HStackView(spacing: 4) {
                    ImageView(UIImage(systemName: "star.fill"))
                        .tintColor(.systemYellow)
                        .size(width: 14, height: 14)
                    
                    LabelView(String(format: "%.1f", movie.voteAverage))
                        .font(.systemFont(ofSize: 14, weight: .regular))
                        .color(.systemYellow)
                }
                .alignment(.center)
                .shimmerable(true)
                
                SpacerView()
            }
            .alignment(.leading)
            .padding(top: 8, left: 0, bottom: 8, right: 0)
        }
        .backgroundColor(UIColor("#1A1A1A"))
        .cornerRadius(12)
        .padding(12)
    }
}

enum SearchSection: String, SectionConfigIdentifier {
    case results
    
    var uniqueId: String { rawValue }
}
