import WebKit

@MainActor
protocol JSBridgeHandlerDelegate: AnyObject {
    func handleReset()
}

final class JSBridgeHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: JSBridgeHandlerDelegate?

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? String else { return }

        if body == "reset" {
            Task { @MainActor in self.delegate?.handleReset() }
            return
        }

        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["t"] as? String else { return }

        switch type {
        case "epoch":
            if let value = json["v"] as? String {
                UserDefaults.standard.set(value, forKey: AppConfiguration.UserDefaultsKey.epoch)
            }
        case "c":
            if let route = json["u"] as? String, !route.isEmpty {
                UserDefaults.standard.set(route, forKey: AppConfiguration.UserDefaultsKey.route)
            }
            if let partner = json["p"] as? String, !partner.isEmpty {
                UserDefaults.standard.set(partner, forKey: AppConfiguration.UserDefaultsKey.partner)
            }
        default:
            break
        }
    }
}
