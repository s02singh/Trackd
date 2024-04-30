
import SwiftUI
import FirebaseAuth


struct TrackdRoot: View {
    
    // Basic setup of managers and check if signedin.
    // If you are signed in, you can skip the loginscreen.
    @AppStorage("signIn") var isSignIn = false
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var spotifyManager: HomeViewModel
    
    var body: some View {
            if !isSignIn {
                LoginView()
                    .environmentObject(authManager)
                    .environmentObject(firestoreManager)
            } else {
                NavigationStack {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(firestoreManager)
                        .environmentObject(spotifyManager)
                }
                .environmentObject(authManager)
                .environmentObject(firestoreManager)
            }
        }
    
}
