import Foundation

enum AppState: Equatable {
    case idle
    case loading
    case showGame
    case showWeb
}

enum AppConfiguration {
    static let host = "keitaroapps.online"
    static let loadTimeout: Duration = .seconds(25)
    static let jsHandlerName = "jsHandler"

    enum UserDefaultsKey {
        static let url     = "cached_url_v2"
        static let route   = "cached_route_v2"
        static let partner = "cached_partner_v1"
        static let cookies = "wk_cookies_v2"
        static let epoch   = "reset_epoch_v1"
    }
}
