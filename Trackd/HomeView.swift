import Foundation
import FirebaseAuth
import Combine
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore
import AuthenticationServices
import WebKit
import AVFoundation

class HomeViewModel: ObservableObject {
    @Published var currentTrack: TrackInfo?
    @Published var authorized = false
    private var cancellables = Set<AnyCancellable>()
    private let spotifyAPI: SpotifyAPI
    @Published var searchText: String = ""
    var accessToken: String?
    private var searchCancellable: AnyCancellable?
    @Published var searchResults: [TrackInfo] = []
    @Published var dailyTheme: String = ""
    

    @Published var audioPlayer: AVPlayer?

    init() {
        // Replace with your Spotify client ID and client secret
        let clientId = "2b5e025dbfe94f2ea67d23ec1f934e4e"
        let clientSecret = "0d741bafed4e442ebe91cf72c08bc423"
    
        

        // Create a Spotify API client
        self.spotifyAPI = SpotifyAPI(clientId: clientId, clientSecret: clientSecret)
        /*searchCancellable = $searchText
                .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
                .sink { [weak self] searchText in
                    self?.searchTrack(query: searchText)
                }
         */
    }

    func getDailyTheme() {
        let db = Firestore.firestore()
        
        // Reference to the dailyThemes collection
        let dailyThemesRef = db.collection("dailyThemes")
        
        // Get today's date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/dd/yyyy"
        let todayDateString = dateFormatter.string(from: Date())
        
        // Query the dailyThemes collection
        dailyThemesRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching daily themes: \(error.localizedDescription)")
                return
            }
            
            // Check if there are any documents
            guard let documents = snapshot?.documents else {
                print("No daily themes documents found")
                return
            }
            
            // Check if the first document exists
            guard let firstDocument = documents.first else {
                print("No daily themes found")
                return
            }
            
            // Extract the themes map from the first document
            let themesMap = firstDocument.data()["themes"] as? [String: String] ?? [:]
            
