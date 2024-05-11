import SwiftUI
import WebKit

struct WebViewWrapper: UIViewControllerRepresentable {
    typealias UIViewControllerType = WebViewController
    
    let url: URL
    let callbackURLScheme: String
    let onAuthorizationCodeReceived: (String) -> Void
    
    func makeUIViewController(context: Context) -> WebViewController {
        let viewController = WebViewController()
        viewController.url = url
        viewController.callbackURLScheme = callbackURLScheme
        viewController.onAuthorizationCodeReceived = onAuthorizationCodeReceived
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}
}

class WebViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var url: URL!
    var callbackURLScheme: String!
    var onAuthorizationCodeReceived: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.applicationNameForUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        
        webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        view = webView
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, url.absoluteString.hasPrefix(callbackURLScheme) else {
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }
        
        for queryItem in queryItems {
            if queryItem.name == "code", let code = queryItem.value {
                onAuthorizationCodeReceived?(code)
                break
            }
        }
    }
}
