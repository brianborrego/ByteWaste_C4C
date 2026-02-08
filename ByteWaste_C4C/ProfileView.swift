//
//  ProfileView.swift
//  ByteWaste_C4C
//
//  User profile and account management
//

import SwiftUI
import Auth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.appCream.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Profile Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.appPrimaryGreen)

                        Text("Profile")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.appGradientTop, .appGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ))

                        if let email = authViewModel.session?.user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.appIconGray)
                        }
                    }

                    Spacer()

                    // Sign Out Button
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await authViewModel.signOut()
                                dismiss()
                            }
                        } label: {
                            Text("Sign Out")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appIconGray)
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
