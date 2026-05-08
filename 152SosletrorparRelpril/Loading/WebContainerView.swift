import SwiftUI
import WebKit

struct WebContainerView: UIViewRepresentable {
    @EnvironmentObject var coordinator: WebCoordinator

    func makeUIView(context: Context) -> WKWebView {
        coordinator.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
