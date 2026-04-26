import Testing
import UIKit
@testable import ConstruktKit

@Suite("LabelView") @MainActor
struct LabelViewTests {
    @Test("Initialization with text")
    func testInitText() {
        let label = LabelView("Test String").build() as! UILabel
        #expect(label.text == "Test String")
    }
    
    @Test("Modifiers apply correctly")
    func testModifiers() {
        let font = UIFont.systemFont(ofSize: 24, weight: .bold)
        let label = LabelView("Styled")
            .font(font)
            .color(.red)
            .alignment(.center)
            .numberOfLines(2)
            .lineBreakMode(.byTruncatingMiddle)
            .build() as! UILabel
        
        #expect(label.font == font)
        #expect(label.textColor == .red)
        #expect(label.textAlignment == .center)
        #expect(label.numberOfLines == 2)
        #expect(label.lineBreakMode == .byTruncatingMiddle)
    }
}

@Suite("ButtonView") @MainActor
struct ButtonViewTests {
    @Test("Initialization applies text")
    func testInit() {
        let button = ButtonView("Tap Me").build() as! UIButton
        #expect(button.title(for: .normal) == "Tap Me")
    }
    
    @Test("Modifiers apply state config")
    func testModifiers() {
        let button = ButtonView("Configured")
            .color(.blue, for: .normal)
            .color(.red, for: .disabled)
            .enabled(false)
            .build() as! UIButton
        
        #expect(button.titleColor(for: .normal) == .blue)
        #expect(button.titleColor(for: .disabled) == .red)
        #expect(button.isEnabled == false)
    }
}

@Suite("ImageView") @MainActor
struct ImageViewTests {
    @Test("Initialization with string resolves image")
    func testInitString() {
        // Star is guaranteed to exist via systemName
        let image = ImageView(systemName: "star").build() as! UIImageView
        #expect(image.image != nil)
    }
    
    @Test("Modifiers configure content mode and tint")
    func testModifiers() {
        let iv = ImageView(systemName: "star")
            .contentMode(.scaleAspectFit)
            .tintColor(.green)
            .build() as! UIImageView
            
        #expect(iv.contentMode == .scaleAspectFit)
        #expect(iv.tintColor == .green)
    }
}

@Suite("StackView") @MainActor
struct StackViewTests {
    @Test("HStackView configures horizontal axis")
    func testHStack() {
        let stack = HStackView {}.build() as! UIStackView
        #expect(stack.axis == .horizontal)
    }
    
    @Test("VStackView configures vertical axis")
    func testVStack() {
        let stack = VStackView {}.build() as! UIStackView
        #expect(stack.axis == .vertical)
    }
    
    @Test("HStackView spacing initializer applies spacing")
    func testHStackSpacingInit() {
        let stack = HStackView(spacing: 24) {
            LabelView("A")
            LabelView("B")
        }.build() as! UIStackView
        
        #expect(stack.spacing == 24)
        #expect(stack.arrangedSubviews.count == 2)
    }
    
    @Test("VStackView spacing initializer applies spacing")
    func testVStackSpacingInit() {
        let stack = VStackView(spacing: 16) {
            LabelView("A")
            LabelView("B")
        }.build() as! UIStackView
        
        #expect(stack.spacing == 16)
        #expect(stack.arrangedSubviews.count == 2)
    }
    
    @Test("HStackView zero spacing overrides system default")
    func testHStackZeroSpacing() {
        let stack = HStackView(spacing: 0) {
            LabelView("A")
        }.build() as! UIStackView
        
        #expect(stack.spacing == 0)
    }
    
    @Test("Modifiers applied to stack components")
    func testModifiers() {
        let stack = VStackView {}
            .spacing(12)
            .alignment(.trailing)
            .distribution(.fillProportionally)
            .build() as! UIStackView
            
        #expect(stack.spacing == 12)
        #expect(stack.alignment == .trailing)
        #expect(stack.distribution == .fillProportionally)
    }
}

@Suite("UIControl Modifiers") @MainActor
struct UIControlModifierTests {
    @Test("enabled modifier sets isEnabled")
    func testEnabledModifier() {
        let button = ButtonView("Test")
            .enabled(false)
            .build() as! UIButton
        
        #expect(button.isEnabled == false)
    }
    
    @Test("highlighted modifier sets isHighlighted, not isEnabled")
    func testHighlightedModifier() {
        let button = ButtonView("Test")
            .highlighted(true)
            .build() as! UIButton
        
        #expect(button.isHighlighted == true)
        // Verify it didn't accidentally set isEnabled instead
        #expect(button.isEnabled == true)
    }
    
    @Test("selected modifier sets isSelected, not isEnabled")
    func testSelectedModifier() {
        let button = ButtonView("Test")
            .selected(true)
            .build() as! UIButton
        
        #expect(button.isSelected == true)
        // Verify it didn't accidentally set isEnabled instead
        #expect(button.isEnabled == true)
    }
    
