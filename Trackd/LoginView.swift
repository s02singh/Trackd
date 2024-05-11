
//
//  LoginView.swift

//
//  Created by Sahilbir Singh on 2/17/24.
//



import Foundation
import FirebaseAuth
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore
import AuthenticationServices


// LoginView: A view struct for the entire login process.

struct LoginView: View {
    @State var username: String = ""
    @State var password: String = ""
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var firestoreManager = FirestoreManager()
    @FocusState private var isKeyboardFocused: Bool
    @State private var showFields: Bool = false // Track whether to show fields or not
    
    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            VStack {
                // Display logo
                Image("TrackdLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                
                // Displays the header, a nice welcome message..
                LoginHeader()
                    .padding(.bottom)
                
                // Button to show username field
                Button(action: {
                    withAnimation {
                        showFields.toggle()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Sign in with Username")
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .padding(.horizontal, 7)
                .background(Color.black)
                .cornerRadius(6)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 1)
                )
                
                // Username field
                if showFields {
                    TextField("Username", text: $username)
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke()
                                .onTapGesture {
                                    isKeyboardFocused = true
                                }
                        )
                        .padding(.horizontal, 24)
                        .focused($isKeyboardFocused)
                        .padding(.vertical, 12)
                    
                    // Password field
                    TextField("Password", text: $password)
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke()
                                .onTapGesture {
                                    isKeyboardFocused = true
                                }
                        )
                        .padding(.horizontal, 24)
                        .focused($isKeyboardFocused)
                        .padding(.vertical, 12)
                        .padding(.bottom, 30)
                    
                    Button(action: {
                        isKeyboardFocused = false
                        
                        Task {
                            
                            do {
                                // if successful, it will set the user's appropriate firebalses
                                // after retrieving them from the firebase.
                                if let (userId, userName) = try await authManager.signIn(username: username, password: password) {
                                    
                                    UserDefaults.standard.set(userId, forKey: "userID")
                                    authManager.userID = userId
                                    authManager.userName = userName
                                    authManager.isSignIn = true
                                    UserDefaults.standard.set(true, forKey: "signIn")
                                    
                                } else {
                                    
                                }
                            } catch {
                                print("Error signing in: \(error)")
                            }
                        }
                        
                    }) {
                        HStack {
                            Spacer()
                            Text("Login")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 7)
                    .background(Color.black)
                    .cornerRadius(6)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white, lineWidth: 1)
                    )
                }
                
                // Login button
            
                
                // Spacer to push content to top
                Spacer()
                    .frame(height: 25)

                
                // Google signin button
                GoogleSigninBtn {
                    
                    // Google sigin functionality
                    guard let clientID = FirebaseApp.app()?.options.clientID else { return }
                    
                    let config = GIDConfiguration(clientID: clientID)
                    
                    GIDSignIn.sharedInstance.configuration = config
                    
                    // Opens window to login
                    GIDSignIn.sharedInstance.signIn(withPresenting: getRootViewController()) { signResult, error in
                        
                        if let error = error {
                            print(error)
                            return
                        }
                        
                        
                        // Retrieves all information from Google account to make a TenaCity account
                        // Also sets the authManager variables
                        guard let user = signResult?.user,
                              let idToken = user.idToken else { return }
                        
                        guard let profile = user.profile else{ return }
                        authManager.userName = profile.name
                        let accessToken = user.accessToken
                        
                        let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString, accessToken: accessToken.tokenString)
                        
                        Auth.auth().signIn(with: credential) { authResult, error in
                            
                        }
                        // Checks if email is already linked to a user
                        let db = Firestore.firestore()
                        let usersRef = db.collection("users")
                        
                        
                        guard let userProfile = user.profile else{return}
                        let userEmail = userProfile.email
                        
                        usersRef.whereField("email", isEqualTo: userEmail).getDocuments { querySnapshot, error in
                            if let error = error {
                                
                                print("Error querying Firestore: \(error.localizedDescription)")
                                return
                            }
                            
                            if let document = querySnapshot?.documents.first, document.exists {
                                // User exists
                                print("User already exists.")
                                if let userId = document.get("id") as? String {
                                    // Store user ID in UserDefaults
                                    UserDefaults.standard.set(userId, forKey: "userID")
                                    authManager.userID = userId
                                    firestoreManager.fetchUser(id: userId) { user, error in
                                        if let error = error {
                                            print("Error fetching user: \(error.localizedDescription)")
                                        } else if let fetchedUser = user {
                                            authManager.user = fetchedUser
                                        } else {
                                            print("User not found.")
                                        }
                                    }
                                    print(userId)
                                }
                            } else {
                                // User doesn't exist so make a new one
                                // Assuming this is where you call createUser
                                if let profile = user.profile {
                                    firestoreManager.createUser(email: userEmail, password: "!", username: profile.name) { newUser in
                                        if let newUser = newUser {
                                            authManager.user = newUser
                                            authManager.userID = newUser.id
                                            UserDefaults.standard.set(newUser.id, forKey: "userID")
                                        } else {
                                            // Handle error or retry logic
                                        }
                                    }
                                }

                            }
                        }
                        
                        print("SIGN IN")
                        UserDefaults.standard.set(true, forKey: "signIn")
                        
                    }
                }
                .padding(.top, 20)
                // GoogleSiginBtn
                
                SignInWithAppleButton(
                                   onRequest: { request in
                                       request.requestedScopes = [.fullName, .email]
                                   },
                                   onCompletion: { result in
                                       switch result {
                                       case .success(let authResults):
                                           print("Authorization successful: \(authResults)")
                                           // Handle successful authorization here
                                       case .failure(let error):
                                           print("Authorization failed: \(error.localizedDescription)")
                                           // Handle authorization failure here
                                       }
                                   }
                               )
                               .frame(height: 33) // Set the height to match the Google sign-in button
                              
                               .padding(.vertical, 6) // Adjust height
                               .cornerRadius(10) // Increase corner radius
                               .overlay(
                                   RoundedRectangle(cornerRadius: 30) // Rounded rectangle overlay
                                       .stroke(Color.white, lineWidth: 1) // Thin white outline
                                    
                                    
                               )
                               .font(.system(size: 20)) // Adjust text size
                               .padding(.horizontal, 118)
                               .cornerRadius(30)

                Spacer()
            }
            // VStack
            .onTapGesture {
                isKeyboardFocused = false
            }
            
            .padding(.top, 52)
        
        }
        .onTapGesture {
            isKeyboardFocused = false
        }
    }
}



struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
