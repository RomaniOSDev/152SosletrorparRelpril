import WebKit

@MainActor
final class CookieManager {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Save

    func save(from store: WKHTTPCookieStore) async {
        let cookies = await withCheckedContinuation { continuation in
            store.getAllCookies { continuation.resume(returning: $0) }
        }

        let serialized: [[String: Any]] = cookies.compactMap { cookie in
            guard let props = cookie.properties else { return nil }
            var dict = [String: Any]()
            for (key, value) in props {
                switch value {
                case let s as String:   dict[key.rawValue] = s
                case let n as NSNumber: dict[key.rawValue] = n
                case let d as Date:     dict[key.rawValue] = d.timeIntervalSince1970
                default: break
                }
            }
            return dict.isEmpty ? nil : dict
        }

        defaults.set(serialized, forKey: AppConfiguration.UserDefaultsKey.cookies)
    }

    // MARK: - Restore

    func restore(to store: WKHTTPCookieStore) async {
        guard let saved = defaults.array(forKey: AppConfiguration.UserDefaultsKey.cookies)
                as? [[String: Any]], !saved.isEmpty else { return }

        for dict in saved {
            var props = [HTTPCookiePropertyKey: Any]()
            for (key, value) in dict {
                let cookieKey = HTTPCookiePropertyKey(key)
                if cookieKey == .expires, let ts = value as? Double {
                    props[cookieKey] = Date(timeIntervalSince1970: ts)
                } else {
                    props[cookieKey] = value
                }
            }
            guard let cookie = HTTPCookie(properties: props) else { continue }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.setCookie(cookie) { continuation.resume() }
            }
        }
    }

    // MARK: - Clear

    func clear() {
        defaults.removeObject(forKey: AppConfiguration.UserDefaultsKey.cookies)
    }
}
