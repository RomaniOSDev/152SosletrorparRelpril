import WebKit

@MainActor
protocol NavigationHandlerDelegate: AnyObject {
    var appState: AppState { get }
    func transition(to state: AppState)
    func saveCookies() async
}

@MainActor
final class NavigationHandler: NSObject {
    weak var delegate: NavigationHandlerDelegate?
    private(set) var retryCount = 0

    func reset() {
        retryCount = 0
    }
}

// MARK: - WKNavigationDelegate

extension NavigationHandler: WKNavigationDelegate {

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if scheme != "http" && scheme != "https" && scheme != "about" {
            decisionHandler(.cancel)
            Task { @MainActor in UIApplication.shared.open(url) }
            return
        }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if host.hasSuffix(AppConfiguration.host),
           path == "/game" || path == "/game/" || path.hasPrefix("/cleargame") {
            decisionHandler(.cancel)
            Task { @MainActor in self.delegate?.transition(to: .showGame) }
            return
        }

        decisionHandler(.allow)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard let delegate,
                  delegate.appState == .loading || delegate.appState == .showWeb,
                  let url = webView.url,
                  let host = url.host?.lowercased() else { return }

            let urlString = url.absoluteString
            guard urlString != "about:blank",
                  !host.hasSuffix(AppConfiguration.host),
                  !host.contains("track.rave") else { return }

            UserDefaults.standard.set(urlString, forKey: AppConfiguration.UserDefaultsKey.url)
            await delegate.saveCookies()

            if delegate.appState == .loading {
                delegate.transition(to: .showWeb)
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in await self.handleLoadFailure(webView: webView, error: error) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in await self.handleLoadFailure(webView: webView, error: error) }
    }

    // MARK: - Private

    private func handleLoadFailure(webView: WKWebView, error: Error) async {
        guard let delegate, delegate.appState == .loading else { return }
        if (error as NSError).code == NSURLErrorCancelled { return }

        let nsErr = error as NSError
        let failedURLString = nsErr.userInfo[NSURLErrorFailingURLStringErrorKey] as? String ?? ""
        let failedHost = URL(string: failedURLString)?.host?.lowercased() ?? ""
        let isExternal = !failedHost.isEmpty && !failedHost.hasSuffix(AppConfiguration.host)
        let partnerURL = UserDefaults.standard.string(forKey: AppConfiguration.UserDefaultsKey.partner) ?? ""

        if isExternal, !partnerURL.isEmpty, retryCount < 2, let url = URL(string: partnerURL) {
            retryCount += 1
            UserDefaults.standard.removeObject(forKey: AppConfiguration.UserDefaultsKey.url)
            webView.load(URLRequest(url: url))
            return
        }

        delegate.transition(to: .showGame)
    }
}
