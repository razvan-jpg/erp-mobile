import SwiftUI
import WebKit

struct RemoteWebView: UIViewRepresentable {
    let url: URL
    var bottomInset: CGFloat = 0
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadFailed: $loadFailed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.navigationDelegate = context.coordinator
        applyScrollInsets(on: webView)
        context.coordinator.load(url: url, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        applyScrollInsets(on: webView)
        let coordinator = context.coordinator
        let targetURL = url
        DispatchQueue.main.async {
            coordinator.loadIfNeeded(url: targetURL, into: webView)
        }
    }

    private func applyScrollInsets(on webView: WKWebView) {
        webView.scrollView.contentInset.bottom = bottomInset
        webView.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var isLoading: Bool
        @Binding private var loadFailed: Bool
        private var loadedURL: URL?

        init(isLoading: Binding<Bool>, loadFailed: Binding<Bool>) {
            _isLoading = isLoading
            _loadFailed = loadFailed
        }

        func loadIfNeeded(url: URL, into webView: WKWebView) {
            guard loadedURL != url else { return }
            load(url: url, into: webView)
        }

        func load(url: URL, into webView: WKWebView) {
            loadedURL = url
            setLoadingState(isLoading: true, loadFailed: false)
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            setLoadingState(isLoading: false, loadFailed: false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishWithError()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishWithError()
        }

        private func finishWithError() {
            setLoadingState(isLoading: false, loadFailed: true)
        }

        private func setLoadingState(isLoading: Bool, loadFailed: Bool) {
            DispatchQueue.main.async { [self] in
                self.isLoading = isLoading
                self.loadFailed = loadFailed
            }
        }
    }
}
