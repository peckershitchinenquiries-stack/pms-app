import Foundation
import CryptoKit

// Identifies which deployment the web view is running, so a resume can reload
// deterministically instead of hoping Next.js notices its own build-ID drift.
//
// The fingerprint is a hash of every `/_next/static/...` asset path in the
// document served at server.url. Those paths are content-hashed by the Next.js
// build, so a new deployment always changes them and a redeploy of the same
// commit never does. Same rule as the Android shell's BuildFingerprint.java.
final class BuildFingerprint {

    private static let key = "build_fingerprint"
    private static let maxBodyBytes = 512 * 1024
    private static let timeout: TimeInterval = 8
    private static let asset = try! NSRegularExpression(pattern: "/_next/static/[A-Za-z0-9._/-]+")

    private let defaults = UserDefaults.standard
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = BuildFingerprint.timeout
        config.timeoutIntervalForResource = BuildFingerprint.timeout
        return URLSession(configuration: config)
    }()

    // Record what is on screen now, so a later resume has something to compare.
    func record(_ url: URL) {
        probe(url) { [weak self] fingerprint in
            guard let fingerprint = fingerprint else { return }
            self?.defaults.set(fingerprint, forKey: Self.key)
        }
    }

    // Clear the record, so the next probe reseeds rather than reporting a change.
    func forget() {
        defaults.removeObject(forKey: Self.key)
    }

    // `onChanged` runs on the main queue, only on a confirmed difference — an
    // unreachable server, a page with no Next.js assets, or no recorded
    // baseline all leave the web view alone.
    func checkForChange(_ url: URL, onChanged: @escaping () -> Void) {
        probe(url) { [weak self] current in
            guard let self = self, let current = current else { return }
            let previous = self.defaults.string(forKey: Self.key)
            self.defaults.set(current, forKey: Self.key)
            if let previous = previous, previous != current {
                DispatchQueue.main.async(execute: onChanged)
            }
        }
    }

    private func probe(_ url: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: url)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        session.dataTask(with: request) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse, http.statusCode < 400 else {
                return completion(nil)
            }
            let body = String(decoding: data.prefix(Self.maxBodyBytes), as: UTF8.self)
            let range = NSRange(body.startIndex..., in: body)
            let assets = Set(Self.asset.matches(in: body, range: range).compactMap { match in
                Range(match.range, in: body).map { String(body[$0]) }
            })
            guard !assets.isEmpty else { return completion(nil) }

            let digest = SHA256.hash(data: Data(assets.sorted().joined(separator: "\n").utf8))
            completion(digest.map { String(format: "%02x", $0) }.joined())
        }.resume()
    }
}
