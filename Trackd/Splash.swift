import Foundation
import FirebaseAuth
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore
import AuthenticationServices
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
            Task {
                if let storedUserId = UserDefaults.standard.string(forKey: "userID") {
                    authManager.userID = storedUserId
                }

                print(authManager.userID)
                if let user = await authManager.fetchUser() {
                    print("User fetched: \(user)")
                    processSubmissionsForUser(userID: user.id) {newscore, error in
                        if let error = error {
                            print("Error processing submissions: \(error)")
                        } else {
                            print("Submissions processed and last sign-in updated.")
                            authManager.user?.score = newscore ?? 0
                        }
                    }
                    self.isActive = true
                } else {
                    print("Failed to fetch user")
                    self.isActive = true
                }
            }
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
