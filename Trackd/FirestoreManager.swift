//
//  FirestoreManager.swift


//

import Foundation
import Firebase
import FirebaseFirestore
import SwiftUI
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
    
    func randomNumericString(length: Int) -> String {
        let numbers = "0123456789"
        return String((0..<length).map{ _ in numbers.randomElement()! })
    }

    // Function to generate a unique username
    func generateUniqueUsername(baseString: String) -> String {
        let randomNumber = randomNumericString(length: 5)
        return "\(baseString)\(randomNumber)"
    }

    func createUser(email: String, password: String, username: String, completion: @escaping (User?) -> Void) {
        let userRef = db.collection("users").document()
        let userName = generateUniqueUsername(baseString: "TrackDer")
        
        db.collection("users").whereField("username", isEqualTo: userName).getDocuments { snapshot, error in
            guard let snapshot = snapshot else {
                print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            if snapshot.isEmpty {
                let newUser = User(id: userRef.documentID, email: email, password: password, username: userName, accountCreationDate: Date(), userInvitedIDs: [], friendIDs: [], profileUrl: "0", score: 0)
                userRef.setData(newUser.dictionary) { error in
                    if let error = error {
                        print("Error adding document: \(error)")
                        completion(nil)
                    } else {
                        print("User added with ID: \(newUser.id)")
                        completion(newUser)
                    }
                }
            } else {
                self.createUser(email: email, password: password, username: username, completion: completion)
            }
        }
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
                
                print("unwrap attempt")

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
                       
                       completion(user, nil)
                } else {
                    let dataError = NSError(domain: "DataUnwrapError", code: 1, userInfo: ["reason": "User data could not be unwrapped"])
                    completion(nil, dataError)
                }
            }
        }
    
}
