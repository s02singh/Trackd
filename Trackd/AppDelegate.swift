import UIKit
import Firebase
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore


class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Other configurations
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle URL for Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        if url.scheme == "trackd://spotify-redirect" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                return false
            }
            for queryItem in queryItems {
                if queryItem.name == "code" {
                    guard let authorizationCode = queryItem.value else {
                        return false
                    }
                    // Handle authorization code (e.g., pass it to your ViewModel)
                    // viewModel.handleAuthorizationCode(authorizationCode)
                    return true
                }
            }
        }
        // Handle URL for Spotify authorization
        if url.scheme == "linkedin.com/in/sahil-singh-linked/" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems else {
                return false
            }
            for queryItem in queryItems {
                if queryItem.name == "code" {
                    guard let authorizationCode = queryItem.value else {
                        return false
                    }
                    // Handle authorization code
                    handleAuthorizationCode(authorizationCode)
                    return true
                }
            }
        }
        return false
    }

    func handleAuthorizationCode(_ code: String) {
        // You can use the authorization code to exchange it for an access token
        print("Authorization code: \(code)")
        // Example: Call a function to exchange the authorization code for an access token
            // exchangeAuthorizationCodeForAccessToken(code)
    }
    
   
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
