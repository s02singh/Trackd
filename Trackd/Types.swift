//
//  Types.swift
//  TenaCity
//
//

import Foundation
import SwiftUI
// User
struct User {
    let id: String
    let email: String
    let password: String
    var username: String
    let accountCreationDate: Date
    var userInvitedIDs: [String]
    var friendIDs: [String] // user ids
    var profileUrl: String
    var score: Int
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
            "friendIDs": friendIDs,
            "profileUrl": profileUrl,
            "score": score
        ]
    }
}

struct TrackInfo {
    let name: String
    let artist: String
    let previewUrl: URL?
    let coverUrl: URL?
    var score: Int // Added score property
    let URI: String
}

// Struct for decoding Firebase data
struct FirebaseTrackInfo: Codable {
    let name: String
    let artist: String
    let previewUrl: String?
    let coverUrl: String?
}
