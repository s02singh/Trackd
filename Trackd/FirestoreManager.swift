//
//  FirestoreManager.swift


//

import Foundation
import Firebase
import FirebaseFirestore

class FirestoreManager: ObservableObject {
    var db: Firestore
    // maybe todo: make a state object of the current user
    
    init() {
        db = Firestore.firestore()
        //populateFirestore()
        /* How to fetch a user
         fetchUser(id: "LJ92RtswXZzgZFK2J6EM") { user, error in
         if let error = error {
         print("Error fetching user: \(error.localizedDescription)")
         } else if let user = user {
         print("Fetched user: \(user)")
         } else {
         print("User not found.")
         }
         }
         */
    }
    
    func createUser(email: String, password: String, username: String) -> User {
        let userRef = db.collection("users").document()
        let newUser = User(id: userRef.documentID, email: email, password: password, username: username, accountCreationDate: Date(), userInvitedIDs: [], friendIDs: [])
        userRef.setData(newUser.dictionary) { error in
            if let error = error {
                print("Error adding document: \(error)")
            } else {
                print("User added with ID: \(String(describing: newUser.id))")
            }
        }
        return newUser
    }
    
    func fetchUser(id: String, completion: @escaping (User?, Error?) -> Void) {
            let userDocument = db.collection("users").document(id)

            userDocument.getDocument { document, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let document = document, document.exists else {
                    completion(nil, nil)
                    return
                }

                if let userData = document.data(),
                   let id = userData["id"] as? String,
                   let email = userData["email"] as? String,
                   let password = userData["password"] as? String,
                   let username = userData["username"] as? String,
                   let accountCreationTimestamp = userData["accountCreationDate"] as? Timestamp,
                   let userInvitedIDs = userData["userInvitedIDs"] as? [String],
                   let friendIDs = userData["friendIDs"] as? [String] {
                       let user = User(id: id,
                                       email: email,
                                       password: password,
                                       username: username,
                                       accountCreationDate: accountCreationTimestamp.dateValue(),
                                       userInvitedIDs: userInvitedIDs,
                                       friendIDs: friendIDs)
                       
                       completion(user, nil)
                } else {
                    let dataError = NSError(domain: "DataUnwrapError", code: 1, userInfo: ["reason": "User data could not be unwrapped"])
                    completion(nil, dataError)
                }
            }
        }
    
}
