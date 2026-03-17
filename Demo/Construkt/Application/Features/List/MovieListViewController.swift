import UIKit
import ConstruktKit

enum MovieListSection: String, SectionConfigIdentifier {
    case filter
    case grid
    
    var uniqueId: String { rawValue }
}

class MovieListViewController: UIViewController {
    
    private let viewModel: MovieListViewModel
    private var filterCollectionViewWrapper: CollectionViewWrapperView?
    
    init(viewModel: MovieListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { nil }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        observe()
    }
    
    private func observe() {
        viewModel.$selectedGenre
            .compactMap { $0 }
            .distinctUntilChanged()
            .observe(on: .main) { [weak self] item in
                self?.scrollToFilter(item.id)
            }
            .store(in: cancelBag)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor("#0A0A0A")
        view.embed(
            ZStackView {
                VStackView {
                    CollectionView {
                        filterSection
                    }
                    .reference(&filterCollectionViewWrapper)
                    .backgroundColor(UIColor("#0A0A0A"))
                    .height(56)
                    .zIndex(100)
                    .clipsToBounds(true)

                    CollectionView {
                         gridSection
                    }
                    .pagination(model: viewModel.$paginationState) { [weak self] _ in
                        self?.viewModel.loadMore()
                    }
                    .onRefresh(viewModel.$isLoading) { [weak self] in
                        self?.viewModel.refresh()
                    }
                }
                .padding(top: 40)
                
                MovieListNavBar(title: viewModel.title, onTapBack: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                })
            }
        )
    }
    
    private var filterSection: AnySection {
        AnySection(
            id: MovieListSection.filter,
            items: viewModel.filterItemsObservable
        ) { item in
            AnyCell(item, id: item.id) { item in
                GenresCell(
                    id: item.id,
                    genre: Genre(id: item.id, name: item.title),
                    isSelected: item.isSelected
                )
            }
        }
        .onSelect(on: self) { (self, item: MovieListViewModel.FilterItem) in
            self.viewModel.selectGenre(item.genre)
        }
        .layout { _ in
            .carousel(
                itemWidth: .estimated(100),
                itemHeight: .absolute(40)
            )
            .spacing(12)
            .insets(top: 8, leading: 16, bottom: 8, trailing: 16)
        }
    }
    
    private var gridSection: AnySection {
        AnySection(
            id:  MovieListSection.grid,
            items: viewModel.moviesObservable.map { Array($0.enumerated()) },
            footer: Footer { [viewModel] in
                CenteredView {
                    ZStackView {
                        ActivityIndicator(style: .large)
                            .color(.white)
                            .animating(viewModel.$paginationState.map { $0.isPaginating })
                    }
                    .padding(12)
                }
            }
        ) { index, movie in
            AnyCell(movie, id: "movie-\(movie.id)-\(index)") { movie in
                MovieGridCell(movie: movie)
            }
        }
        .onSelect(on: self) { (self, movie: Movie) in
            self.showDetail(for: movie)
        }
        .shimmer(count: 8, when: viewModel.$isLoading) {
            MovieGridCell(movie: .placeholder)
        }
        .layout { _ in
            .grid(
                itemHeight: .fractionalWidth(0.75),
                columns: 2,
                itemInsets: .init(top: 12, leading: 8, bottom: 12, trailing: 8)
            )
            .supplementaryFooter(height: .absolute(40))
        }
    }
    
    private func showDetail(for movie: Movie) {
        let detailVC = MovieDetailView(movie: movie)
            .toPresentable(trackingLabel: "MovieDetailView(from:MovieList)")
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func scrollToFilter(_ id: Int) {        
        guard let wrapper = filterCollectionViewWrapper,
              let dataSource = wrapper.collectionView.dataSource as? AnyCollectionDiffableDataSource,
              dataSource.snapshot().numberOfItems > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.scrollToFilter(id)
            }
            return
        }
        
        let searchKey = CellConfig(id: id)
        if let indexPath = dataSource.indexPath(for: searchKey) {
            wrapper.collectionView.layoutIfNeeded()
            wrapper.collectionView.scrollToItem(
                at: indexPath,
                at: .centeredHorizontally,
                animated: true
            )
        }
    }
}
