//
//  👨‍💻 Created by @thatswiftdev on 04/02/26.
//
//  © 2026, https://github.com/thatswiftdev. All rights reserved.
//
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

// MARK: - Protocols

/// A protocol that identifies types capable of resolving into a reactive binding of `SectionConfig` arrays.
public protocol AnySectionObservable {
    /// Converts the conforming type into a binding of section controllers.
    func asAnySectionObservable() -> AnyViewBinding<[SectionConfig]>
}

extension SectionConfig: AnySectionObservable {
    public func asAnySectionObservable() -> AnyViewBinding<[SectionConfig]> { .just([self]) }
}

extension Array: AnySectionObservable where Element == SectionConfig {
    public func asAnySectionObservable() -> AnyViewBinding<[SectionConfig]> { .just(self) }
}

/// A marker protocol identifying valid declarative components belonging within a `Section` body.
public protocol AnySectionComponent {}

extension Array: AnySectionComponent where Element == CellConfig {}

// MARK: - Section Constructs

/// A declarative wrapper defining a supplementary header view for a `Section`.
public struct Header: AnySectionComponent {
    public let controller: SupplementaryController
    
    /// Initializes the header with a unique ID and a statically structured declarative `View` block.
    public init(id: AnyHashable? = nil, @ViewResultBuilder content: @escaping () -> ViewConvertable) {
        self.controller = SupplementaryController(
            id: id ?? AnyHashable(UUID()),
            elementKind: UICollectionView.elementKindSectionHeader,
            viewType: HostingReusableView<VStackView>.self
        ) { view in
            view.setAnimatedShimmerView(false)
            let views = content().asViews()
            view.host(VStackView(views))
        }
    }
    
    // Internal init for modifier
    private init(_ controller: SupplementaryController) {
        self.controller = controller
    }
    
    /// Imperatively hides or shows the header.
    public func hidden(_ isHidden: Bool) -> Header {
        var copy = self.controller
        copy.isHidden = isHidden
        return Header(copy)
    }
}

/// A declarative wrapper defining a supplementary footer view for a `Section`.
public struct Footer: AnySectionComponent {
    public let controller: SupplementaryController
    
    /// Initializes the footer with a unique ID and a statically structured declarative `View` block.
    public init(id: AnyHashable? = nil, @ViewResultBuilder content: @escaping () -> ViewConvertable) {
        self.controller = SupplementaryController(
            id: id ?? AnyHashable(UUID()),
            elementKind: UICollectionView.elementKindSectionFooter,
            viewType: HostingReusableView<VStackView>.self
        ) { view in
            view.setAnimatedShimmerView(false)
            let views = content().asViews()
            view.host(VStackView(views))
        }
    }
    
    // Internal init for modifier
    private init(_ controller: SupplementaryController) {
        self.controller = controller
    }
    
    /// Imperatively hides or shows the footer.
    public func hidden(_ isHidden: Bool) -> Footer {
        var copy = self.controller
        copy.isHidden = isHidden
        return Footer(copy)
    }
}

// Ensure CellConfig conforms to AnySectionComponent (via AnyCellConvertible wrapper)
public struct CellComponent: AnySectionComponent {
    let cells: [CellConfig]
}

extension CellConfig: AnySectionComponent {}

// MARK: - Section Content Builder

/// An intermediate structure aggregating parsed cells, headers, and footers from a single `AnyAnySectionContentBuilder`.
public struct AnySectionContent {
    var cells: [CellConfig] = []
    var header: SupplementaryController?
    var footer: SupplementaryController?
}

/// A result builder designed to aggregate headers, footers, and cells into a unified `AnySectionContent` model.
@resultBuilder
public struct AnyAnySectionContentBuilder {
    public static func buildBlock(_ components: AnySectionComponent...) -> AnySectionContent {
        var content = AnySectionContent()
        for component in components {
            if let header = component as? Header {
                content.header = header.controller
            } else if let footer = component as? Footer {
                content.footer = footer.controller
            } else if let cell = component as? CellConfig {
                content.cells.append(cell)
            } else if let cellConvertible = component as? AnyCellConvertible {
                content.cells.append(contentsOf: cellConvertible.asCells())
            }
        }
        return content
    }
    
    public static func buildExpression(_ expression: AnyCellConvertible) -> AnySectionComponent {
        return expression
    }
    
