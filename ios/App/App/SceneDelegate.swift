import UIKit
import Capacitor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // The ONLY place the window is built. Info.plist names no storyboard
        // (UISceneStoryboardFile / UIMainStoryboardFile were removed): with one,
        // UIKit also builds Main.storyboard's plain CAPBridgeViewController,
        // which could start a second Capacitor bridge without the offline
        // screen, swipe-back, theme or location bridge.
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = PeckersBridgeViewController()
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }
}
