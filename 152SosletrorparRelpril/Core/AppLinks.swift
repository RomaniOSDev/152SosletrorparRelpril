import Foundation

enum AppLink: String, CaseIterable {
    case privacyPolicy = "https://sosletrorparrelpril152.site/privacy/134"
    case termsOfUse = "https://sosletrorparrelpril152.site/terms/134"

    var url: URL? {
        URL(string: rawValue)
    }
}
