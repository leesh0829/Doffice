import Foundation
import SwiftUI
import WebKit

// ═══════════════════════════════════════════════════════
// MARK: - Plugin Panel View (WKWebView 래퍼)
// ═══════════════════════════════════════════════════════

#if os(macOS)
public struct PluginPanelView: NSViewRepresentable {
    public let htmlURL: URL
    public let pluginName: String

    public init(htmlURL: URL, pluginName: String) {
        self.htmlURL = htmlURL
        self.pluginName = pluginName
    }

    public func makeNSView(context: Context) -> WKWebView {
        makeWebView()
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(webView)
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let handler = PluginMessageHandler()
        config.userContentController.add(handler, name: "doffice")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    private func loadContent(_ webView: WKWebView) {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
#elseif os(iOS)
public struct PluginPanelView: UIViewRepresentable {
    public let htmlURL: URL
    public let pluginName: String

    public init(htmlURL: URL, pluginName: String) {
        self.htmlURL = htmlURL
        self.pluginName = pluginName
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let handler = PluginMessageHandler()
        config.userContentController.add(handler, name: "doffice")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }
}
#endif

/// 플러그인 JS → 앱 통신 핸들러
public class PluginMessageHandler: NSObject, WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "getSessionInfo":
            // 세션 정보를 JS에 전달
            NotificationCenter.default.post(name: .pluginRequestSessionInfo, object: message.webView)
        case "notify":
            if let text = body["text"] as? String {
                NotificationCenter.default.post(name: .pluginNotify, object: nil, userInfo: ["text": text])
            }
        default:
            break
        }
    }
}

extension Notification.Name {
    public static let pluginRequestSessionInfo = Notification.Name("pluginRequestSessionInfo")
    public static let pluginNotify = Notification.Name("pluginNotify")
    public static let pluginReload = Notification.Name("pluginReload")
    public static let pluginEffectEvent = Notification.Name("pluginEffectEvent")
}
