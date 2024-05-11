import Foundation
import FirebaseAuth
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore
import FirebaseCore

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
    
    func fetchUser(completion: @escaping (Bool) -> Void) {
        guard let userID = userID else {
            completion(false)
            return
        }
        
        Firestore.firestore().collection("users").document(userID).getDocument { document, error in
            if let document = document, document.exists {
                if let userData = document.data(),
                   let email = userData["email"] as? String,
                   let password = userData["password"] as? String,
                   let username = userData["username"] as? String,
                   let accountCreationDateTimestamp = userData["accountCreationDate"] as? Timestamp,
                   let userInvitedIDs = userData["userInvitedIDs"] as? [String],
                   let friendIDs = userData["friendIDs"] as? [String] {
                    
                    let accountCreationDate = accountCreationDateTimestamp.dateValue()
                    let user = User(id: userID,
                                    email: email,
                                    password: password,
                                    username: username,
                                    accountCreationDate: accountCreationDate,
                                    userInvitedIDs: userInvitedIDs,
                                    friendIDs: friendIDs)
                    self.userName = username
                    self.user = user
                    completion(true)
                } else {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
    
   
}