            // Get the theme for today's date
            if let dailyTheme = themesMap[todayDateString] {
                // If a theme exists for today, set it
                self.dailyTheme = dailyTheme
            } else {
                // If no theme exists for today, select a random one
                if let randomTheme = themesMap.values.randomElement() {
                    self.dailyTheme = randomTheme
                } else {
                    print("No themes available")
                }
            }
        }
    }
    
    func authorizeSpotify(completion: @escaping (Bool) -> Void) {
        let authorizationURL = "https://accounts.spotify.com/authorize?client_id=2b5e025dbfe94f2ea67d23ec1f934e4e&response_type=code&redirect_uri=https://advancebrokerage.net/&scope=user-read-private"
        guard let url = URL(string: authorizationURL) else {
            completion(false)
            return
        }

        // Create a background task to load the authorization URL
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Authorization request error: \(error)")
                completion(false)
                return
            }

            guard data != nil else {
                print("Authorization request returned no data")
                completion(false)
                return
            }

            // Process the data to extract the authorization code
            if let responseURL = response?.url, let code = self.extractAuthorizationCode(from: responseURL) {
                print(code)
                self.handleAuthorizationRedirect(code: code)
                completion(true)
            } else {
                print("Authorization code not found")
                completion(false)
            }
        }.resume()
    }


    // Function to extract the authorization code from the response URL
    func extractAuthorizationCode(from url: URL) -> String? {
        // Parse the URL's query parameters
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = urlComponents?.queryItems
        
        // Look for the "code" parameter
        return queryItems?.first { $0.name == "code" }?.value
    }

 
    
    func handleAuthorizationRedirect(code: String) {
        // Request access token using the authorization code
        spotifyAPI.requestAccessToken(authorizationCode: code)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error requesting access token: \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { accessToken in
                // Store the access token
                print(accessToken)
                self.accessToken = accessToken
                // Fetch a sample track
                
            })
            .store(in: &cancellables)
    }

    func searchTrack(query: String) {
        guard let accessToken = accessToken else {
            print("Access token is missing")
            return
        }

        spotifyAPI.searchTrack(query: query, accessToken: accessToken)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error searching track: \(error)")
                    DispatchQueue.main.async {
                        self.currentTrack = nil
                    }
                case .finished:
                    break
                }
            }, receiveValue: { track in
                DispatchQueue.main.async {
                    self.currentTrack = TrackInfo(name: track.name, artist: track.artists[0].name, previewUrl: track.previewUrl, coverUrl: track.coverUrl, score: 0, URI: track.uri)
                }
            })
            .store(in: &cancellables)
    }

    func searchTracks(query: String) {
        guard let accessToken = accessToken else {
            print("Access token is missing")
            return
        }

        spotifyAPI.searchTracks(query: query, accessToken: accessToken)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error searching tracks: \(error)")
                    DispatchQueue.main.async {
                        self.searchResults = []
                    }
                case .finished:
                    break
                }
            }, receiveValue: { tracks in
                DispatchQueue.main.async {
                    var uniqueTracks: [TrackInfo] = []
                    var trackSet = Set<String>()

                    for track in tracks {
                        let trackIdentifier = "\(track.name) by \(track.artists.map { $0.name }.joined(separator: ", "))"
                        // Check if track identifier is already in the set, if not, add it to results
                        if !trackSet.contains(trackIdentifier) {
                            let trackInfo = TrackInfo(name: track.name, artist: track.artists.map { $0.name }.joined(separator: ", "),  previewUrl: track.previewUrl, coverUrl: track.coverUrl, score: 0, URI: track.uri)
                            uniqueTracks.append(trackInfo)
                            trackSet.insert(trackIdentifier)
                        }
                    }

                    // Update searchResults with unique tracks
                    self.searchResults = uniqueTracks
                }
            })
            .store(in: &cancellables)
    }


    
    func fetchTrack() {
        guard let accessToken = accessToken else {
            print("Access token is missing")
            return
        }

        spotifyAPI.fetchTrack(trackId: "67nepsnrcZkowTxMWigSbb", accessToken: accessToken)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error fetching track: \(error)")
                    DispatchQueue.main.async {
                        self.currentTrack = nil
                    }
                case .finished:
                    break
                }
            }, receiveValue: { track in
                DispatchQueue.main.async {
                    self.currentTrack = TrackInfo(name: track.name, artist: track.artists[0].name, previewUrl: track.previewUrl, coverUrl: track.coverUrl, score: 0, URI: track.uri)
                }
            })
            .store(in: &cancellables)
    }

    func playTrackPreview() {
        guard let currentTrack = currentTrack, let previewUrl = currentTrack.previewUrl else { return }
        
        audioPlayer?.pause() // Pause the current playback if any
        
        let playerItem = AVPlayerItem(url: previewUrl)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.play()
    }
}


class SpotifyAPI {
    private let clientId: String
    private let clientSecret: String

