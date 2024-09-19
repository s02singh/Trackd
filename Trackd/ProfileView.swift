import SwiftUI
import FirebaseAuth
import GoogleSignIn
import Firebase
import PhotosUI
import FirebaseStorage



struct ProfileView: View {
    @State private var user: User?
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isEditingUsername = false
    @State private var newUsername: String = ""
    @State private var isUsernameTaken = false
    @State private var loadingpfp = false

    var body: some View {
        VStack {
            topSection
            
            if let user = user {
                scoreAndFollowersHStack
                Text("Coming Soon!")
                    .font(.title3)
                    .font(.custom("AvenirNext-DemiBold", size: 50))
                    .padding(.top, 40)
                Spacer()
            } else {
                ProgressView("Loading profile...")
                    .padding()
            }

            Spacer()
            signOutButton
        }
        .padding()
        .background()
        .ignoresSafeArea(edges: .top)
        .onAppear {
            loadUserData()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, uploadImage: uploadImage).environmentObject(authManager)
        }
    }

    private var topSection: some View {
        VStack {
            if loadingpfp {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.0, green: 0.8, blue: 0.0)))
                    .scaleEffect(1.5)
                    .padding(.top, 50)
            } else {
                if let image = authManager.pfp {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .overlay(
                            Circle().stroke(Color.gray, lineWidth: 5)
                        )
                        .onTapGesture {
                            showingImagePicker = true
                        }
                } else {
                    Image("pfpicon")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.gray, lineWidth: 5)
                        )
                        .onTapGesture {
                            showingImagePicker = true
                        }
                }
            }
            
            // Username editing UI
            if isEditingUsername {
                HStack {
                    TextField("New Username", text: $newUsername)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .onChange(of: newUsername) { _ in
                            isUsernameTaken = false // Reset if user starts typing again
                        }
                    
                    // Save button
                    Button(action: checkAndSaveUsername) {
                        Text("Save")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                    .disabled(newUsername.isEmpty)
                    
                    // Cancel button
                    Button(action: {
                        withAnimation(.spring()) {
                            isEditingUsername = false
                            newUsername = authManager.userName ?? "" // Reset to the original username
                        }
                    }) {
                        Text("Cancel")
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                
                if isUsernameTaken {
                    Text("Username is taken")
                        .foregroundColor(.red)
                        .padding(.top, 5)
                }
            } else {
                // Display username with tap-to-edit functionality
                Text(authManager.userName ?? "Username")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 10)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isEditingUsername = true
                            newUsername = user?.username ?? ""
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
            }

        }
        .animation(.easeInOut, value: isEditingUsername)
        .padding(.top, 40)
    }

    private var scoreAndFollowersHStack: some View {
        HStack(spacing: 20) {
            scoreCard(title: "Score", value: "\(authManager.user?.score ?? 0)")
            scoreCard(title: "Followers", value: "\(authManager.user?.friendIDs.count ?? 0)")
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

    // Sign out button
    private var signOutButton: some View {
        Button(action: signOut) {
            Text("Sign Out")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(10)
        }
        .padding(.top, 30)
    }

    // Function to check if username is taken and save if available
    private func checkAndSaveUsername() {
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        usersRef.whereField("username", isEqualTo: newUsername).getDocuments { snapshot, error in
            guard error == nil else {
                print("Error checking username: \(error!.localizedDescription)")
                return
            }

            if let documents = snapshot?.documents, !documents.isEmpty {
                isUsernameTaken = true
            } else {
                // Update username
                if let userID = authManager.userID {
                    usersRef.document(userID).updateData(["username": newUsername]) { error in
                        if let error = error {
                            print("Error updating username: \(error.localizedDescription)")
                        } else {
                            print("Username successfully updated!")
                            user?.username = newUsername
                            
                            authManager.userName = newUsername
                            isEditingUsername = false
                        }
                    }
                }
            }
        }
    }

    // Load user data from AuthManager
    private func loadUserData ()  {
        if let currentUser = authManager.user {
            self.user = currentUser
            Task{
                await authManager.loadProfileImage(for: currentUser.id)
            }
        }
    }
    

    
    // Top Artist Component
    private func topArtistCard(user: User) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Artist")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "music.note")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.purple).frame(width: 60, height: 60))
                    .shadow(radius: 5)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("bleh")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Most played in 2024")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
        .padding(.vertical, 20)
    }
    
 
    
    
    // Upload selected image to Firebase Storage and save URL to Firestore
    private func uploadImage(image: UIImage) {
        loadingpfp = true
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        guard let userId = authManager.userID else{return}
        
        let storageRef = Storage.storage().reference().child("profile_images/\(userId).jpg")
        
        // Upload image to Firebase Storage
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            guard error == nil else {
                print("Error uploading image: \(error!.localizedDescription)")
                return
            }
            
            // Retrieve download URL
            storageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Failed to get download URL")
                    return
                }
                
                // Save the download URL to Firestore under user's profile
                let db = Firestore.firestore()
                if let userID = authManager.user?.id {
                    let userDoc = db.collection("users").document(userID)
                    userDoc.updateData(["profilePicURL": downloadURL.absoluteString]) { error in
                        if let error = error {
                            print("Error saving URL to Firestore: \(error.localizedDescription)")
                        } else {
                            print("Profile image URL successfully saved to Firestore!")
                            authManager.pfp = image
                            loadingpfp = false
                        }
                    }
                }
            }
        }
    }
    
    // Sign out function
    private func signOut() {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            UserDefaults.standard.set(false, forKey: "signIn")
            UserDefaults.standard.set(nil, forKey: "userID")
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

// ImagePicker component for picking image
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @EnvironmentObject var authManager: AuthManager
    var uploadImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let selectedImage = image as? UIImage {
                        self.parent.selectedImage = selectedImage
                        // Call uploadImage here after the image is selected
                        self.parent.uploadImage(selectedImage)
                    
                    }
                }
            }
        }
    }
}
