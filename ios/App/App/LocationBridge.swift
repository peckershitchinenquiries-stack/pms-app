import CoreLocation
import WebKit

// Answers the page's navigator.geolocation from Core Location instead of WebKit.
//
// In a WKWebView, WebKit's own geolocation shows a SECOND, website-level prompt
// ("<domain> would like to use your current location") on top of the app's
// permission, and does not remember the answer across launches — so staff would
// be asked on every clock-in day. Core Location asks once, as "Peckers", and
// the answer lives in Settings › Peckers › Location like any app.
//
// The page is unchanged: a document-start script replaces navigator.geolocation
// (getCurrentPosition / watchPosition / clearWatch) and answers
// navigator.permissions.query({ name: "geolocation" }), and this class streams
// positions back. The geofence verdict stays on the server, as before.
final class LocationBridge: NSObject, CLLocationManagerDelegate {

    static let messageHandler = "peckersLocation"

    private let manager = CLLocationManager()
    private weak var webView: WKWebView?
    // True while the page has at least one watcher; drives start/stop and
    // whether an authorization change should start updates.
    private var wanted = false

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // Messages from the main frame's shim: start, stop, reset, permission.
    func handle(_ body: Any) {
        guard let message = body as? [String: Any], let op = message["op"] as? String else { return }
        switch op {
        case "start":
            wanted = true
            begin()
        case "stop", "reset":
            wanted = false
            manager.stopUpdatingLocation()
        case "permission":
            guard let id = message["id"] as? Int else { return }
            send("_permission(\(id), \"\(permissionState)\")")
        default:
            break
        }
    }

