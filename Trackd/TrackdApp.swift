import SwiftUI
import FirebaseAuth

@main
struct TrackdApp: App {
    // Basic setup of managers and check if signedin.
    // If you are signed in, you can skip the loginscreen.
    @AppStorage("signIn") var isSignIn = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authManager = AuthManager()
    @StateObject var firestoreManager = FirestoreManager()
    @StateObject private var spotifyManager = HomeViewModel()
    @State private var isActive = false // Add state for splash screen

    var body: some Scene {
        WindowGroup {
            // Use if-else to conditionally show splash screen or content
            if isActive {
                TrackdRoot()
                    .environmentObject(authManager)
                    .environmentObject(firestoreManager)
                    .environmentObject(spotifyManager)
                    .onAppear(){spotifyManager.getDailyTheme()}
            } else {
                Splash(isActive: $isActive)
            }
        }
    }
}