    @Test("highlighted(false) does not disable the control")
    func testHighlightedFalseDoesNotDisable() {
        let button = ButtonView("Test")
            .highlighted(false)
            .build() as! UIButton
        
        #expect(button.isHighlighted == false)
        #expect(button.isEnabled == true)
    }
    
    @Test("selected(false) does not disable the control")
    func testSelectedFalseDoesNotDisable() {
        let button = ButtonView("Test")
            .selected(false)
            .build() as! UIButton
        
        #expect(button.isSelected == false)
        #expect(button.isEnabled == true)
    }
}

@Suite("View Identifier & Tag Overloads") @MainActor
struct ViewIdentifierOverloadTests {
    @Test("accessibilityIdentifier with plain String")
    func testAccessibilityIdentifierString() {
        let view = UIView()
            .accessibilityIdentifier("login_button")
            .build()
        
        #expect(view.accessibilityIdentifier == "login_button")
    }
    
    @Test("identifier with plain String")
    func testIdentifierString() {
        let view = UIView()
            .identifier("submit_field")
            .build()
        
        #expect(view.accessibilityIdentifier == "submit_field")
    }
    
    @Test("tag with plain Int")
    func testTagInt() {
        let view = UIView()
            .tag(42)
            .build()
        
        #expect(view.tag == 42)
    }
}

@Suite("Gesture Modifiers") @MainActor
struct GestureModifierTests {
    @Test("onSwipeUp adds swipe gesture recognizer with up direction")
    func testSwipeUp() {
        let view = UIView()
            .onSwipeUp { _ in }
            .build()
        
        let swipeGestures = view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer } ?? []
        #expect(swipeGestures.count == 1)
        #expect(swipeGestures.first?.direction == .up)
    }
    
    @Test("onSwipeDown adds swipe gesture recognizer with down direction")
    func testSwipeDown() {
        let view = UIView()
            .onSwipeDown { _ in }
            .build()
        
        let swipeGestures = view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer } ?? []
        #expect(swipeGestures.count == 1)
        #expect(swipeGestures.first?.direction == .down)
    }
    
    @Test("onSwipeLeft adds swipe gesture recognizer with left direction")
    func testSwipeLeft() {
        let view = UIView()
            .onSwipeLeft { _ in }
            .build()
        
        let swipeGestures = view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer } ?? []
        #expect(swipeGestures.count == 1)
        #expect(swipeGestures.first?.direction == .left)
    }
    
    @Test("onSwipeRight adds swipe gesture recognizer with right direction")
    func testSwipeRight() {
        let view = UIView()
            .onSwipeRight { _ in }
            .build()
        
        let swipeGestures = view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer } ?? []
        #expect(swipeGestures.count == 1)
        #expect(swipeGestures.first?.direction == .right)
    }
}

@Suite("SwitchView") @MainActor
struct SwitchViewTests {
    @Test("isOn initialization configures state")
    func testState() {
        let toggle = SwitchView(true).build() as! UISwitch
        #expect(toggle.isOn == true)
    }
    
    @Test("onTintColor applies correctly")
    func testModifiers() {
        let toggle = SwitchView()
            .onTintColor(.purple)
            .build() as! UISwitch
            
        #expect(toggle.onTintColor == .purple)
    }
}

@Suite("ContainerViews") @MainActor
struct ContainerViewTests {
    @Test("ContainerView generates a valid ViewBuilder host")
    func testContainerInit() {
        let container = ContainerView {
            LabelView("Inside Container")
        }.build()
        
        // ContainerView lazily mounts children on didMoveToSuperview
        let parent = UIView()
        parent.addSubview(container)
        
        #expect(container.subviews.count == 1)
        #expect(container.subviews.first is UILabel)
    }
}

@Suite("Spacers") @MainActor
struct SpacerTests {
    @Test("Divider generates exactly 1px line")
    func testDivider() {
        let divider = DividerView().build()
        
        // Divider uses an internal subview for the actual line
        let line = divider.subviews.first
        #expect(line != nil)
        
        let constraints = line?.constraints ?? []
        let sizeConstraint = constraints.first { $0.firstAttribute == .height || $0.firstAttribute == .width }
        
        #expect(sizeConstraint != nil)
        if let c = sizeConstraint {
            // Depending on screen scale, 0.5 logical pixels may render as 1.0
            #expect(c.constant > 0 && c.constant <= 1.0)
        }
    }
    
    @Test("Fixed Spacer sets rigid dimensions")
    func testFixedSpacer() {
        let spacerVertical = FixedSpacerView(15).build()
        let heightConstraint = spacerVertical.constraints.first { $0.firstAttribute == .height }
        #expect(heightConstraint?.constant == 15)
        #expect(heightConstraint?.priority == .required)
        
        let spacerHorizontal = FixedSpacerView(width: 25).build()
        let widthConstraint = spacerHorizontal.constraints.first { $0.firstAttribute == .width }
        #expect(widthConstraint?.constant == 25)
        #expect(widthConstraint?.priority == .required)
    }
}

