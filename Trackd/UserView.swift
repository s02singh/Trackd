import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct UserView: View {
    let username: String
    @State private var userData: UserData? = nil
    @State private var isLoading = true
    @State private var task: Task<Void, Never>? = nil
    @EnvironmentObject var authManager: AuthManager
    @State private var isFriend = false
    @State private var isAddingFriend = false
    @State private var followNum: Int = 0

    var body: some View {
        VStack {
            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if let userData = userData {
                VStack {
                    HStack {
                        Text("\(userData.username)")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        
                        // Small circular "+" button or checkmark depending on isFriend state
                        Button(action: toggleFriendStatus) {
                            if isFriend {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Color.green))
                            } else {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Color.green))
                            }
                        }
                        .disabled(isAddingFriend)  // Disable button while adding/removing friend
                    }
                    .padding(.top, 40)
                    
                    if let userpfp = userData.profileImage {
                        Image(uiImage: userpfp)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .shadow(radius: 10)
                            .overlay(
                                Circle().stroke(Color.gray, lineWidth: 5)
                            )
                            .clipShape(Circle())
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.0, green: 0.8, blue: 0.0)))
                            .scaleEffect(1.5)
                            .padding(.top, 50)
                    }
                    scoreAndFollowersHStack
                    Spacer()
                    Text("Coming Soon!")
                        .font(.title3)
                    Spacer()
                }
            } else {
                Spacer()
                Text("User not found")
                    .font(.title3)
                    .font(.custom("AvenirNext-DemiBold", size: 50))
                Spacer()
            }
            Spacer()
        }
        .onAppear {
            fetchUserData(for: username) { fetchedData in
                self.userData = fetchedData
                if let fetchedData = fetchedData {
                    task = Task {
                        await loadProfileImage(for: fetchedData.userId)
                    }
                    checkIfFriend()  // Check if current user is already a friend
                }
                self.isLoading = false
            }
        }
        .onDisappear {
            task?.cancel()
        }
    }

    private var scoreAndFollowersHStack: some View {
        HStack(spacing: 20) {
            scoreCard(title: "Score", value: "\(userData?.score ?? 0)")
            scoreCard(title: "Followers", value: "\(followNum)")
        }
        .padding(.vertical, 20)
    }

    private func scoreCard(title: String, value: String) -> some View {
        VStack(spacing: 10) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 120, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.2))
                .shadow(color: Color.gray.opacity(0.4), radius: 10, x: 0, y: 5)
        )
        .cornerRadius(15)
        .shadow(radius: 10)
    }

    // Function to toggle the friend status
    private func toggleFriendStatus() {
        if isFriend {
            removeFriend()
        } else {
            addFriend()
        }
    }

    // Function to add current user as a friend
    private func addFriend() {
        guard let userData = userData, let currentUserId = authManager.userID else { return }
        isAddingFriend = true

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userData.userId)

        userRef.updateData([
            "friendIDs": FieldValue.arrayUnion([currentUserId])
        ]) { error in
            if let error = error {
                print("Error adding friend: \(error)")
                isAddingFriend = false
                return
            }

            // Update UI after successfully adding friend
            followNum += 1
            isFriend = true
            isAddingFriend = false
        }
    }

    // Function to remove current user as a friend
    private func removeFriend() {
        guard let userData = userData, let currentUserId = authManager.userID else { return }
        isAddingFriend = true

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userData.userId)

        userRef.updateData([
            "friendIDs": FieldValue.arrayRemove([currentUserId])
        ]) { error in
            if let error = error {
                print("Error removing friend: \(error)")
                isAddingFriend = false
                return
            }

            // Update UI after successfully removing friend
            followNum -= 1
            isFriend = false
            isAddingFriend = false
        }
    }

    // Check if the current user is already a friend
    private func checkIfFriend() {
        guard let userData = userData, let currentUserId = authManager.userID else { return }
        if userData.followers.contains(currentUserId) {
            isFriend = true
        }
    }

    // Function to fetch user data based on username
    func fetchUserData(for username: String, completion: @escaping (UserData?) -> Void) {
        let db = Firestore.firestore()
        let usersCollection = db.collection("users")

        usersCollection.whereField("username", isEqualTo: username).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error)")
                completion(nil)
                return
            }

            guard let document = snapshot?.documents.first,
                  let data = document.data() as? [String: Any] else {
                completion(nil)
                return
            }

            let userData = UserData(
                username: data["username"] as? String ?? "Unknown",
                bio: data["bio"] as? String ?? "",
                profileImage: nil,
                userId: data["id"] as? String ?? "",
                score: data["score"] as? Int ?? 0,
                followers: data["friendIDs"] as? [String] ?? []
            )
            followNum = userData.followers.count

            completion(userData)
        }
    }

    func loadProfileImage(for userID: String) async {
        let storageRef = Storage.storage().reference().child("profile_images/\(userID).jpg")

        do {
            let data = try await storageRef.data(maxSize: 1 * 1024 * 1024) // 1 MB max size
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    userData?.profileImage = image
                }
            } else {
                DispatchQueue.main.async {
                    userData?.profileImage = UIImage(named: "profileicon")
                }
            }
        } catch {
            DispatchQueue.main.async {
                userData?.profileImage = UIImage(named: "profileicon")
            }
        }
    }
}

// UserData model to store the user's info
struct UserData {
    var username: String
    var bio: String
    var profileImage: UIImage?
    var userId: String
    var score: Int
    var followers: [String]
}