    public static func buildExpression(_ expression: Header) -> AnySectionComponent {
        return expression
    }
    
    public static func buildExpression(_ expression: Footer) -> AnySectionComponent {
        return expression
    }
    
    public static func buildOptional(_ component: AnySectionComponent?) -> AnySectionComponent {
         return component ?? CellComponent(cells: [])
    }
    
    public static func buildEither(first: AnySectionComponent) -> AnySectionComponent {
        return first
    }

    public static func buildEither(second: AnySectionComponent) -> AnySectionComponent {
        return second
    }
    
    public static func buildArray(_ components: [AnySectionComponent]) -> AnySectionComponent {
        // Flatten cells
        var cells: [CellConfig] = []
        components.forEach {
            if let cell = $0 as? CellConfig {
                cells.append(cell)
            } else if let convertible = $0 as? AnyCellConvertible {
                cells.append(contentsOf: convertible.asCells())
            }
        }
        return CellComponent(cells: cells)
    }
}

// MARK: - Section Result Builder
/// A robust result builder mapping discrete `Section` definitions into unified binding-powered observables.
@resultBuilder
public struct AnySectionResultBuilder {
    public static func buildBlock() -> AnyViewBinding<[SectionConfig]> {
        .just([])
    }
    
    public static func buildBlock(_ components: AnySectionObservable...) -> AnyViewBinding<[SectionConfig]> {
        let bindings = components.map { $0.asAnySectionObservable() }
        return combineLatestBindings(bindings)
    }
    
    public static func buildIf(_ value: AnySectionObservable?) -> AnyViewBinding<[SectionConfig]> {
        value?.asAnySectionObservable() ?? .just([])
    }
    
    public static func buildEither(first: AnySectionObservable) -> AnyViewBinding<[SectionConfig]> {
        first.asAnySectionObservable()
    }
    
    public static func buildEither(second: AnySectionObservable) -> AnyViewBinding<[SectionConfig]> {
        second.asAnySectionObservable()
    }
    
    public static func buildArray(_ components: [AnySectionObservable]) -> AnyViewBinding<[SectionConfig]> {
        let bindings = components.map { $0.asAnySectionObservable() }
        return combineLatestBindings(bindings)
    }
}


// MARK: - Section
/// A declarative constructor for generating a `SectionConfig` via native data bindings 
/// or static `AnyCellResultBuilder` closures.
public struct AnySection: AnySectionObservable {
    private let binding: AnyViewBinding<[SectionConfig]>
    
    // MARK: Initializers
    
    // Standard initializer handled cleanly by @AnyAnySectionContentBuilder without ambiguity
    
    /// Static Data-binding initializer
    public init<T>(
        id: SectionConfigIdentifier,
        items: [T],
        @AnyCellResultBuilder content: (T) -> [CellConfig]
    ) {
        let cells = items.flatMap { content($0) }
        let section = SectionConfig(identifier: id, cells: cells, header: nil, footer: nil, layoutProvider: nil)
        self.binding = .just([section])
    }
    
    /// Reactive Binding initializer
    public init<B: ViewBinding>(
        id: SectionConfigIdentifier,
        binding: B,
        @AnyCellResultBuilder content: @escaping (B.Value) -> [CellConfig]
    ) {
        self.binding = binding
            .map { items in
                return [SectionConfig(identifier: id, cells: content(items), header: nil, footer: nil, layoutProvider: nil)]
            }
    }
    
    /// Reactive Binding with element iteration helper
    public init<B: ViewBinding, Element>(
        id: SectionConfigIdentifier,
        items binding: B,
        header: Header? = nil,
        footer: Footer? = nil,
        @AnyCellResultBuilder content: @escaping (Element) -> [CellConfig]
    ) where B.Value == [Element] {
        self.binding = binding
            .map { items in
                let cells = items.flatMap { content($0) }
                return [
                    SectionConfig(
                        identifier: id,
                        cells: cells,
                        header: header?.controller,
                        footer: footer?.controller,
                        layoutProvider: nil
                    )
                ]
            }
    }