// MARK: - ScrollView Tests

@Suite("ScrollView Tests")
@MainActor
struct ScrollViewTests {
    @Test("ScrollView creates UIScrollView")
    func scrollViewCreation() {
        let scrollView = ScrollView(nil)
        let uiView = scrollView.build()
        #expect(uiView is UIScrollView)
    }

    @Test("ScrollView with content creates UIScrollView")
    func scrollViewWithContent() {
        let scrollView = ScrollView {
            UIView()
        }
        let uiView = scrollView.build()
        #expect(uiView is UIScrollView)
    }

    @Test("bounces modifier sets bounces property")
    func bouncesModifier() {
        let scrollView = ScrollView(nil)
            .bounces(false)
        let uiView = scrollView.build() as! UIScrollView
        #expect(uiView.bounces == false)
    }

    @Test("showVerticalIndicator modifier")
    func showVerticalIndicator() {
        let scrollView = ScrollView(nil)
            .showVerticalIndicator(false)
        let uiView = scrollView.build() as! UIScrollView
        #expect(uiView.showsVerticalScrollIndicator == false)
    }

    @Test("showHorizontalIndicator modifier")
    func showHorizontalIndicator() {
        let scrollView = ScrollView(nil)
            .showHorizontalIndicator(false)
        let uiView = scrollView.build() as! UIScrollView
        #expect(uiView.showsHorizontalScrollIndicator == false)
    }

    @Test("VerticalScrollView creates UIScrollView")
    func verticalScrollViewCreation() {
        let scrollView = VerticalScrollView(nil)
        let uiView = scrollView.build()
        #expect(uiView is UIScrollView)
    }
}

// MARK: - Image Binding Tests

@Suite("Image Binding Tests")
@MainActor
struct ImageBindingTests {
    @Test("ImageView with UIImage creates UIImageView")
    func imageViewWithUIImage() {
        let image = UIImage()
        let imageView = ImageView(image)
        let uiView = imageView.build()
        #expect(uiView is UIImageView)
        #expect((uiView as! UIImageView).image === image)
    }

    @Test("ImageView with system name creates UIImageView")
    func imageViewWithSystemName() {
        let imageView = ImageView(systemName: "star")
        let uiView = imageView.build()
        #expect(uiView is UIImageView)
        #expect((uiView as! UIImageView).image != nil)
    }

    @Test("ImageView with named image")
    func imageViewWithNamedImage() {
        let imageView = ImageView(named: "nonexistent_test_image")
        let uiView = imageView.build()
        #expect(uiView is UIImageView)
    }

    @Test("ImageView reactive init with Property binding")
    func imageBindModifier() {
        let image = UIImage()
        let property = Property<UIImage>(image)
        let imageView = ImageView(property)
        let uiView = imageView.build()
        #expect(uiView is UIImageView)
    }

    @Test("image bind modifier with optional Property")
    func imageBindOptionalModifier() {
        let property = Property<UIImage?>(nil)
        let imageView = ImageView(UIImage())
            .image(bind: property)
        let uiView = imageView.build() as! UIImageView
        let newImage = UIImage()
        property.wrappedValue = newImage
        #expect(uiView.image === newImage)
    }

    @Test("tintColor modifier on ImageView")
    func tintColorModifier() {
        let imageView = ImageView(systemName: "star")
            .tintColor(.red)
        let uiView = imageView.build() as! UIImageView
        #expect(uiView.tintColor == .red)
    }
}

// MARK: - Style Tests

@Suite("Style Tests")
@MainActor
struct StyleTests {
    struct RedBackgroundStyle: BuilderStyle {
        func apply(to view: UIView) {
            view.backgroundColor = .red
        }
    }

    struct LabelBoldStyle: BuilderStyle {
        func apply(to view: UILabel) {
            view.font = .boldSystemFont(ofSize: 16)
        }
    }

    @Test("style modifier applies UIView style")
    func styleModifierAppliesUIViewStyle() {
        let label = UILabel()
        let modified = ViewModifier<UILabel>(label)
            .style(RedBackgroundStyle())
        #expect(modified.build().backgroundColor == UIColor.red)
    }

    @Test("style modifier applies typed style")
    func styleModifierAppliesTypedStyle() {
        let label = UILabel()
        let modified = ViewModifier<UILabel>(label)
            .style(LabelBoldStyle())
        #expect((modified.build() as! UILabel).font == UIFont.boldSystemFont(ofSize: 16))
    }

    @Test("UIView style applies to any view type")
    func uiViewStyleAppliesToAnyView() {
        let button = UIButton()
        let modified = ViewModifier<UIButton>(button)
            .style(RedBackgroundStyle())
        #expect(modified.build().backgroundColor == UIColor.red)
    }
}
