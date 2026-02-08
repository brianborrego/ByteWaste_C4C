//
//  LoginView.swift
//  ByteWaste_C4C
//
//  Authentication entry screen
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            // Cream background
            Color.appCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo/Title
                    VStack(spacing: 8) {
                        Text("UPantry")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        Text("Reduce food waste, one scan at a time")
                            .font(.subheadline)
                            .foregroundColor(.appIconGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Apple Sign-In Button
                    VStack(spacing: 16) {
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = sha256(nonce)
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.appIconGray.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.subheadline)
                            .foregroundColor(.appIconGray)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.appIconGray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)

                    // Email/Password Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.appIconGray)
                                .padding(.horizontal, 16)

                            TextField("", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .foregroundColor(.black)
                                .padding()
                                .cardStyle()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.appIconGray)
                                .padding(.horizontal, 16)

                            SecureField("", text: $password)
                                .padding()
                                .foregroundColor(.black)
                                .cardStyle()
                        }

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Sign In/Up Button
                        Button {
                            Task {
                                if isSignUp {
                                    await authViewModel.signUp(email: email, password: password)
                                } else {
                                    await authViewModel.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(Color.appPrimaryGreen)
                        .cornerRadius(12)
                        .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                        // Toggle Sign In/Up
                        Button {
                            isSignUp.toggle()
                            authViewModel.errorMessage = nil
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                                .foregroundColor(.appPrimaryGreen)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $authViewModel.isLoading) {
            TreeLoadingView()
        }
    }

    // MARK: - Apple Sign-In Handler

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authViewModel.errorMessage = "Failed to get Apple ID credential"
                print("❌ Could not cast to ASAuthorizationAppleIDCredential")
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken else {
                authViewModel.errorMessage = "Failed to get identity token"
                print("❌ Identity token is nil")
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                authViewModel.errorMessage = "Failed to decode identity token"
                print("❌ Could not decode token data to string")
                return
            }

            guard let nonce = currentNonce else {
                authViewModel.errorMessage = "Invalid nonce"
                print("❌ Current nonce is nil")
                return
            }

            print("✅ Apple Sign-In credential received")
            print("📧 Email: \(appleIDCredential.email ?? "not provided")")
            print("👤 User ID: \(appleIDCredential.user)")

            Task {
                await authViewModel.signInWithApple(
                    idToken: idTokenString,
                    nonce: nonce
                )
            }

        case .failure(let error):
            let nsError = error as NSError
            print("❌ Apple Sign-In error: \(error)")
            print("❌ Error code: \(nsError.code)")
            print("❌ Error domain: \(nsError.domain)")

            // Provide more helpful error messages
            switch nsError.code {
            case 1000:
                authViewModel.errorMessage = "Apple Sign-In configuration error. Check Xcode capabilities and Apple Developer settings."
            case 1001:
                authViewModel.errorMessage = "Sign-In was cancelled"
            case 1004:
                authViewModel.errorMessage = "Sign-In not available. Check device settings."
            default:
                authViewModel.errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}
