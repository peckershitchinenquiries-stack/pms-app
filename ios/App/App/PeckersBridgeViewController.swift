import UIKit
import WebKit
import Capacitor

// The page draws under the status bar (viewport-fit=cover), and its top bar
// follows the web app's own light/dark setting, which can differ from the
// phone's. So the page reports its theme and the status bar text is matched to
// it; until it does, Capacitor's default follows the phone.
class PeckersBridgeViewController: CAPBridgeViewController {

    // Must match THEME_MESSAGE_HANDLER in the web repo's ThemeProvider.
    private static let themeHandler = "peckersTheme"

    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        webView?.configuration.userContentController.add(
            WeakScriptMessageHandler(self),
            name: Self.themeHandler
        )
    }
}

extension PeckersBridgeViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.themeHandler, let theme = message.body as? String else { return }
        switch theme {
        case "dark": setStatusBarStyle(.lightContent)
        case "light": setStatusBarStyle(.darkContent)
        default: return
        }
    }
}

// WKUserContentController holds its handlers strongly; this breaks the cycle
// back to the view controller that owns the web view.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