    /// Reactive boolean gate initializer.
    ///
    /// Builds the section content when `binding` emits `true`, and removes the section when `false`.
    public init<B: ViewBinding>(
        id: SectionConfigIdentifier,
        when binding: B,
        @AnyAnySectionContentBuilder content: @escaping () -> AnySectionContent
    ) where B.Value == Bool {
        self.binding = binding.map { isVisible in
            guard isVisible else { return [] }

            let sectionContent = content()
            let section = SectionConfig(
                identifier: id,
                cells: sectionContent.cells,
                header: sectionContent.header,
                footer: sectionContent.footer,
                layoutProvider: nil
            )
            return [section]
        }
    }

    /// Reactive single-item initializer.
    ///
    /// Use this when your section is driven by one non-array model.
    public init<B: ViewBinding, Item>(
        id: SectionConfigIdentifier,
        item binding: B,
        header: Header? = nil,
        footer: Footer? = nil,
        @AnyCellResultBuilder content: @escaping (Item) -> [CellConfig]
    ) where B.Value == Item {
        self.binding = binding
            .map { item in
                [
                    SectionConfig(
                        identifier: id,
                        cells: content(item),
                        header: header?.controller,
                        footer: footer?.controller,
                        layoutProvider: nil
                    )
                ]
            }
    }

    /// Reactive optional single-item initializer.
    ///
    /// Emits no section when the value is `nil` and one section when non-nil.
    public init<B: ViewBinding, Item>(
        id: SectionConfigIdentifier,
        item binding: B,
        header: Header? = nil,
        footer: Footer? = nil,
        @AnyCellResultBuilder content: @escaping (Item) -> [CellConfig]
    ) where B.Value == Item? {
        self.binding = binding
            .map { item in
                guard let item = item else { return [] }
                return [
                    SectionConfig(
                        identifier: id,
                        cells: content(item),
                        header: header?.controller,
                        footer: footer?.controller,
                        layoutProvider: nil
                    )
                ]
            }
    }

    // MARK: - Actions Modifier
    
    /// Attaches a type-safe, imperative selection action to every item within this section.
    /// Use this for side-effects (logging, analytics, delegate calls) that do NOT produce a navigation event.
    public func onSelect<T>(_ handler: @escaping (T) -> Void) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                let newCells = section.cells.map { cell in
                    var modelToUse = cell.model
                    
                    if let wrapper = modelToUse as? CellContentWrapper {
                        modelToUse = wrapper.originalModel
                    }
                    
                    guard let model = modelToUse as? T else { return cell }
                    
                    return cell.withSelection { _ in
                        handler(model)
                    }
                }
                 
                return SectionConfig(
                    identifier: section.identifier,
                    cells: newCells,
                    header: section.header,
                    footer: section.footer,
                    layoutProvider: section.layoutProvider
                )
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Attaches a declarative routing action to every item within this section.
    /// The returned event is automatically bubbled up the UIResponder chain to the nearest `RouteHandlingCoordinator`.
    public func onRoute<T, E>(_ handler: @escaping (T) -> E) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                let newCells = section.cells.map { cell in
                    var modelToUse = cell.model
                    
                    while let wrapper = modelToUse as? CellContentWrapper {
                        modelToUse = wrapper.originalModel
                    }
                    
                    guard let model = modelToUse as? T else { return cell }
                    
                    return cell.withSelection { sender in
                        let event = handler(model)
                        sender?.route(event, sender: sender)
                    }
                }
                 
                return SectionConfig(
                    identifier: section.identifier,
                    cells: newCells,
                    header: section.header,
                    footer: section.footer,
                    layoutProvider: section.layoutProvider
                )
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Optional-aware variant: routes only when the handler returns a non-nil event.
    /// Supports guard patterns like `guard ... else { return nil }`.
    public func onRoute<T, E>(_ handler: @escaping (T) -> E?) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                let newCells = section.cells.map { cell in
                    var modelToUse = cell.model
                    
                    while let wrapper = modelToUse as? CellContentWrapper {
                        modelToUse = wrapper.originalModel
                    }
                    
                    guard let model = modelToUse as? T else { return cell }
                    
                    return cell.withSelection { sender in
                        guard let event = handler(model) else { return }
                        sender?.route(event, sender: sender)
                    }
                }
                 
