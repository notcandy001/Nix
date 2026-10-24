import Foundation
import WebKit

/// Shell-facing engine boundary. WebKit is the only implemented adapter in v0.
@MainActor
protocol EngineAdapter: AnyObject {
    var webView: WKWebView { get }
    func load(_ url: URL)
    func goBack()
    func goForward()
    func reload()
}

@MainActor
final class WebKitEngineAdapter: EngineAdapter {
    let webView: WKWebView
    init(configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }
    func load(_ url: URL) { webView.load(URLRequest(url: url)) }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
}
