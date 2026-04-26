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