                return SectionConfig(
                    identifier: section.identifier,
                    cells: newCells,
                    header: section.header,
                    footer: section.footer,
                    layoutProvider: section.layoutProvider
                )
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Binds an externally injected target reference weakly into every item's tap action dynamically inside this section.
    public func onSelect<T, Target: AnyObject>(on target: Target, _ handler: @escaping (Target, T) -> Void) -> AnySection {
        let improved = binding
            .map { [weak target] sections in
                guard let target = target else { return sections }
            
                return sections.map { section in
                    let newCells = section.cells.map { cell in
                        var modelToUse = cell.model
                        
                        while let wrapper = modelToUse as? CellContentWrapper {
                            modelToUse = wrapper.originalModel
                        }
                        
                        guard let model = modelToUse as? T else { return cell }
                        return cell.withSelection { [weak target] sender in
                            guard let target = target else { return }
                            handler(target, model)
                        }
                    }
                     
                    return SectionConfig(
                        identifier: section.identifier,
                        cells: newCells,
                        header: section.header,
                        footer: section.footer,
                        layoutProvider: section.layoutProvider
                    )
                }
        }
        return AnySection(binding: improved)
    }

    /// Builder Initializer with Header/Footer support
    public init(
        id: SectionConfigIdentifier,
        @AnyAnySectionContentBuilder content: () -> AnySectionContent
    ) {
        let sectionContent = content()
        let section = SectionConfig(
            identifier: id, 
            cells: sectionContent.cells, 
            header: sectionContent.header, 
            footer: sectionContent.footer, 
            layoutProvider: nil
        )
        self.binding = .just([section])
    }
    
    // MARK: Modifiers
    /// Uses a standard closure returning an optional `NSCollectionLayoutSection`, parameterized by environment.
    public func layout(_ handler: @escaping (String) -> NSCollectionLayoutSection?) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                var copy = section
                copy.layoutProvider = handler
                return copy
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Uses a declarative `@LayoutBuilder` closure to synthesize the UI layout for this specific section implicitly.
    public func layout(@LayoutBuilder _ builder: @escaping () -> NSCollectionLayoutSection) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                var copy = section
                copy.layoutProvider = { _ in builder() }
                return copy
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Uses a declarative `@LayoutBuilder` closure dynamically injected with an environment string identifier.
    public func layout(@LayoutBuilder _ builder: @escaping (String) -> NSCollectionLayoutSection) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                var copy = section
                copy.layoutProvider = builder
                return copy
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Modifies the structural definition of the section's header by providing an internally injected declarative `Header` block.
    public func header(_ handler: @escaping () -> Header) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                return SectionConfig(
                    identifier: section.identifier,
                    cells: section.cells,
                    header: handler().controller,
                    footer: section.footer,
                    layoutProvider: section.layoutProvider
                )
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Modifies the structural definition of the section's footer by providing an internally injected declarative `Footer` block.
    public func footer(_ handler: @escaping () -> Footer) -> AnySection {
        let improved = binding.map { sections in
             sections.map { section in
                 return SectionConfig(
                     identifier: section.identifier,
                     cells: section.cells,
                     header: section.header,
                     footer: handler().controller,
                     layoutProvider: section.layoutProvider
                 )
             }
         }
         return AnySection(binding: improved)
      }

    /// Hides or shows the section header reactively using a boolean binding.
    ///
    /// - Important: This uses `distinctUntilChanged` to avoid unnecessary section updates when the
    ///   incoming visibility value repeats.
    public func headerHidden<B: ViewBinding>(when hiddenBinding: B) -> AnySection where B.Value == Bool {
        let hidden = hiddenBinding.distinctUntilChanged()

        let improved = AnyViewBinding<([SectionConfig], Bool)>
            .combineLatest(binding, hidden)
            .map { sections, isHidden in
                sections.map { section in
                    let updatedHeader = isHidden ? nil : section.header

                    if (section.header == nil) == (updatedHeader == nil), section.header?.id == updatedHeader?.id {
                        return section
                    }

                    return SectionConfig(
                        identifier: section.identifier,
                        cells: section.cells,
                        header: updatedHeader,
                        footer: section.footer,
                        layoutProvider: section.layoutProvider,
                        layoutModifiers: section.layoutModifiers,
                        decorationProviders: section.decorationProviders
                    )
                }
            }

        return AnySection(binding: improved)
    }

