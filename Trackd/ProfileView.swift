//
//  ProfileView.swift
//  Trackd
//
//  Created by Sahilbir Singh on 4/7/24.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import Firebase
import SwiftUI
import FirebaseFirestore
import AuthenticationServices


struct ProfileView: View {
    var body: some View {
        VStack{
            Text("This is the Profile View")
            SignOutButton()
        }
        
    }
}

struct SignOutButton: View {
    var body: some View {
        Button(action: {
            let firebaseAuth = Auth.auth()
            do {
              try firebaseAuth.signOut()
              UserDefaults.standard.set(false, forKey: "signIn")
              UserDefaults.standard.set(nil, forKey: "userID")
            } catch let signOutError as NSError {
              print("Error signing out: %@", signOutError)
            }
        }) {
            Text("Sign Out")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
        }
        .padding()
    }
}
