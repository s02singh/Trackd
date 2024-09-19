
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
    @State private var isSigningin: Bool = false
    
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
                                    if let userId = authManager.userID{
                                        processSubmissionsForUser(userID: userId) {newscore, error in
                                            if let error = error {
                                                print("Error processing submissions: \(error)")
                                            } else {
                                                print("Submissions processed and last sign-in updated.")
                                                authManager.user?.score = newscore ?? 0
                                            }
                                        }
                                    }
                                    
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
                    isSigningin = true
                    
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
                        if let userId = authManager.userID{
                            processSubmissionsForUser(userID: userId) {newscore, error in
                                if let error = error {
                                    print("Error processing submissions: \(error)")
                                } else {
                                    print("Submissions processed and last sign-in updated.")
                                    authManager.user?.score = newscore ?? 0
                                }
                            }
                        }
                        
                    }
                    isSigningin = false
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
    
    
    func updateLastSignedIn(userID: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)
        
        // Update the "lastsignedin" field with the current server timestamp
        userRef.updateData([
            "lastsignedin": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating lastsignedin: \(error)")
            } else {
                print("Successfully updated lastsignedin field.")
            }
        }
    }
    

    // Function to compare last signed in date and process submissions
    func processSubmissionsForUser(userID: String, completion: @escaping (Int?, Error?) -> Void) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)
        
        // Fetch the last signed-in date and the current user score
        userRef.getDocument { documentSnapshot, error in
            if let error = error {
                print("Error fetching user data: \(error)")
                completion(nil, error)
                return
            }
            
            // Get the last signed-in date from Firestore
            let lastSignedIn = documentSnapshot?.get("lastsignedin") as? Timestamp ?? Timestamp(date: Date.distantPast)
            let lastSignedInDate = lastSignedIn.dateValue()
            
            // Get the user's current score from Firestore (default to 0 if missing)
            let currentScore = documentSnapshot?.get("score") as? Int ?? 0
            
            // Date formatter to match the Firestore dailySubmissions structure
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // Generate the list of dates between lastSignedInDate and currentDate
            var currentDateIter = Calendar.current.startOfDay(for: lastSignedInDate)
            let endDate = Calendar.current.startOfDay(for: Date())
            
            var totalScore = 0
            let dispatchGroup = DispatchGroup()

            while currentDateIter < endDate {
                // Convert the current date to the Firestore collection name format
                let dateString = dateFormatter.string(from: currentDateIter)
                let submissionsRef = db.collection("dailySubmissions").document(dateString).collection("submissions")
                
                dispatchGroup.enter()
                
                submissionsRef.whereField("userPosted", isEqualTo: userID)
                    .getDocuments { querySnapshot, error in
                        if let error = error {
                            print("Error fetching submissions for \(dateString): \(error)")
                            dispatchGroup.leave()
                            return
                        }
                        
                        querySnapshot?.documents.forEach { document in
                            if let score = document.get("score") as? Int {
                                totalScore += score
                            }
                        }
                        
                        dispatchGroup.leave()
                    }
                
                currentDateIter = Calendar.current.date(byAdding: .day, value: 1, to: currentDateIter) ?? currentDateIter
            }
            
            dispatchGroup.notify(queue: .main) {
                print("Total score from submissions since last sign-in: \(totalScore)")
                
                let newScore = currentScore + totalScore
                
                // Update the user's score and last signed-in date
                userRef.updateData([
                    "score": newScore,
                    "lastsignedin": Timestamp(date: Date())
                ]) { error in
                    if let error = error {
                        print("Error updating user score or last signed-in date: \(error)")
                        completion(nil, error)
                        return
                    }
                    
                    print("User's score and last signed-in date successfully updated.")
                    completion(newScore, nil) // Return the new score
                }
            }
        }
    }


    

    
}



struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
