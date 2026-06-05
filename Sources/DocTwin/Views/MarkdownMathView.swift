import SwiftUI
import WebKit

struct MarkdownMathView: NSViewRepresentable {
    let markdown: String
    let title: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let signature = "\(title)\u{0}\(markdown)"
        guard context.coordinator.lastSignature != signature else {
            return
        }

        context.coordinator.lastSignature = signature
        webView.loadHTMLString(
            MarkdownHTMLRenderer.html(markdown: markdown, title: title),
            baseURL: baseURL
        )
    }

    final class Coordinator {
        var lastSignature: String?
    }
}