    /// Hides or shows the section footer reactively using a boolean binding.
    ///
    /// - Important: This uses `distinctUntilChanged` to avoid unnecessary section updates when the
    ///   incoming visibility value repeats.
    public func footerHidden<B: ViewBinding>(when hiddenBinding: B) -> AnySection where B.Value == Bool {
        let hidden = hiddenBinding.distinctUntilChanged()

        let improved = AnyViewBinding<([SectionConfig], Bool)>
            .combineLatest(binding, hidden)
            .map { sections, isHidden in
                sections.map { section in
                    let updatedFooter = isHidden ? nil : section.footer

                    if (section.footer == nil) == (updatedFooter == nil), section.footer?.id == updatedFooter?.id {
                        return section
                    }

                    return SectionConfig(
                        identifier: section.identifier,
                        cells: section.cells,
                        header: section.header,
                        footer: updatedFooter,
                        layoutProvider: section.layoutProvider,
                        layoutModifiers: section.layoutModifiers,
                        decorationProviders: section.decorationProviders
                    )
                }
            }

        return AnySection(binding: improved)
    }
     
    /// Adds decoration items to the section's layout.
    public func decorationItems(_ items: [NSCollectionLayoutDecorationItem]) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                var copy = section
                copy.layoutModifiers.append { layout in
                    layout.decorationItems.append(contentsOf: items)
                }
                return copy
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Appends a single decoration item to the section's layout.
    public func decorationItem(_ item: NSCollectionLayoutDecorationItem) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                var copy = section
                copy.layoutModifiers.append { layout in
                    layout.decorationItems.append(item)
                }
                return copy
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Appends a custom declarative background view dynamically bound to this specific section's lifecycle.
    public func backgroundDecoration(id: String? = nil, insets: NSDirectionalEdgeInsets = .zero, zIndex: Int? = nil, @ViewResultBuilder _ content: @escaping () -> ViewConvertable) -> AnySection {
        let improved = binding.map { sections in
            sections.map { section in
                var copy = section
                let parsedId = id ?? section.identifier.uniqueId
                let bgId = parsedId.hasPrefix("custom_bg_") ? parsedId : "custom_bg_\(parsedId)"
                
                // 1. Store the declarative view provider securely in the section's memory
                copy.decorationProviders[bgId] = content
                
                // 2. Queue the layout modification to inject the decoration item geometry
                copy.layoutModifiers.append { layout in
                    let background = NSCollectionLayoutDecorationItem.background(elementKind: bgId)
                    background.contentInsets = insets
                    if let zIndex { background.zIndex = zIndex }
                    layout.decorationItems.append(background)
                }
                
                return copy
            }
        }
        return AnySection(binding: improved)
    }
    
    /// Imposes an automated animated "_Shimmer mode" replacing layout components with shimmer placeholder items.
    /// Dictated dynamically by resolving a binding boolean argument `when:`.
    public func shimmer<C, B>(
        _ type: C.Type,
        count: Int,
        when shimmerBinding: B,
        includeSuppmentary: Bool = false,
        hideSupplementary: Bool = false,
        configure: ((C) -> Void)? = nil
    ) -> AnySection where C: UICollectionViewCell, B: ViewBinding, B.Value == Bool {
        
        let combined = AnyViewBinding<([SectionConfig], Bool)>.combineLatest(binding, shimmerBinding)
            .map { (sections, isLoading) -> [SectionConfig] in
                if isLoading {
                    return sections.map { section in
                         var header = hideSupplementary ? nil : section.header
                         if includeSuppmentary { header = header?.as_Shimmer() }
                         
                         var footer = hideSupplementary ? nil : section.footer
                         if includeSuppmentary { footer = footer?.as_Shimmer() }
                         
                         return SectionConfig(
                            identifier: section.identifier,
                            cells: _Shimmer<C>.create(count: count, configure: configure),
                            header: header,
                            footer: footer,
                            layoutProvider: section.layoutProvider
                         )
                    }
                } else {
                    return sections
                }
            }
            
        return AnySection(binding: combined)
    }
    
    /// Imposes an automated declarative "_Shimmer mode" loading block via `HostingCell` replacing the current section layout.
    public func shimmer<Content: View, B: ViewBinding>(
        count: Int,
        when binding: B,
        includeSupplementary: Bool = false,
        hideSupplementary: Bool = false,
        placeholder: @escaping () -> Content
    ) -> AnySection where B.Value == Bool {
        return shimmer(
            HostingCell<Content>.self,
            count: count,
            when: binding,
            includeSuppmentary: includeSupplementary,
            hideSupplementary: hideSupplementary
        ) { cell in
            cell.host(placeholder())
        }
    }
    
