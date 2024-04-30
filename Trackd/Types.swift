//
//  Types.swift
//  TenaCity
//
//

import Foundation

// User
struct User {
    let id: String
    let email: String
    let password: String
    let username: String
    let accountCreationDate: Date
    var userInvitedIDs: [String]
    var friendIDs: [String] // user ids
}



// User Extension
extension User {
    var dictionary: [String: Any] {
        return [
            "id": id,
            "email": email,
            "password": password,
            "username": username,
            "accountCreationDate": accountCreationDate,
            "userInvitedIDs": userInvitedIDs,
            "friendIDs": friendIDs
        ]
    }
}

struct TrackInfo {
    let name: String
    let artist: String
    let previewUrl: URL?
    let coverUrl: URL?
    var score: Int // Added score property
}

// Struct for decoding Firebase data
struct FirebaseTrackInfo: Codable {
    let name: String
    let artist: String
    let previewUrl: String?
    let coverUrl: String?
}
