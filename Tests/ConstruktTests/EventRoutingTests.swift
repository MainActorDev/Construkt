import Testing
import UIKit
@testable import ConstruktKit

private enum TestRoute: Equatable {
    case page1
    case page2(id: Int)
}

private class MockRootViewController: UIViewController, RouteReceiving {
    typealias Event = TestRoute
    
    var receivedRoute: TestRoute?
    var dispatchClosure: (() -> Void)?
    
    func canReceive(_ event: TestRoute, sender: Any?) -> Bool {
        receivedRoute = event
        dispatchClosure?()
        return true
    }
}

@Suite("EventRoutingTests") @MainActor
struct EventRoutingTests {

    @Test("Route should bubble up to the root controller")
    func testRouteBubblesUpToRootController() {
        let rootVC = MockRootViewController()
        
        // Add a view that emits a route
        let button = ButtonView("Go").onRoute(TestRoute.page2(id: 42)).build() as! UIButton
        
        // Responder chain requires establishing a valid window hierarchy
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        
        rootVC.view.addSubview(button)
        
        // Simulate tap
        button.route(TestRoute.page2(id: 42), sender: button)
        
        #expect(rootVC.receivedRoute == .page2(id: 42))
    }
    
    @Test("Declarative .onReceiveRoute intercepts bubbled events")
    func testDeclarativeRouteInterceptor() {
        var trappedRoute: TestRoute? = nil
        
        let container = ContainerView()
            .onReceiveRoute(TestRoute.self, handler: { event in
                trappedRoute = event
                return true
            })
            .first!.build()
            
        let button = ButtonView("Action")
            .onRoute(TestRoute.page1)
            .build() as! UIButton
            
        container.addSubview(button)
        
        // Bubbles up from the button -> intercepted by the declarative container logic
        button.route(TestRoute.page1, sender: button)
        
        #expect(trappedRoute == .page1)
    }
    
    @Test("Targeted declarative .onReceiveRoute safely decouples objects")
    func testTargetedRouteInterceptorMemorySafety() {
        class RefCountedTarget {
            var handledValue: Int = 0
            deinit {}
        }
        
        var target: RefCountedTarget? = RefCountedTarget()
        weak let weakTarget = target
        
        let container = ContainerView()
            .onReceiveRoute(TestRoute.self, on: target!) { ref, event in
                switch event {
                case .page2(let id):
                    ref.handledValue = id
                    return true
                default:
                    return false
                }
            }
            .first!.build()
            
        let button = ButtonView("Action").build() as! UIButton
        container.addSubview(button)
        
        button.route(TestRoute.page2(id: 99), sender: button)
        #expect(target?.handledValue == 99)
        
        // Assert releasing the target works
        target = nil
        #expect(weakTarget == nil)
        
        // Bubbling continues instead of failing with released targets
        let handled = button.route(TestRoute.page2(id: 100), sender: button)
        #expect(handled == false)
    }
    
    // MARK: - Multi-handler tests
    
    @Test("Multiple .onReceiveRoute handlers for different enum types both fire")
    func testMultipleOnReceiveRouteHandlersDifferentTypes() {
        var trappedTestRoute: TestRoute? = nil
        var trappedSecondRoute: TestRoute2? = nil
        
        let container = ContainerView()
            .onReceiveRoute(TestRoute.self, handler: { event in
                trappedTestRoute = event
                return true
            })
            .onReceiveRoute(TestRoute2.self, handler: { event in
                trappedSecondRoute = event
                return true
            })
            .build()
        
        let button = ButtonView("Action").build() as! UIButton
        container.addSubview(button)
        
        // Send first enum type
        button.route(TestRoute.page1, sender: button)
        #expect(trappedTestRoute == .page1)
        #expect(trappedSecondRoute == nil)
        
        // Send second enum type
        button.route(TestRoute2.settings, sender: button)
        #expect(trappedSecondRoute == .settings)
    }
    
    @Test("Multiple .onReceiveRoute handlers for the same type: first registered wins")
    func testMultipleOnReceiveRouteSameTypePriority() {
        var firstCalled = false
        var secondCalled = false
        
        let container = ContainerView()
            .onReceiveRoute(TestRoute.self, handler: { _ in
                firstCalled = true
                return true   // handled → stops dispatch
            })
            .onReceiveRoute(TestRoute.self, handler: { _ in
                secondCalled = true
                return true
            })
            .build()
        
        let button = ButtonView("Action").build() as! UIButton
        container.addSubview(button)
        
        button.route(TestRoute.page1, sender: button)
        #expect(firstCalled == true)
        #expect(secondCalled == false)
    }
    
    // MARK: - RouteChannel tests
    
    @Test("RouteChannel delivers events to subscribers")
    func testRouteChannelBasicDelivery() {
        let channel = RouteChannel<TestRoute>()
        var received: TestRoute? = nil
        
        // Use a strong owner so the listener stays alive
        let owner = NSObject()
        channel.subscribe(owner: owner, handler: { event, sender in
            received = event
            return true
        })
        
        let handled = channel.send(.page2(id: 42))
        #expect(handled == true)
        #expect(received == .page2(id: 42))
    }
    
    @Test("RouteChannel auto-cleans listeners when owner is deallocated")
    func testRouteChannelListenerCleanup() {
        let channel = RouteChannel<TestRoute>()
        var received = false
        
        var owner: NSObject? = NSObject()
        channel.subscribe(owner: owner!, handler: { _, _ in
            received = true
            return true
        })
        
        // Deallocate owner
        owner = nil
        
        let handled = channel.send(.page1)
        #expect(handled == false)
        #expect(received == false)
    }
    @Test("RouteChannel.shared returns the same instance for the same event type")
    func testRouteChannelSharedSingleton() {
        let channel1 = RouteChannel<TestRoute>.shared
        let channel2 = RouteChannel<TestRoute>.shared
        #expect(channel1 === channel2)
    }
    
    @Test("RouteChannel.shared returns different instances for different event types")
    func testRouteChannelSharedDifferentTypes() {
        let channel1 = RouteChannel<TestRoute>.shared
        let channel2 = RouteChannel<TestRoute2>.shared
        // They are different types, so we just verify both are non-nil and functional
        var received1: TestRoute? = nil
        var received2: TestRoute2? = nil
        
        let owner = NSObject()
        channel1.subscribe(owner: owner) { event, _ in
            received1 = event
            return true
        }
        channel2.subscribe(owner: owner) { event, _ in
            received2 = event
            return true
        }
        
        channel1.send(.page1)
        channel2.send(.settings)
        
        #expect(received1 == .page1)
        #expect(received2 == .settings)
    }
}

private enum TestRoute2: Equatable {
    case settings
    case logout
}
