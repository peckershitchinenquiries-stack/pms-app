import UIKit
import Capacitor
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // The plist is gitignored and copied in only when present (see the
        // "Copy GoogleService-Info.plist" build phase). Configuring without it
        // crashes at launch, so a build lacking it runs with push unavailable.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        return true
    }

    // The server sends through FCM (lib/fcm.ts in the web repo), which rejects a
    // raw APNs token as invalid and would prune the row as dead. So the APNs
    // token is handed to Firebase and the FCM token it issues is what reaches
    // the page's `registration` listener - the same kind of token Android gives.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard FirebaseApp.app() != nil else {
            let error = NSError(
                domain: "uk.co.peckers.app",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Notifications aren't set up in this app build."]
            )
            NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
            return
        }

        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, error in
            if let token = token {
                NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: token)
            } else {
                let failure = error ?? NSError(
                    domain: "uk.co.peckers.app",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Notification registration failed."]
                )
                NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: failure)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
