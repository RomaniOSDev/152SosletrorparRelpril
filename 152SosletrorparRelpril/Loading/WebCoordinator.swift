import SwiftUI
import WebKit
import Combine
import AppTrackingTransparency

@MainActor
final class WebCoordinator: NSObject, ObservableObject {
    @Published private(set) var appState: AppState = .idle

    let webView: WKWebView
    private let cookieManager = CookieManager()
    private let navigationHandler = NavigationHandler()
    private let jsHandler = JSBridgeHandler()
    private var epoch: UInt = 0
    private var loadingTask: Task<Void, Never>?
    private var lifecycleTasks: [Task<Void, Never>] = []

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let userContent = WKUserContentController()
        userContent.add(jsHandler, name: AppConfiguration.jsHandlerName)
        config.userContentController = userContent

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        super.init()

        webView.navigationDelegate = navigationHandler
        navigationHandler.delegate = self
        jsHandler.delegate = self

        lifecycleTasks = [
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(
                    named: UIApplication.willEnterForegroundNotification
                ) {
                    await self?.handleForeground()
                }
            },
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(
                    named: UIApplication.willResignActiveNotification
                ) {
                    await self?.handleResignActive()
                }
            }
        ]
    }

    deinit {
        loadingTask?.cancel()
        lifecycleTasks.forEach { $0.cancel() }
    }

    // MARK: - Public

    func start() async {
        guard appState == .idle else { return }
        epoch &+= 1
        let currentEpoch = epoch
        navigationHandler.reset()
        appState = .loading

        await cookieManager.restore(to: webView.configuration.websiteDataStore.httpCookieStore)
        guard epoch == currentEpoch else { return }

        guard let url = buildStartURL() else {
            appState = .showGame
            return
        }
        await requestTrackingAuthorizationIfNeeded()
        guard epoch == currentEpoch else { return }

        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))

        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            try? await Task.sleep(for: AppConfiguration.loadTimeout)
            guard let self, !Task.isCancelled,
                  self.epoch == currentEpoch,
                  self.appState == .loading else { return }
            self.appState = .showGame
        }
    }

    func resetAll() async {
        epoch &+= 1
        loadingTask?.cancel()

        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.url)
        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.route)
        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.partner)
        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.epoch)
        cookieManager.clear()

        webView.load(URLRequest(url: URL(string: "about:blank")!))

        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) { continuation.resume() }
        }

        appState = .idle
    }

    // MARK: - Private

    private func requestTrackingAuthorizationIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }

    private func buildStartURL() -> URL? {
        var components = URLComponents(string: "https://\(AppConfiguration.host)/start/")
        let bundleID = Bundle.main.bundleIdentifier ?? "com.cloakapp.game"
        components?.queryItems = [URLQueryItem(name: "bundle", value: bundleID)]

        let cachedURL = UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKey.url) ?? ""
        let cachedRoute = UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKey.route) ?? ""
        let cached = cachedURL.isEmpty ? cachedRoute : cachedURL
        if !cached.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "cached", value: cached))
        }

        let persistedEpoch = UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKey.epoch) ?? "0"
        components?.queryItems?.append(URLQueryItem(name: "epoch", value: persistedEpoch))

        return components?.url
    }

    private func handleForeground() async {
        guard appState == .showWeb else { return }
        let urlString = webView.url?.absoluteString ?? ""
        if urlString.isEmpty || urlString == "about:blank" {
            appState = .idle
            await start()
        }
    }

    private func handleResignActive() async {
        guard appState == .showWeb else { return }
        await saveCookies()
    }
}

// MARK: - NavigationHandlerDelegate

extension WebCoordinator: NavigationHandlerDelegate {
    func transition(to state: AppState) {
        if state != .loading {
            loadingTask?.cancel()
        }
        appState = state
    }

    func saveCookies() async {
        await cookieManager.save(from: webView.configuration.websiteDataStore.httpCookieStore)
    }
}

// MARK: - JSBridgeHandlerDelegate

extension WebCoordinator: JSBridgeHandlerDelegate {
    func handleReset() {
        epoch &+= 1
        loadingTask?.cancel()
        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.url)
        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.route)
        UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.partner)
        cookieManager.clear()
    }
}
