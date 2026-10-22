import UIKit
import Network

// Covers the web view with a native retry screen whenever the page cannot load.
// Native rather than Capacitor's `server.errorPath` page because a web view with
// no network cannot be trusted to render anything, and because the retry has to
// reload server.url itself — a local error page would reload only itself.
// Mirrors the Android shell's OfflineGate.java and offline_overlay.xml.
final class OfflineGate {

    private enum Copy {
        static let title = "No connection"
        static let body = "Peckers needs an internet connection to load. Check your Wi\u{2011}Fi or mobile data, then try again."
        static let bodyStill = "Still no connection. Check your Wi\u{2011}Fi or mobile data."
        static let retry = "Try again"
    }

    // Fixed dark values, the same as Android's: the screen must read the same
    // whichever theme the page was in when the network dropped.
    private enum Palette {
        static let background = UIColor(red: 0x0f / 255, green: 0x0f / 255, blue: 0x0f / 255, alpha: 1)
        static let text = UIColor(red: 0xf4 / 255, green: 0xf4 / 255, blue: 0xf5 / 255, alpha: 1)
        static let mutedText = UIColor(red: 0xa1 / 255, green: 0xa1 / 255, blue: 0xaa / 255, alpha: 1)
    }

    private let overlay = UIView()
    private let body = UILabel()
    private let monitor = NWPathMonitor()
    private var pathStatus: NWPath.Status?

    private let reload: () -> Void
    private let onVisibilityChange: (Bool) -> Void

    init(in host: UIView, reload: @escaping () -> Void, onVisibilityChange: @escaping (Bool) -> Void) {
        self.reload = reload
        self.onVisibilityChange = onVisibilityChange
        buildOverlay(in: host)

        // Kept running for the app's lifetime: a cancelled monitor cannot be
        // restarted, and a suspended app receives no updates anyway.
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let cameBack = path.status == .satisfied && self.pathStatus != .satisfied
            self.pathStatus = path.status
            if cameBack && self.isShowing { self.retry() }
        }
        monitor.start(queue: .main)
    }

    var isShowing: Bool {
        !overlay.isHidden
    }

    // Until the monitor's first report arrives, assume online and let a failed
    // load prove otherwise.
    var hasNetwork: Bool {
        pathStatus.map { $0 == .satisfied } ?? true
    }

    func show() {
        body.text = Copy.body
        guard overlay.isHidden else { return }
        overlay.superview?.bringSubviewToFront(overlay)
        overlay.isHidden = false
        onVisibilityChange(true)
    }

    func hide() {
        guard !overlay.isHidden else { return }
        overlay.isHidden = true
        onVisibilityChange(false)
    }

    // Reload server.url, or say so again if the device still has no network.
    func retry() {
        guard hasNetwork else {
            body.text = Copy.bodyStill
            return
        }
        hide()
        reload()
    }

    private func buildOverlay(in host: UIView) {
        overlay.backgroundColor = Palette.background
        overlay.isHidden = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(overlay)

        let title = UILabel()
        title.text = Copy.title
        title.textColor = Palette.text
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.adjustsFontForContentSizeCategory = true

        body.text = Copy.body
        body.textColor = Palette.mutedText
        body.font = .systemFont(ofSize: 15)
        body.numberOfLines = 0
        body.textAlignment = .center

        var style = UIButton.Configuration.filled()
        style.baseBackgroundColor = Palette.text
        style.baseForegroundColor = Palette.background
        style.cornerStyle = .fixed
        style.background.cornerRadius = 10
        style.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 28, bottom: 12, trailing: 28)
        style.attributedTitle = AttributedString(
            Copy.retry,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .bold)])
        )
        let button = UIButton(configuration: style, primaryAction: UIAction { [weak self] _ in self?.retry() })

        let stack = UIStackView(arrangedSubviews: [title, body, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.setCustomSpacing(24, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)

        let guide = overlay.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: host.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),

            stack.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -24),
            body.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
        ])
    }
}
