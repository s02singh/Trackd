import SwiftUI
import AVFoundation
import FirebaseFirestore

struct TrackDisplay {
    var trackInfo: TrackInfo
    var documentID: String
    var userVotes: [String: Int] // Dictionary to store user votes
}

struct RanksView: View {
    @State private var trackDisplays: [TrackDisplay] = []
    @State private var selection = 0 // 0 for Trending, 1 for New
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var spotifyManager: HomeViewModel
    @State var lastPlayed: String = " "
    @State var isPlaying: Bool = false

    var body: some View {
        VStack {
            LinearGradientText(text: spotifyManager.dailyTheme)
                    .font(.custom("AvenirNext-DemiBold", size: 50))
                    .fontWeight(.bold)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
            
            Picker(selection: $selection, label: Text("")) {
                Text("Trending").tag(0)
                Text("New").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selection) { _ in
                fetchTracks() // Call fetchTracks() when the selection changes
            }

            List(trackDisplays.indices, id: \.self) { index in
                TrackRow(trackDisplay: trackDisplays[index], upvoteAction: {
                    upvoteTrack(index: index)
                }, downvoteAction: {
                    downvoteTrack(index: index)
                }
                         , isPlaying: $isPlaying
                         , lastPlayed: $lastPlayed
                         , trackDisplays: $trackDisplays
                        
                )
                .environmentObject(authManager)
                .environmentObject(spotifyManager)
            }
        }
        .onAppear {
            fetchTracks() // Fetch tracks initially
        }
    }

    func fetchTracks() {
        let collection = Firestore.firestore().collection("dailySubmissions")
        var query: Query

        if selection == 0 {
            // Trending: Query based on score, descending
            query = collection.order(by: "score", descending: true).limit(to: 10)
        } else {
            // New: Query based on timestamp, descending
            query = collection.order(by: "timestamp", descending: true).limit(to: 10)
        }

        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching tracks: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No tracks found")
                return
            }

            // Parse documents into TrackDisplay objects
            trackDisplays = documents.compactMap { document in
                do {
                    if let submissionString = document.data()["submission"] as? String,
                       let jsonData = submissionString.data(using: .utf8),
                       let firebaseTrackInfo = try? JSONDecoder().decode(FirebaseTrackInfo.self, from: jsonData)
                    {
                        let trackInfo = TrackInfo(name: firebaseTrackInfo.name,
                                                  artist: firebaseTrackInfo.artist,
                                                  previewUrl: firebaseTrackInfo.previewUrl.flatMap { URL(string: $0) },
                                                  coverUrl: firebaseTrackInfo.coverUrl.flatMap { URL(string: $0) },
                                                  score: document.data()["score"] as? Int ?? 0)

                        // Check if the current user has upvoted or downvoted this track
                        _ = authManager.userID ?? ""
                        let userVotes = document.data()["userVotes"] as? [String: Int] ?? [:]

                        return TrackDisplay(trackInfo: trackInfo, documentID: document.documentID, userVotes: userVotes)
                    }
                } catch {
                    print("Error parsing track: \(error)")
                }
                return nil
            }
        }
    }
}

struct TrackRow: View {
    let trackDisplay: TrackDisplay
    let upvoteAction: () -> Void
    let downvoteAction: () -> Void
    @State private var isUpvoted = false
    @State private var isDownvoted = false
    @EnvironmentObject var authManager: AuthManager
    @State private var isPlayingPreview = false // State to track playback
    @Binding var isPlaying: Bool // State to track playback
    @EnvironmentObject var spotifyManager: HomeViewModel
    var playerItem: AVPlayerItem?
    @Binding var lastPlayed: String
    @Binding var trackDisplays: [TrackDisplay]
    @State var playIcon: Bool = false