    /// Submits a distinct declarative nested view substituting this entire section context if the 
    /// dynamically resolved properties within evaluate functionally completely empty or to length 0 count.
    public func emptyState(
        layout: ((String) -> NSCollectionLayoutSection)? = nil,
        @ViewResultBuilder _ content: @escaping () -> ViewConvertable
    ) -> AnySection {
        return AnySection(binding: binding.map { sections in
            sections.map { section in
                if section.cells.isEmpty {
                    // Create Empty Cell
                    let emptyCell = CellConfig(
                        id: "empty_\(section.identifier.uniqueId)",
                        model: (),
                        registration: UICollectionView.CellRegistration<HostingCell<UIView>, Void> { cell, _, _ in
                            let views = content().asViews()
                            let stack = VStackView(views)
                                .alignment(.center)
                            cell.host(stack.build())
                        },
                        didSelect: nil
                    )
                    
                    // Determine Layout
                    let layoutProvider: (String) -> NSCollectionLayoutSection? = { env in
                        return AnySection.makeEmptyStateLayout(
                            env: env,
                            customLayout: layout,
                            section: section
                        )
                    }
                    
                    return SectionConfig(
                        identifier: section.identifier,
                        cells: [emptyCell],
                        header: section.header,
                        footer: section.footer,
                        layoutProvider: layoutProvider
                    )
                }
                return section
            }
        })
    }
    
    // MARK: - Helpers
    
    private static func makeEmptyStateLayout(
        env: String,
        customLayout: ((String) -> NSCollectionLayoutSection)?,
        section: SectionConfig
    ) -> NSCollectionLayoutSection? {
        let sectionLayout: NSCollectionLayoutSection
        if let customLayout = customLayout {
            sectionLayout = customLayout(env)
        } else {
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            sectionLayout = NSCollectionLayoutSection(group: group)
        }
        
        if let originalProvider = section.layoutProvider, let originalLayout = originalProvider(env) {
            var supplementaries = sectionLayout.boundarySupplementaryItems
            
            supplementaries.removeAll { $0.elementKind == UICollectionView.elementKindSectionHeader }
            supplementaries.removeAll { $0.elementKind == UICollectionView.elementKindSectionFooter }
            
            let originalSupplementaries = originalLayout.boundarySupplementaryItems.filter {
                $0.elementKind == UICollectionView.elementKindSectionHeader ||
                $0.elementKind == UICollectionView.elementKindSectionFooter
            }
            supplementaries.append(contentsOf: originalSupplementaries)
            
            sectionLayout.boundarySupplementaryItems = supplementaries
            sectionLayout.contentInsets = originalLayout.contentInsets
        } else {
             addStartSupplementaries(to: sectionLayout, from: section)
        }
        
        return sectionLayout
    }
    
    private static func addStartSupplementaries(to layout: NSCollectionLayoutSection, from section: SectionConfig) {
         var supplementaries = layout.boundarySupplementaryItems
         let hasHeader = supplementaries.contains { $0.elementKind == UICollectionView.elementKindSectionHeader }
         let hasFooter = supplementaries.contains { $0.elementKind == UICollectionView.elementKindSectionFooter }
         
         if !hasHeader, let _ = section.header {
             let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
             let header = NSCollectionLayoutBoundarySupplementaryItem(
                 layoutSize: headerSize,
                 elementKind: UICollectionView.elementKindSectionHeader,
                 alignment: .top
             )
             supplementaries.append(header)
         }
         
         if !hasFooter, let _ = section.footer {
              let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
              let footer = NSCollectionLayoutBoundarySupplementaryItem(
                  layoutSize: footerSize,
                  elementKind: UICollectionView.elementKindSectionFooter,
                  alignment: .bottom
              )
              supplementaries.append(footer)
         }
         layout.boundarySupplementaryItems = supplementaries
    }
    
    // Internal init for modifiers
    private init(binding: AnyViewBinding<[SectionConfig]>) {
        self.binding = binding
    }

    // MARK: Convert
    
    public func asAnySectionObservable() -> AnyViewBinding<[SectionConfig]> {
        return binding
    }
}
