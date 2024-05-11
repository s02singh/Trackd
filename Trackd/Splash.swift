import SwiftUI
import FirebaseAuth

struct Splash: View {
    @Binding var isActive: Bool
    @EnvironmentObject var authManager: AuthManager // Inject AuthManager

    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            Text("Trackd")
                .font(.custom("AvenirNext-DemiBold", size: 50))
                .fontWeight(.bold)
                .foregroundColor(.green)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.2)]), startPoint: .leading, endPoint: .trailing)
                )
                .mask(Text("Trackd")
                    .font(.custom("AvenirNext-DemiBold", size: 50))
                    .fontWeight(.bold)
                )
        }
        .onAppear {
            // Fetch user data
            authManager.fetchUser { success in
                if success {
                    // If user data is fetched successfully, set isActive to true
                    self.isActive = true
                }
            }
        }
     
    }
}
