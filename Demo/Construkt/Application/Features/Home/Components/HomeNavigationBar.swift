import UIKit
import ConstruktKit

struct HomeNavigationBar: ViewBuilder {
    let isLoading: AnyViewBinding<Bool>
    let scrollOffset: AnyViewBinding<CGFloat>
    var onSearchTap: ((UIView) -> Void)?
    
    private enum Layout {
        static let fadeDistance: CGFloat = 100
    }
    
    var body: View {
        ZStackView {
            // Gradient Background
            GradientView(colors: [.black.withAlphaComponent(0.8), .black.withAlphaComponent(0.3)])
                .height(100)
                .alpha(0) // Start transparent
                .onReceive(scrollOffset) { context in
                    context.view.alpha = context.value.scrollProgress(over: Layout.fadeDistance)
                }
            
            // Navbar Content
            CustomNavigationBar(
                customTitle: LabelView("LUMINA")
                    .font(.systemFont(ofSize: 24, weight: .bold))
                    .padding(insets: .init(top: 0, left: 4, bottom: 0, right: 0))
                    .color(bind: isLoading.map { isLoading in
                        return isLoading ? .gray : .white
                    }),
                trailing: [
                    ImageView(UIImage(systemName: "magnifyingglass"))
                        .tintColor(.white)
                        .size(width: 24, height: 24)
                        .contentMode(.scaleAspectFit)
                        .onTapGesture { context in onSearchTap?(context.view) },
                    ImageView(UIImage(systemName: "person.crop.circle.fill"))
                        .tintColor(.gray)
                        .size(width: 32, height: 32)
                        .cornerRadius(16)
                        .clipsToBounds(true)
                        .backgroundColor(UIColor(white: 1.0, alpha: 0.2))
                        .border(color: .white, lineWidth: 1)
                ]
            )
        }
        .position(.top) // Pin to top without filling screen
        .height(120) // Explicit height
    }
}
