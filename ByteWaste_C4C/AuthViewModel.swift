//
//  AuthViewModel.swift
//  ByteWaste_C4C
//
//  User authentication and session management
//

import SwiftUI
import Supabase
import Combine

class AuthViewModel: ObservableObject {
    @Published var session: Supabase.Session?
    @Published var isLoading = false
    @Published var isCheckingSession = true
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared.client

    var isAuthenticated: Bool {
        session != nil
    }

    var currentUserId: UUID? {
        session?.user.id
    }

    init() {
        // Check for existing session on init
        Task { @MainActor in
            await checkSession()
        }
    }

    // MARK: - Session Management

    @MainActor
    func checkSession() async {
        let startTime = Date()

        do {
            session = try await supabase.auth.session
            print("✅ Session restored: \(session?.user.email ?? "unknown")")
        } catch {
            print("ℹ️ No existing session")
            session = nil
        }

        // Ensure minimum display time (prevents flash)
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 5.5

        if elapsed < minDuration {
            try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
        }

        isCheckingSession = false
    }

    // MARK: - Email/Password Auth

    @MainActor
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        let startTime = Date()

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            session = response.session
            print("✅ Sign up successful: \(email)")
        } catch {
            errorMessage = "Sign up failed: \(error.localizedDescription)"
            print("❌ Sign up error: \(error)")
        }

        // Ensure minimum loading display
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 5.5
        if elapsed < minDuration {
            try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
        }

        isLoading = false
    }

    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        let startTime = Date()

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            self.session = session
            print("✅ Sign in successful: \(email)")
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("❌ Sign in error: \(error)")
        }

        // Ensure minimum loading display
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 5.5
        if elapsed < minDuration {
            try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
        }

        isLoading = false
    }

    // MARK: - Apple Sign-In

    @MainActor
    func signInWithApple(idToken: String, nonce: String) async {
        isLoading = true
        errorMessage = nil

        let startTime = Date()

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            self.session = session
            print("✅ Apple Sign-In successful")
        } catch {
            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            print("❌ Apple Sign-In error: \(error)")
        }

        // Ensure minimum loading display
        let elapsed = Date().timeIntervalSince(startTime)
        let minDuration = 5.5
        if elapsed < minDuration {
            try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
        }

        isLoading = false
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            session = nil
            print("✅ Sign out successful")
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
            print("❌ Sign out error: \(error)")
        }
    }
}
