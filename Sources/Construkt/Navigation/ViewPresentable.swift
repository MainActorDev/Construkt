//
//  ViewPresentable.swift
//  Construkt
//

import UIKit

public struct ViewPresentable: ConstruktPresentable {
    private let viewBuilder: () -> View
    
    public init(_ builder: @escaping () -> View) {
        self.viewBuilder = builder
    }
    
    public func toPresentable() -> UIViewController {
        ViewHostController(viewBuilder: viewBuilder)
    }
}

private final class ViewHostController: UIViewController {
    let viewBuilder: () -> View
    
    init(viewBuilder: @escaping () -> View) {
        self.viewBuilder = viewBuilder
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.embed(viewBuilder())
    }
}
