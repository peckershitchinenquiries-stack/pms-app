import UIKit
import WebKit
import Capacitor

// The native behaviour the Android shell has in MainActivity: back navigation,
// an offline screen, and a reload on resume after a new deployment. Plus the
// status bar text, which follows the page's own light/dark setting.
class PeckersBridgeViewController: CAPBridgeViewController {

    // Must match THEME_MESSAGE_HANDLER in the web repo's ThemeProvider.
    private static let themeHandler = "peckersTheme"

    // A resume sooner than this is an app switch, not a return to a stale app.
    private static let versionCheckAfter: TimeInterval = 60
    // Long enough away that reloading is right whether or not the deploy moved.
    private static let forceReloadAfter: TimeInterval = 12 * 60 * 60

    private var offline: OfflineGate?
    private let fingerprint = BuildFingerprint()
    private var navigationObserver: NavigationObserver?
    private var backgroundedAt: Date?

    // The page draws under the status bar (viewport-fit=cover) and can be in a
    // different theme from the phone. Until it reports, Capacitor's default
    // (follow the phone) applies.
    private var pageStatusBarStyle: UIStatusBarStyle?
    private var defaultStatusBarStyle: UIStatusBarStyle = .default

    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        guard let webView = webView else { return }

        defaultStatusBarStyle = statusBarStyle
        webView.configuration.userContentController.add(
            WeakScriptMessageHandler(self),
            name: Self.themeHandler
        )

        // iPhones have no back button, so without the edge swipe a screen with
        // no in-page way back is a dead end. WKWebView walks pushState history
        // too, so this covers Next.js client-side navigation. No route names:
        // the landing screen is simply where history runs out.
        webView.allowsBackForwardNavigationGestures = true

        offline = OfflineGate(
            in: webView,
            reload: { [weak self] in self?.reloadApp() },
            onVisibilityChange: { [weak self] showing in self?.offlineVisibilityChanged(showing) }
        )

        // Capacitor's delegation handler stays the navigation delegate in all but
        // name: the observer forwards every call to it and only watches the
        // outcome of each main-frame load.
        let observer = NavigationObserver(forwardingTo: webView.navigationDelegate)
        observer.onFinish = { [weak self] in self?.pageLoaded() }
        observer.onConnectivityFailure = { [weak self] in self?.offline?.show() }
        navigationObserver = observer
        webView.navigationDelegate = observer

        NotificationCenter.default.addObserver(
            self, selector: #selector(didEnterBackground),
            name: UIScene.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(willEnterForeground),
            name: UIScene.willEnterForegroundNotification, object: nil
        )
    }

    private var startURL: URL? {
        bridge?.config.appStartServerURL
    }

    private func reloadApp() {
        guard let url = startURL else { return }
        webView?.load(URLRequest(url: url))
    }

    private func pageLoaded() {
        offline?.hide()
        if let url = startURL { fingerprint.record(url) }
    }

    private func offlineVisibilityChanged(_ showing: Bool) {
        // The edge swipe would otherwise still reach the web view underneath.
        webView?.allowsBackForwardNavigationGestures = !showing
        setStatusBarStyle(showing ? .lightContent : (pageStatusBarStyle ?? defaultStatusBarStyle))
    }

    @objc private func didEnterBackground() {
        backgroundedAt = Date()
    }

    @objc private func willEnterForeground() {
        guard let offline = offline else { return }
        let away = backgroundedAt.map { Date().timeIntervalSince($0) } ?? 0
        backgroundedAt = nil

        if !offline.hasNetwork {
            offline.show()
            return
        }
        if offline.isShowing {
            offline.retry()
            return
        }

        guard let url = startURL else { return }
        if away >= Self.forceReloadAfter {
            fingerprint.forget()
            reloadApp()
        } else if away >= Self.versionCheckAfter {
            fingerprint.checkForChange(url) { [weak self] in self?.reloadApp() }
        }
    }
}

extension PeckersBridgeViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.themeHandler, let theme = message.body as? String else { return }
        switch theme {
        case "dark": pageStatusBarStyle = .lightContent
        case "light": pageStatusBarStyle = .darkContent
        default: return
        }
        // The offline screen is always dark; the page's choice applies once it hides.
        if offline?.isShowing != true, let style = pageStatusBarStyle {
            setStatusBarStyle(style)
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

// Sits in front of Capacitor's navigation delegate, which cannot be subclassed
// because CAPBridgeViewController.loadView is final. Every method it does not
// implement is forwarded untouched; the three it does implement call through
// first, so Capacitor's own handling always runs.
private final class NavigationObserver: NSObject, WKNavigationDelegate {
    // Capacitor's bridge owns its delegation handler for the app's lifetime.
    private weak var inner: WKNavigationDelegate?

    var onFinish: (() -> Void)?
    var onConnectivityFailure: (() -> Void)?

    init(forwardingTo inner: WKNavigationDelegate?) {
        self.inner = inner
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (inner?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        inner?.responds(to: aSelector) == true ? inner : super.forwardingTarget(for: aSelector)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        inner?.webView?(webView, didFinish: navigation)
        onFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        inner?.webView?(webView, didFail: navigation, withError: error)
        if Self.isConnectivityFailure(error) { onConnectivityFailure?() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        inner?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
        if Self.isConnectivityFailure(error) { onConnectivityFailure?() }
    }

    // A cancelled load (a tap that interrupts another) or a navigation the
    // policy handler turned away (WebKitErrorDomain) is not the network failing.
    private static func isConnectivityFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code != NSURLErrorCancelled
    }
}
