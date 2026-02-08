//
//  ByteWaste_C4CApp.swift
//  ByteWaste_C4C
//
//  Created by Matthew Segura on 2/7/26.
//

import SwiftUI

@main
struct ByteWaste_C4CApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environmentObject(authViewModel)
                } else {
                    LoginView(authViewModel: authViewModel)
                }
            }
        }
    }
}