    var body: some View {
        HStack {
            if let coverUrl = trackDisplay.trackInfo.coverUrl {
                AsyncImage(url: coverUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(5)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .cornerRadius(5)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .cornerRadius(5)
            }

            VStack(alignment: .leading) {
                Text(trackDisplay.trackInfo.name)
                    .font(.headline)
                Text(trackDisplay.trackInfo.artist)
                    .font(.subheadline)
                HStack {
                    Button(action: {
                        if !isUpvoted {
                            isUpvoted = true
                            if isDownvoted {
                                isDownvoted = false
                                upvoteAction()
                            }
                            upvoteAction()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(isUpvoted ? .green : .primary) // Set color based on upvote state

                    Text("\(trackDisplay.trackInfo.score)")
                        .foregroundColor(isUpvoted ? .green : (isDownvoted ? .red : .yellow))
                        .padding(.horizontal, 4)
                        .background(isUpvoted ? Color.green.opacity(0.3) : (isDownvoted ? Color.red.opacity(0.3) : Color.yellow.opacity(0.3)))
                        .cornerRadius(4)

                    Button(action: {
                        if !isDownvoted {
                            isDownvoted = true
                            if isUpvoted {
                                isUpvoted = false
                                downvoteAction()
                            }
                            downvoteAction()
                        }
                    }) {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(isDownvoted ? .red : .primary) // Set color based on downvote state
                }
            }

            Spacer()

            if trackDisplay.trackInfo.previewUrl != nil {
                Button(action: {
                    togglePreview()
                })
                {
                    Image(systemName: isPlayingPreview ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
                    // Preview ended, set isPlayingPreview to false
                    isPlayingPreview = false
                }
                .onChange(of: isPlaying) { newValue in
                    // Handle changes to isPlaying here
                    if(lastPlayed != trackDisplay.documentID){
                        isPlayingPreview = false
                    }
                }
            }
            
        }
        .padding(.vertical, 8)
        .onAppear {
            // Check if the current user has upvoted or downvoted this track
            let currentUserID = authManager.userID ?? ""
            if let vote = trackDisplay.userVotes[currentUserID] {
                if vote == 0 {
                    isUpvoted = true
                } else if vote == 1 {
                    isDownvoted = true
                }
            }
        }
    }

    private func togglePreview() {
        if isPlayingPreview {
            // Pause the preview
            spotifyManager.audioPlayer?.pause()
        } else {
            // Play the preview
            lastPlayed = trackDisplay.documentID
            isPlaying.toggle()
            if let previewUrl = trackDisplay.trackInfo.previewUrl {
                spotifyManager.audioPlayer?.pause() // Pause any other previews playing
                spotifyManager.audioPlayer = AVPlayer(url: previewUrl)
                spotifyManager.audioPlayer?.play()
            }
        }
        isPlayingPreview.toggle() // Toggle playback state
    }
}

extension RanksView {
    func upvoteTrack(index: Int) {
        guard let userID = authManager.userID // Replace with actual user ID
        else{ return }

        // Update local score
        trackDisplays[index].trackInfo.score += 1
        trackDisplays[index].userVotes[userID] = 0 // Upvote

        // Update score and user votes in Firestore
        updateFirestoreData(index: index)
    }

    func downvoteTrack(index: Int) {
        guard let userID = authManager.userID // Replace with actual user ID
        else{ return }

        // Update local score
        trackDisplays[index].trackInfo.score -= 1
        trackDisplays[index].userVotes[userID] = 1 // Downvote

        // Update score and user votes in Firestore
        updateFirestoreData(index: index)
    }

    func updateFirestoreData(index: Int) {
        let trackDisplay = trackDisplays[index]
        let collection = Firestore.firestore().collection("dailySubmissions")

        let documentRef = collection.document(trackDisplay.documentID)
        documentRef.updateData([
            "score": trackDisplay.trackInfo.score,
            "userVotes": trackDisplay.userVotes // Update user votes in Firestore
        ]) { error in
            if let error = error {
                print("Error updating data in Firestore: \(error)")
            } else {
                print("Data updated successfully")
            }
        }
    }
}

