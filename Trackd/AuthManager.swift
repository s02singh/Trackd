import Foundation
import FirebaseAuth
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore
import FirebaseCore
import FirebaseStorage

class AuthManager: ObservableObject {
    // records various auth variables
    // this includes a signin bool, the username, userID, and the User struct.
    @Published var isSignIn = false
    @Published var isLoading = true
    @Published var userName: String?
    @Published var userID: String?
    @Published var user: User?
    @Published private var password: String?
    @ObservedObject var firestoreManager = FirestoreManager()
    @Published var authToken: String? = nil
    @Published var accessToken: String? = nil
    @Published var pfp: UIImage?
 
    
    init() {
        let token = UserDefaults.standard.string(forKey: "authToken")
        if let token = token
        {
            authToken = token
        }
        let userId = UserDefaults.standard.string(forKey: "userID")
        if let userId = userId {
            userID = userId
        }
        pfp = UIImage(named: "profileicon")
    }
    
    // Allows user to update their password
    func updatePassword(pswd: String) {
        self.password = pswd
    }
    
    // Small function for easy check if signin
    func checkUserSignIn() {
        if let _ = Auth.auth().currentUser {
            isSignIn = true
        } else {
            isSignIn = false
        }
        isLoading = false
    }
    
    // signin function used when logging in with a password and username.
    func signIn(username: String, password: String) async throws -> (userId: String, username: String)?{
        print(username)
        // Fetches the user with the current username
        let users = try await Firestore.firestore().collection("users").whereField("username", isEqualTo: username).getDocuments()
         
        // It will compare the passwords of the firestore saved and current inputted.
        let documents = users.documents
        print(documents)
        if let user = documents.first?.data() {
            if let storedPassword = user["password"] as? String {
                if comparePasswords(password: password, storedPassword: storedPassword) {
                    if let userId = documents.first?.documentID, let userName = user["username"] as? String {
                        print(userName)
                        print(userId)
                        self.userID = userID
                        Task {
                            if let user = await self.fetchUser() {
                                print("User fetched: \(user)")
                            } else {
                                print("Failed to fetch user")
                            }
                        }
                        return (userId, userName)
                    }
                }
            }
        }
        return nil
      }
    
    // Helper function to compare passwords. Can incorporate hashing later if we wanted.
    private func comparePasswords(password: String, storedPassword: String) -> Bool {
        return password == storedPassword
      }
    
    // Quick access function to sign out. sets sign in to false.
    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignIn = false
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    func fetchUser() async -> User? {
        print("Fetching user...")
        guard let userID = userID else {
            return nil
        }

        do {
            let document = try await Firestore.firestore().collection("users").document(userID).getDocument()

            print("Document retrieved")

            if let userData = document.data(),
               let id = userData["id"] as? String,
               let email = userData["email"] as? String,
               let password = userData["password"] as? String,
               let username = userData["username"] as? String,
               let accountCreationTimestamp = userData["accountCreationDate"] as? Timestamp,
               let userInvitedIDs = userData["userInvitedIDs"] as? [String],
               let friendIDs = userData["friendIDs"] as? [String],
               let profileUrl = userData["profileUrl"] as? String,
               let score = userData["score"] as? Int
            {
                let user = User(id: id,
                                email: email,
                                password: password,
                                username: username,
                                accountCreationDate: accountCreationTimestamp.dateValue(),
                                userInvitedIDs: userInvitedIDs,
                                friendIDs: friendIDs,
                                profileUrl: profileUrl,
                                score: score
                )
                
                print("Assigning user data")
                DispatchQueue.main.async {
                    self.userName = username
                    self.user = user
                }
                
                // Start loading the profile image in the background after returning the user
            
                await loadProfileImage(for: userID)
        
                
                return user
            }
        } catch {
            print("Error fetching user: \(error)")
        }

        return nil
    }
    
    func loadProfileImage(for userID: String) async {
        let storageRef = Storage.storage().reference().child("profile_images/\(userID).jpg")
        
        do {
            // Fetch image data from Firebase Storage
            let data = try await storageRef.data(maxSize: 1 * 1024 * 1024) // 1 MB max size
            // Convert data to UIImage
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.pfp = image
                }
            } else {
                print("Failed to convert data to UIImage")
                DispatchQueue.main.async {
                    self.pfp = UIImage(named: "profileicon")
                }
            }
        } catch {
            print("Error fetching profile image: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.pfp = UIImage(named: "profileicon")
            }
        }
    }



    
   
}
