import SwiftUI

@main
struct PwngroundApp: App {
    var body: some Scene {
        WindowGroup {
            Color.black
                .ignoresSafeArea()
                .onAppear(perform: switchHostingController)
        }
    }
    
    private func switchHostingController() {
        UIApplication.shared.switchHostingController()
    }
}

class HostingController: UIHostingController<ContentView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    override var childForStatusBarStyle: UIViewController? { nil }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }
    override var shouldAutorotate: Bool {
        false
    }
}

extension UIApplication {
    static var hostingController: HostingController?
    static var statusBarStyle: UIStatusBarStyle = .default
    
    static func setStatusBarStyle(_ style: UIStatusBarStyle) {
        statusBarStyle = style
        hostingController?.setNeedsStatusBarAppearanceUpdate()
    }
    
    func switchHostingController() {
        let hostingController = HostingController(rootView: ContentView())
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { scene in
                scene as? UIWindowScene
            }.flatMap { windowScene in
                windowScene.windows
            }.first(where: \.isKeyWindow)
        keyWindow?.overrideUserInterfaceStyle = .light
        keyWindow?.rootViewController = hostingController
        keyWindow?.makeKeyAndVisible()
    }
}