    init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    func searchTrack(query: String, accessToken: String) -> AnyPublisher<Track, Error> {
        let formattedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.spotify.com/v1/search?q=\(formattedQuery)&type=track&limit=1")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                return output.data
            }
            .decode(type: SearchResult.self, decoder: JSONDecoder())
            .tryMap { result -> Track in
                guard let track = result.tracks.items.first else {
                    throw URLError(.badServerResponse)
                }
                return track
            }
            .eraseToAnyPublisher()
    }
    
    func searchTracks(query: String, accessToken: String) -> AnyPublisher<[Track], Error> {
        let formattedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(formattedQuery)&type=track&limit=12") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                return output.data
            }
            .decode(type: SearchResult.self, decoder: JSONDecoder())
            .map { $0.tracks.items }
            .eraseToAnyPublisher()
    }


    
    func requestAccessToken(authorizationCode: String) -> AnyPublisher<String, Error> {
        let redirectUri = "https://advancebrokerage.net/" // Custom redirect URI
        let body = "grant_type=authorization_code&code=\(authorizationCode)&redirect_uri=\(redirectUri)"
        let postData = body.data(using: .utf8)

        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = postData
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let base64Credentials = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                let response = try JSONDecoder().decode(TokenResponse.self, from: output.data)
                return response.accessToken
            }
            .eraseToAnyPublisher()
    }

    func fetchTrack(trackId: String, accessToken: String) -> AnyPublisher<Track, Error> {
        let url = URL(string: "https://api.spotify.com/v1/tracks/\(trackId)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                return output.data
            }
            .decode(type: Track.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct SearchResult: Decodable {
    let tracks: Tracks

    struct Tracks: Decodable {
        let items: [Track]
    }
}


struct Track: Decodable {
    let name: String
    let previewUrl: URL?
    let coverUrl: URL?
    let artists: [Artist] // Add artists property
    let uri: String // Add URI property

    enum CodingKeys: String, CodingKey {
        case name
        case previewUrl = "preview_url"
        case album
        case artists
        case uri
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        previewUrl = try container.decodeIfPresent(URL.self, forKey: .previewUrl)

        // Decode album to extract cover URL
        let albumContainer = try container.nestedContainer(keyedBy: AlbumCodingKeys.self, forKey: .album)
        let images = try albumContainer.decode([Image].self, forKey: .images)
        coverUrl = images.first?.url

        // Decode artists
        artists = try container.decode([Artist].self, forKey: .artists)

        // Decode URI
        uri = try container.decode(String.self, forKey: .uri)
    }

    struct Image: Decodable {
        let url: URL
    }

    struct Artist: Decodable {
        let name: String
    }

    enum AlbumCodingKeys: String, CodingKey {
        case images
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: HomeViewModel
    @State private var isAuthorizationWebViewPresented = false
    @FocusState private var isKeyboardFocused: Bool
    @State private var isLoading = true
    @State private var authorized = false
    @EnvironmentObject var authManager: AuthManager
    @State var submissionCompleted: Bool = false
    @State var submitting: Bool = false
    @State var dailyTheme: String = ""
    @State private var isPlayingPreview = false
    
    var body: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .onAppear() {
                    print("here")
                    let token = UserDefaults.standard.string(forKey: "authToken")
                    if token != nil {
                        viewModel.authorizeSpotify { success in
                            DispatchQueue.main.async {
                                if success {
                                    // Authorization succeeded, handle success
                                    print("Authorization successful!")
                                    authorized = true
                                    if let accToken = viewModel.accessToken{
                                        print("accToken is: \(accToken)" )
                                        authManager.accessToken = accToken
                                    }
                                } else {
                                    // Authorization failed, handle failure
                                    print("Authorization failed!")
                                }
                                //while(viewModel.dailyTheme == ""){}
                                isLoading = false
                            }
                        }
                      
                    }
                    else{
                        isLoading = false
                    }
                    
                }
                
        } else {
            VStack {
                // Search bar
                if(authorized){
                    
                    if viewModel.currentTrack != nil || viewModel.searchText == "" {
                        if(viewModel.dailyTheme == ""){
                            ProgressView()
                        }
                        else{
                            LinearGradientText(text: viewModel.dailyTheme)
                                .font(.custom("AvenirNext-DemiBold", size: 50))
                                .fontWeight(.bold)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                        }
                    }
                    TextField("Search Track", text: $viewModel.searchText)
                        .padding(16)
                        .background(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke()
                                .onTapGesture {
                                    isKeyboardFocused = !isKeyboardFocused
                                }
                        )
                        .padding(.horizontal, 24)
                        .focused($isKeyboardFocused)
                        .padding(.vertical, 12)
                        .onTapGesture {
                            // Deselect the current track when the search bar is clicked
                            viewModel.currentTrack = nil
                        }
                        .onChange(of: viewModel.searchText) { newValue in
                            viewModel.currentTrack = nil
                            submissionCompleted = false
                            if newValue != "" {
                                viewModel.searchTracks(query: newValue)
                            }
                        }
                        .overlay(
                            HStack {
                                Spacer()
                                Button(action: {
                                    // Clear the search text when the button is clicked
                                    viewModel.searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 10)
                                }
                                .opacity(viewModel.searchText.isEmpty ? 0 : 1) // Show the button only when there's text in the search bar
                                .padding(.trailing, 20)
                            }
                        )
                }

                
                // Authorization button
                if(!authorized){
                    Spacer()
                    Button("Authorize Spotify") {
                        isAuthorizationWebViewPresented.toggle()
                    }
                    .padding()
                    .sheet(isPresented: $isAuthorizationWebViewPresented) {
                        WebViewWrapper(url: URL(string: "https://accounts.spotify.com/authorize?client_id=2b5e025dbfe94f2ea67d23ec1f934e4e&response_type=code&redirect_uri=https://advancebrokerage.net/&scope=user-read-private")!, callbackURLScheme: "https", onAuthorizationCodeReceived: { code in
                            print("Authorization Code: \(code)")
                            // Handle authorization code
                            viewModel.handleAuthorizationRedirect(code: code)
                            // Close the WebView
                            isAuthorizationWebViewPresented = false
                            authorized = true
                            authManager.accessToken = viewModel.accessToken
                            UserDefaults.standard.set(code, forKey: "authToken")
                        })
                    }
                    Spacer()
                }
                
                
                // Display search results or selected track information
                if viewModel.currentTrack == nil {
                                    // Display search results
                    List(viewModel.searchResults, id: \.name) { trackInfo in
                        SearchResultsRow(trackInfo: trackInfo)
                            .onTapGesture {
                                // Handle track selection
                                viewModel.currentTrack = trackInfo
                            }
                    }
                    .onTapGesture {
                        isKeyboardFocused = false
                    }
                } else {
                    // Display selected track information and preview button
                    if let trackInfo = viewModel.currentTrack {
                        SongView(trackInfo: trackInfo)
                            .padding()
                            .environmentObject(authManager)
                            .environmentObject(viewModel)
                        Spacer()
      
                           
                    }
                }
            }
            .onAppear(){
                if let accessToken = authManager.accessToken{
                    viewModel.accessToken = accessToken
                }
            }
            
            
            
            .onTapGesture {
                isKeyboardFocused = false
            }
        }
    }
    



    
}



struct LinearGradientText: View {
    var text: String
    
    var body: some View {
        let gradient = Gradient(colors: [
            Color.green.opacity(1),
            Color.green.opacity(1),
            Color.green.opacity(1)
        ])
        let textLength = CGFloat(text.count)
        
        return HStack(spacing: 0) {
            ForEach(0..<text.count) { index in
                let char = text[text.index(text.startIndex, offsetBy: index)]
                let percentage = CGFloat(index) / textLength
                Text(String(char))
                    .foregroundColor(.clear)
                    .background(
                        LinearGradient(
                            gradient: gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Text(String(char))
                                .font(.custom("AvenirNext-DemiBold", size: 50))
                                .opacity(percentage + 0.4) // Adjust opacity based on position
                        )
                    )
                    .padding(0.5)
            }
        }
    }
}



struct SearchResultsRow: View {
    let trackInfo: TrackInfo

    var body: some View {
        HStack {
            if let coverUrl = trackInfo.coverUrl {
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
                Text(trackInfo.name)
                    .font(.headline)
                Text(trackInfo.artist)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SongView: View {
    let trackInfo: TrackInfo
    @State private var isPlayingPreview = false
    @State private var submissionCompleted: Bool = false
    @State private var submitting: Bool = false
    @State private var alreadySubmitted: Bool = false // Track whether the song has already been submitted
    @EnvironmentObject var viewModel: HomeViewModel
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let coverUrl = trackInfo.coverUrl {
                    AsyncImage(url: coverUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(trackInfo.name)
                        .font(.headline)
                    Text(trackInfo.artist)
                        .font(.subheadline)
                }
                Spacer()
            }
            
            HStack(spacing: 20) {
                if trackInfo.previewUrl != nil {
                    Button(action: {
                        if isPlayingPreview {
                            // Pause preview if already playing
                            viewModel.audioPlayer?.pause()
                        } else {
                            // Play preview if not playing
                            viewModel.playTrackPreview()
                        }
                        isPlayingPreview.toggle()
                    }) {
                        Image(systemName: isPlayingPreview ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 2)
                }
                
                Button(action: {
                    if submitting {
                        return
                    }
                    submitting = true
                    // Submit song
                    submitSong(trackInfo: trackInfo)
                }) {
                    Text(submissionCompleted ? "Submitted!" : alreadySubmitted ? "Already Submitted" : "Submit Song")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(alreadySubmitted ? Color.red : submissionCompleted ? Color.green : Color.blue)
                                .shadow(color: Color.gray.opacity(0.5), radius: 10, x: 0, y: 5)
                        )
                }
                .disabled(submissionCompleted || alreadySubmitted) // Disable button if submission completed or already submitted
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .shadow(color: Color.gray.opacity(0.4), radius: 5, x: 0, y: 2)
    }
    
    func submitSong(trackInfo: TrackInfo) {
        guard let userId = authManager.userID else {
            print("User ID not available")
            return
        }
        
        guard let user = authManager.user else {
            print("User not available")
            return
        }
        
        let db = Firestore.firestore()
        let dailySubmissionsRef = db.collection("dailySubmissions")
        
        // Check if any document in dailySubmissions collection has the same URI as the song being submitted
        dailySubmissionsRef.whereField("uri", isEqualTo: trackInfo.URI).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching submissions: \(error.localizedDescription)")
                return
            }
            
            if let documents = snapshot?.documents, !documents.isEmpty {
                // A submission with the same URI exists, indicating the song has already been submitted
                print("Song already submitted by someone else.")
                // You can handle this case by showing an alert to the user or updating UI accordingly
                alreadySubmitted = true
                submitting = false
                return
            }
            
            // No submission with the same URI found, proceed with submitting the song
            let firebaseTrackInfo = FirebaseTrackInfo(name: trackInfo.name,
                                                      artist: trackInfo.artist,
                                                      previewUrl: trackInfo.previewUrl?.absoluteString ?? "",
                                                      coverUrl: trackInfo.coverUrl?.absoluteString ?? "")
            do {
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(firebaseTrackInfo)
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    print("Error converting JSON data to string")
                    return
                }
                
                // Reference to your Firebase database
                let db = Firestore.firestore()
                
                // Reference to the user's document
                let userRef = db.collection("users").document(userId)
                
                // Reference to the dailySubmissions collection
                let dailySubmissionsRef = db.collection("dailySubmissions")
                
                // Add a new document to dailySubmissions collection
                let newSubmissionDocument = dailySubmissionsRef.document()
                
                // Data to be set in the new submission document
                let submissionData: [String: Any] = [
                    "submission": jsonString,
                    "score": 0,
                    "timestamp": FieldValue.serverTimestamp(),
                    "userPosted": userId,
                    "username" : user.username,
                    "uri" : trackInfo.URI
                ]
                
                // Set the data in the new submission document
                newSubmissionDocument.setData(submissionData) { error in
                    if let error = error {
                        print("Error adding submission document: \(error.localizedDescription)")
                        return
                    }
                    
                    print("New submission created with ID: \(newSubmissionDocument.documentID)")
                    
                    // Update the user's document with a reference to the new submission document
                    userRef.updateData([
                        "submittedTracks": FieldValue.arrayUnion([newSubmissionDocument.documentID])
                    ]) { error in
                        if let error = error {
                            print("Error updating submittedTracks for current user: \(error.localizedDescription)")
                        } else {
                            print("Submission ID added to current user's submittedTracks")
                        }
                    }
                    
                    // Now you can dismiss the view or perform any other actions
                    submissionCompleted = true
                    submitting = false
                    print("Submission process completed successfully")
                }
            } catch {
                print("Error encoding track info: \(error)")
            }
        }
    }
}
