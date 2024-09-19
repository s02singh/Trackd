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



struct ArtistInfo {
    let name: String
    let imageUrl: URL
    var image: UIImage?
    var isLoading: Bool = true
    var id = "holder"
}


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
    @Published var topArtists: [ArtistInfo] = []
    @Published var topSongs: [TrackInfo] = []
    @Published var artistsLoaded: Bool = false
    
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

    func fetchTopArtistsAndSongs() {
        print("fetching try")
        guard let accessToken = accessToken else {
            print("accessToken not found")
            return
        }
        
        print("token found")
        spotifyAPI.getTopArtists(limit: 4, accessToken: accessToken) { artists in
            DispatchQueue.main.async {
                self.topArtists = artists
                self.artistsLoaded = true
            }
        }
        
        
        // spotifyAPI.getTopSongs(limit: 5) { songs in
        //    DispatchQueue.main.async {
        // self.topSongs = songs
        //   }
        //  }
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
        let authorizationURL = "https://accounts.spotify.com/authorize?client_id=2b5e025dbfe94f2ea67d23ec1f934e4e&response_type=code&redirect_uri=https://mlt-sahilsingh15.replit.app/&scope=user-read-private%20user-top-read"
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
                self.fetchTopArtistsAndSongs()
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
        print("searching")
        guard let accessToken = accessToken else {
            print("Access token is missing")
            return
        }
        print("token found")

        spotifyAPI.searchTracks(query: query, accessToken: accessToken)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("Error searching tracks: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("Data corrupted: \(context)")
                            if let underlyingError = context.underlyingError {
                                print("Underlying error: \(underlyingError)")
                            }
                        default:
                            break
                        }
                    }
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
    
    func getTopArtists(limit: Int, accessToken: String, completion: @escaping ([ArtistInfo]) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/me/top/artists?time_range=short_term&limit=\(limit)")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching top artists: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let artists = json?["items"] as? [[String: Any]] ?? []
                
                var topArtists: [ArtistInfo] = artists.compactMap { artist in
                    guard let name = artist["name"] as? String,
                          let images = artist["images"] as? [[String: Any]],
                          let imageUrlString = images.first?["url"] as? String,
                          let imageUrl = URL(string: imageUrlString),
                          let spotifyId = artist["id"] as? String // Ensure spotifyId is a string
                    else {
                        return nil
                    }
                    
                    // Assign the spotifyId to the id property of ArtistInfo
                    return ArtistInfo(name: name, imageUrl: imageUrl, id: spotifyId)
                }

                
                DispatchQueue.global().async {
                    for i in 0..<topArtists.count {
                        if let imageData = try? Data(contentsOf: topArtists[i].imageUrl),
                           let image = UIImage(data: imageData) {
                            topArtists[i].image = image
                            topArtists[i].isLoading = false
                        } else {
                            topArtists[i].isLoading = false
                        }
                        DispatchQueue.main.async {
                            completion(topArtists)
                        }
                    }
                }
            } catch {
                print("Error parsing top artists response: \(error.localizedDescription)")
                completion([])
            }
        }
        
        task.resume()
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
        let redirectUri = "https://mlt-sahilsingh15.replit.app/" // Custom redirect URI
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
    @State private var selectedArtist: Int? = nil
    @Namespace var animation
    @State var showTopArtists: Bool = false
    
    
    
    
    
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
                                    viewModel.fetchTopArtistsAndSongs()
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
                        WebViewWrapper(url: URL(string: "https://accounts.spotify.com/authorize?client_id=2b5e025dbfe94f2ea67d23ec1f934e4e&response_type=code&redirect_uri=https://mlt-sahilsingh15.replit.app/&scope=user-read-private%20user-top-read")!, callbackURLScheme: "https", onAuthorizationCodeReceived: { code in
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
                if (!viewModel.searchText.isEmpty){
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
                if(viewModel.artistsLoaded && viewModel.searchText.isEmpty && viewModel.currentTrack == nil){
                    VStack {
                        Text("My Top Artists")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(
                                LinearGradient(gradient: Gradient(colors: [.blue, .purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .padding(.bottom, 5)
                        Text("(last 4 weeks)")
                            .font(.body)
                            .bold()
                            .foregroundStyle(
                                LinearGradient(gradient: Gradient(colors: [.blue, .purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        ScrollViewReader{ proxy in
                            ScrollView {
                                VStack(spacing: 20) {
                                    
                                    ForEach(viewModel.topArtists.indices, id: \.self) { index in
                                        let artist = viewModel.topArtists[index]
                                        
                                        ZStack {
                                            if selectedArtist == index {
                                                detailedArtistCard(artist: artist)
                                                    .matchedGeometryEffect(id: index, in: animation)
                                                    .onTapGesture {
                                                        withAnimation(.spring()) {
                                                            selectedArtist = nil
                                                        }
                                                    }
                                            } else {
                                                basicArtistCard(artist: artist)
                                                    .matchedGeometryEffect(id: index, in: animation)
                                                    .onTapGesture {
                                                        withAnimation {
                                                            proxy.scrollTo(index, anchor: .center) // Auto-focus on card
                                                            
                                                        }
                                                        withAnimation(.spring()) {
                                                            
                                                            selectedArtist = index
                                                        }
                                                        
                                                    }
                                            }
                                        }
                                        .frame(height: selectedArtist == index ? 400 : 100)
                                        .animation(.easeInOut(duration: 0.5), value: selectedArtist)
                                        .transition(.slide)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    .opacity(showTopArtists ? 1 : 0)  // initially hidden
                    .onAppear {
                        showTopArtists = true  // slide in with animation
                    }
                    .animation(.easeInOut(duration: 1.0), value: showTopArtists)
                    //.animation(.easeInOut(duration: 0.5), value: selectedArtist)
                    .padding()
                    /*
                     // Top 5 Songs Card
                     VStack(alignment: .leading) {
                     Text("Top 5 Songs")
                     .font(.headline)
                     .padding(.bottom, 5)
                     
                     ForEach(viewModel.topSongs.indices, id: \.self) { index in
                     HStack {
                     Image(uiImage: viewModel.topSongs[index].albumImage)
                     .resizable()
                     .frame(width: 50, height: 50)
                     .clipShape(Circle())
                     VStack(alignment: .leading) {
                     Text("\(index + 1). \(viewModel.topSongs[index].name)")
                     .font(.subheadline)
                     Text(viewModel.topSongs[index].artist)
                     .font(.footnote)
                     .foregroundColor(.secondary)
                     }
                     Spacer()
                     }
                     .padding(.vertical, 5)
                     }
                     }
                     .padding()
                     .background(Color(.secondarySystemBackground))
                     .cornerRadius(10)
                     */
                }
                Spacer()
            }
            .onChange(of: viewModel.accessToken){ newValue in
                viewModel.fetchTopArtistsAndSongs()
            }
            .onAppear(){
                if let accessToken = authManager.accessToken{
                    print("first")
                    print(accessToken)
                    viewModel.accessToken = accessToken
                }
            }
            
            
            
            .onTapGesture {
                isKeyboardFocused = false
            }
        }
     
    }
    
    func basicArtistCard(artist: ArtistInfo) -> some View {
           HStack {
               Image(uiImage: artist.image ?? UIImage(named: "TrackdLogo")!)
                   .resizable()
                   .frame(width: 60, height: 60)
                   .clipShape(Circle())
                   .shadow(radius: 5)
               
               VStack(alignment: .leading, spacing: 5) {
                   Text(artist.name)
                       .font(.title2)
                       .bold()
                       .foregroundStyle(
                           LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing)
                       )
                   
                   if artist.isLoading {
                       ProgressView()
                   }
               }
               Spacer()
           }
           .padding()
           .background(
               RoundedRectangle(cornerRadius: 15)
                   .fill(Color(.secondarySystemBackground))
                   .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
           )
       }
       
    func openSpotifyArtist(artistId: String) {
        let spotifyURLString = "spotify://artist/\(artistId)"
        if let spotifyURL = URL(string: spotifyURLString) {
            if UIApplication.shared.canOpenURL(spotifyURL) {
                UIApplication.shared.open(spotifyURL, options: [:], completionHandler: nil)
            } else {
                // Fallback: open Spotify artist page in Safari if app isn't installed
                let webURLString = "https://open.spotify.com/artist/\(artistId)"
                if let webURL = URL(string: webURLString) {
                    UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                }
            }
        }
    }
    
       func detailedArtistCard(artist: ArtistInfo) -> some View {
           VStack(spacing: 10) {
               Image(uiImage: artist.image ?? UIImage(named: "placeholder")!)
                   .resizable()
                   .scaledToFit()
                   .frame(width: 150, height: 150)
                   .clipShape(Circle())
                   .shadow(radius: 10)

               Text(artist.name)
                   .font(.largeTitle)
                   .bold()
                   .foregroundStyle(
                       LinearGradient(gradient: Gradient(colors: [.blue, .purple, .pink]), startPoint: .leading, endPoint: .trailing)
                   )

               if artist.isLoading {
                   ProgressView()
               }

               Spacer()

               Button(action: {
                   openSpotifyArtist(artistId: artist.id)
               }) {
                   Text("Open on Spotify")
                       .font(.headline)
                       .foregroundColor(.white)
                       .padding()
                       .background(
                           Capsule()
                               .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                       )
                       .shadow(radius: 10)
               }
           }
           .padding()
           .background(
               RoundedRectangle(cornerRadius: 20)
                   .fill(Color(.tertiarySystemBackground))
                   .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 10)
           )
       }
   }
    



struct LinearGradientText: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(.custom("AvenirNext-DemiBold", size: 50))
            .fontWeight(.bold)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.5),
                        Color.green.opacity(0.7),
                        Color.green.opacity(0.9)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .lineLimit(1) // Keep the text on one line
            .minimumScaleFactor(0.5) // Allow the text to scale down to 50% if needed
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
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
    @State private var alreadySubmitted: Bool = false
    @State private var rotateDegrees: Double = 0 // For spinning animation
    @State private var timer: Timer? // To control the spinning timer
    @EnvironmentObject var viewModel: HomeViewModel
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 20) {
                HStack {
                    AsyncImage(url: trackInfo.coverUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(rotateDegrees)) // Apply rotation effect
                                .animation(
                                    Animation.linear(duration: 10)
                                        .repeatForever(autoreverses: false),
                                    value: rotateDegrees // Trigger animation when rotateDegrees changes
                                )
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        @unknown default:
                            EmptyView()
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(trackInfo.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(trackInfo.artist)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack(spacing: 30) {
                    if trackInfo.previewUrl != nil {
                        Button(action: {
                            if isPlayingPreview {
                                viewModel.audioPlayer?.pause()
                            } else {
                                viewModel.playTrackPreview()
                            }
                            isPlayingPreview.toggle()
                        }) {
                            Image(systemName: isPlayingPreview ? "pause.circle.fill" : "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        if submitting {
                            return
                        }
                        submitting = true
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
                            )
                    }
                    .disabled(submissionCompleted || alreadySubmitted)
                }
                .padding(.horizontal)
                
                Button(action: {
                    // Extract the track ID from the full URI
                    let components = trackInfo.URI.split(separator: ":")
                    if components.count > 2, components[1] == "track" {
                        let trackID = String(components[2])
                        let spotifyUri = "spotify:track:\(trackID)"
                        let spotifyWebUrl = "https://open.spotify.com/track/\(trackID)"
                        
                        if let url = URL(string: spotifyUri), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else if let url = URL(string: spotifyWebUrl) {
                            UIApplication.shared.open(url)
                        }
                    }
                }) {
                    HStack {
                        Image("spotifylogo") // Use your Spotify logo image here
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20) // Adjust size as needed
                            .padding(.leading, 10)
                        
                        Text("Listen on Spotify")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.trailing, 10)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue)
                            .shadow(color: Color.gray.opacity(0.4), radius: 10, x: 0, y: 5)
                    )
                }
            }
        }
        .cornerRadius(20)
        .shadow(color: Color.gray.opacity(0.4), radius: 10, x: 0, y: 5)
        .padding()
        .onAppear {
            // Start spinning animation
            startSpinning()
        }
        .onDisappear {
            // Stop spinning animation when view disappears
            timer?.invalidate()
        }
    }
    
    func startSpinning() {
        // Set up a timer to update the rotation degrees every 0.1 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                rotateDegrees += 5
            }
        }
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
        
        // Create a date string for today's date (e.g., "2024-09-18")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayDate = dateFormatter.string(from: Date())
        
        // Reference to the dailySubmissions collection under today's date folder
        let dailySubmissionsRef = db.collection("dailySubmissions").document(todayDate).collection("submissions")
        
        // Check if any document in today's submissions has the same URI as the song being submitted
        dailySubmissionsRef.whereField("uri", isEqualTo: trackInfo.URI).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching submissions: \(error.localizedDescription)")
                return
            }
            
            if let documents = snapshot?.documents, !documents.isEmpty {
                // A submission with the same URI exists, indicating the song has already been submitted
                print("Song already submitted by someone else.")
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
                
                // Add a new document to today's submissions collection
                let newSubmissionDocument = dailySubmissionsRef.document()
                
                // Data to be set in the new submission document
                let submissionData: [String: Any] = [
                    "submission": jsonString,
                    "score": 1,
                    "timestamp": FieldValue.serverTimestamp(),
                    "userPosted": userId,
                    "username": user.username,
                    "uri": trackInfo.URI
                ]
                
                // Set the data in the new submission document
                newSubmissionDocument.setData(submissionData) { error in
                    if let error = error {
                        print("Error adding submission document: \(error.localizedDescription)")
                        return
                    }
                    
                    print("New submission created with ID: \(newSubmissionDocument.documentID)")
                    
                    // Update the user's document with a reference to the new submission document
                    let userRef = db.collection("users").document(userId)
                    userRef.updateData([
                        "submittedTracks": FieldValue.arrayUnion([newSubmissionDocument.documentID])
                    ]) { error in
                        if let error = error {
                            print("Error updating submittedTracks for current user: \(error.localizedDescription)")
                        } else {
                            print("Submission ID added to current user's submittedTracks")
                        }
                    }
                    
                    // Mark submission as completed
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





