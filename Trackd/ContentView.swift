import SwiftUI
import Foundation
import FirebaseAuth
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @State private var selection = 0
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var spotifyManager: HomeViewModel

    var body: some View {
        TabView(selection: $selection){
            HomeView()
                .environmentObject(authManager)
                .environmentObject(spotifyManager)
                .tabItem {
                    VStack {
                        Image(systemName: "house.fill")
                        Text("Home")
                            .foregroundColor(selection == 0 ? .blue : .black)
                    }
                }
                .tag(0)
            RanksView()
                .environmentObject(authManager)
                .environmentObject(spotifyManager)
                .tabItem {
                    VStack {
                        Image(systemName: "person.2.fill")
                        Text("Ranks")
                            .foregroundColor(selection == 1 ? .blue : .black)
                    }
                }
                .tag(1)
            ProfileView()
                .environmentObject(authManager)
                .tabItem {
                    VStack {
                        Image(systemName: "person.fill")
                        Text("Profile")
                            .foregroundColor(selection == 2 ? .blue : .black)
                    }
                }
                .tag(2)
        }
        .environmentObject(authManager)
    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