    private var permissionState: String {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "granted"
        case .denied, .restricted: return "denied"
        default: return "prompt"
        }
    }

    private func begin() {
        switch manager.authorizationStatus {
        case .notDetermined:
            // The answer arrives in locationManagerDidChangeAuthorization.
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            wanted = false
            send("_error(1, \"User denied Geolocation\")")
        default:
            manager.startUpdatingLocation()
            // The page's timeouts start here, not while the prompt was up.
            send("_started()")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if wanted { begin() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 {
            send("_position(\(Self.json(location)))")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        switch (error as? CLError)?.code {
        case .locationUnknown?:
            // Transient: Core Location keeps trying, as a browser's watch does.
            return
        case .denied?:
            wanted = false
            manager.stopUpdatingLocation()
            send("_error(1, \"User denied Geolocation\")")
        default:
            send("_error(2, \"Position unavailable\")")
        }
    }

    // The shape of a GeolocationPosition, with null where the spec has null.
    private static func json(_ location: CLLocation) -> String {
        let hasAltitude = location.verticalAccuracy >= 0
        let coords: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": hasAltitude ? location.altitude : NSNull(),
            "altitudeAccuracy": hasAltitude ? location.verticalAccuracy : NSNull(),
            "heading": location.course >= 0 ? location.course : NSNull(),
            "speed": location.speed >= 0 ? location.speed : NSNull(),
        ]
        let payload: [String: Any] = [
            "coords": coords,
            "timestamp": (location.timestamp.timeIntervalSince1970 * 1000).rounded(),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return "null" }
        return text
    }

    private func send(_ call: String) {
        webView?.evaluateJavaScript("window.__peckersGeo && window.__peckersGeo.\(call)", completionHandler: nil)
    }

    // Injected at document start in the main frame, before any page script, so
    // the page only ever sees this navigator.geolocation.
    static let userScript = WKUserScript(
        source: shim,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    private static let shim = #"""
    (function () {
      var handlers = window.webkit && window.webkit.messageHandlers;
      if (window.__peckersGeo || !handlers || !handlers.peckersLocation) return;
      var post = function (m) { handlers.peckersLocation.postMessage(m); };

      var watchers = {};
      var nextId = 1;
      var started = false;
      var permissionWaits = {};
      var nextPermission = 1;

      function count() { return Object.keys(watchers).length; }
      function makeError(code, message) {
        return { code: code, message: message, PERMISSION_DENIED: 1, POSITION_UNAVAILABLE: 2, TIMEOUT: 3 };
      }
      function call(fn, arg) {
        if (!fn) return;
        try { fn(arg); } catch (e) { setTimeout(function () { throw e; }); }
      }
      function remove(id) {
        var w = watchers[id];
        if (!w) return;
        if (w.timer) clearTimeout(w.timer);
        delete watchers[id];
        if (!count()) { started = false; post({ op: "stop" }); }
      }
      // A timeout counts from the moment updates start, as in a browser —
      // never while the permission prompt is on screen.
      function arm(id) {
        var w = watchers[id];
        if (!w || w.timer || w.got || w.timeout == null) return;
        w.timer = setTimeout(function () {
          w.timer = null;
          if (!watchers[id] || w.got) return;
          if (w.once) remove(id);
          call(w.error, makeError(3, "Timeout expired"));
        }, w.timeout);
      }
      function add(success, error, options, once) {
        var id = nextId++;
        var o = options || {};
        var maxAge = typeof o.maximumAge === "number" ? o.maximumAge : 0;
        watchers[id] = {
          success: success,
          error: error,
          once: once,
          // Core Location's first report can be a cached position. Anything
          // older than the caller allows (at least 10s, for clock skew) is
          // dropped rather than passed off as fresh.
          maxAge: Math.max(maxAge, 10000),
          timeout: typeof o.timeout === "number" && isFinite(o.timeout) ? o.timeout : null,
          got: false,
          timer: null
        };
        if (count() === 1) post({ op: "start" });
        else if (started) arm(id);
        return id;
      }

      var geolocation = {
        getCurrentPosition: function (s, e, o) { add(s, e, o, true); },
        watchPosition: function (s, e, o) { return add(s, e, o, false); },
        clearWatch: function (id) { remove(id); }
      };
      try {
        Object.defineProperty(navigator, "geolocation", { value: geolocation, configurable: true });
      } catch (e) {
        return;
      }

      window.__peckersGeo = {
        _started: function () {
          started = true;
          Object.keys(watchers).forEach(arm);
        },
        _position: function (p) {
          if (!p) return;
          var age = Date.now() - p.timestamp;
          Object.keys(watchers).forEach(function (id) {
            var w = watchers[id];
            if (!w || age > w.maxAge) return;
            w.got = true;
            if (w.timer) { clearTimeout(w.timer); w.timer = null; }
            if (w.once) remove(id);
            call(w.success, { coords: p.coords, timestamp: p.timestamp });
          });
        },
        _error: function (code, message) {
          Object.keys(watchers).forEach(function (id) {
            var w = watchers[id];
            if (!w) return;
            if (w.once || code === 1) remove(id);
            call(w.error, makeError(code, message));
          });
        },
        _permission: function (id, state) {
          var resolve = permissionWaits[id];
          delete permissionWaits[id];
          if (resolve) resolve(state);
        }
      };

      if (navigator.permissions && navigator.permissions.query) {
        var query = navigator.permissions.query.bind(navigator.permissions);
        navigator.permissions.query = function (descriptor) {
          if (!descriptor || descriptor.name !== "geolocation") return query(descriptor);
          return new Promise(function (resolve) {
            var id = nextPermission++;
            permissionWaits[id] = function (state) {
              resolve({ name: "geolocation", state: state, onchange: null,
                        addEventListener: function () {}, removeEventListener: function () {} });
            };
            post({ op: "permission", id: id });
          });
        };
      }

      // A new document: stop anything the previous one left running.
      post({ op: "reset" });
      window.addEventListener("pagehide", function () { started = false; post({ op: "stop" }); });
      // Restored from the back/forward cache with watches still open.
      window.addEventListener("pageshow", function (e) {
        if (e.persisted && count()) post({ op: "start" });
      });
    })();
    """#
}
