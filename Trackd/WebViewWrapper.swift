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
        
        webView = WKWebView()
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
