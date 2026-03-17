import UIKit
import ConstruktKit

// MARK: - Search Bar Component
struct ExploreSearchBar: ViewBuilder {
    let viewModel: ExploreViewModel
    
    var body: View {
        HStackView {
            ImageView(UIImage(systemName: "magnifyingglass"))
                .tintColor(.gray)
                .size(width: 20, height: 20)
            
            TextField(placeholder: "Movies, shows, actors...")
                .text(bidirectionalBind: viewModel.$searchQuery)
                .with {
                    $0.font = .systemFont(ofSize: 14, weight: .medium)
                }
                .autocapitalizationType(.none)
                .textColor(.white)
                    
            ImageView(UIImage(systemName: "slider.horizontal.3"))
                .tintColor(.gray)
                .size(width: 20, height: 20)
        }
        .alignment(.center)
        .padding(top: 12, left: 16, bottom: 12, right: 16)
        .backgroundColor(UIColor(white: 0.15, alpha: 0.8))
        .cornerRadius(12)
        .border(color: UIColor(white: 0.2, alpha: 1), lineWidth: 1)
    }
}

// MARK: - Genre Card Component
struct ExploreGenreCard: ViewBuilder {
    let genre: ExploreGenre
    
    var body: View {
        ZStackView {
            // Abstract Decorative Icon in background
            ImageView(UIImage(systemName: "film.fill"))
                .tintColor(UIColor.white.withAlphaComponent(0.15))
                .size(width: 80, height: 80)
                .position(.bottomRight)
                .margins(bottom: -20, right: -20)
            
            // Gradient Overlay
            LinearGradient(colors: [UIColor.clear, UIColor.black.withAlphaComponent(0.4)])
            
            // Title
            LabelView(genre.name)
                .font(.systemFont(ofSize: 16, weight: .bold))
                .color(.white)
                .position(.bottomLeft)
                .margins(12)
        }
        .backgroundColor(UIColor(genre.colorHex))
        .height(96)
        .cornerRadius(12)
        .border(color: UIColor(white: 1.0, alpha: 0.1), lineWidth: 1)
        .clipsToBounds(true)
    }
}

// MARK: - Collection Card Component
struct ExploreCollectionCard: ViewBuilder {
    let collection: ExploreCollection
    
    var body: View {
        ZStackView {
            ImageView(url: URL(string: collection.imageURL))
                .contentMode(.scaleAspectFill)
                .clipsToBounds(true)
                .alpha(0.7)
            
            LinearGradient(
                colors: [UIColor.black.withAlphaComponent(0.8), UIColor.clear],
                startPoint: CGPoint(x: 0.0, y: 0.5),
                endPoint: CGPoint(x: 1.0, y: 0.5)
            )
            
            VStackView {
                SpacerView()
                LabelView(collection.topic)
                    .font(.systemFont(ofSize: 10, weight: .bold))
                    .color(.systemYellow)
                
                LabelView(collection.title)
                    .font(.systemFont(ofSize: 20, weight: .medium))
                    .color(.white)
                    .numberOfLines(2)
            }
            .spacing(4)
            .alignment(.leading)
            .position(.left)
            .margins(20)
        }
        .width(240)
        .height(140)
        .cornerRadius(12)
        .border(color: UIColor(white: 1.0, alpha: 0.1), lineWidth: 1)
        .clipsToBounds(true)
    }
}

// MARK: - Arrival List Item Component
struct ExploreArrivalRow: ViewBuilder {
    let arrival: ExploreArrival
    
    var body: View {
        HStackView {
            ImageView(url: URL(string: arrival.imageURL)!)
                .contentMode(.scaleAspectFill)
                .size(width: 56, height: 56)
                .cornerRadius(8)
                .border(color: UIColor(white: 1.0, alpha: 0.05), lineWidth: 1)
                .clipsToBounds(true)
            
            VStackView {
                LabelView(arrival.title)
                    .font(.systemFont(ofSize: 14, weight: .medium))
                    .color(.white)
                
                LabelView(arrival.subtitle)
                    .font(.systemFont(ofSize: 12, weight: .regular))
                    .color(.gray)
            }
            .spacing(2)
            
            SpacerView()
            
            // Forward button
            ZStackView {
                ImageView(UIImage(systemName: "chevron.right"))
                    .tintColor(.gray)
                    .size(width: 8, height: 14)
                    .position(.center)
            }
            .size(width: 32, height: 32)
            .cornerRadius(16)
            .border(color: UIColor(white: 0.2, alpha: 1), lineWidth: 1)
        }
        .alignment(.center)
        .spacing(16)
        .padding(top: 8, left: 0, bottom: 8, right: 0)
    }
}

// MARK: - Header
struct ExploreHeader: ViewBuilder {
    let title: String
    let subtitle: String?
    
    var body: View {
        VStackView {
            LabelView(title)
                .font(.systemFont(ofSize: 18, weight: .medium))
                .color(.white)
            LabelView(subtitle)
                .font(.systemFont(ofSize: 12, weight: .regular))
                .color(.gray)
                .hidden(subtitle == nil)
        }
        .spacing(4)
        .padding(top: 16, left: 8, bottom: 16, right: 8)
    }
}
