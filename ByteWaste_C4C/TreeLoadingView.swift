//
//  TreeLoadingView.swift
//  ByteWaste_C4C
//
//  Loading screen with tree animation
//

import SwiftUI

struct TreeLoadingView: View {
    @State private var shouldAnimate = false

    var body: some View {
        ZStack {
            // Cream background
            Color.appCream.ignoresSafeArea()

            // Tree animation (no background image)
            TreeViewRepresentable(
                growth: 1.0,  // Max growth (level 10)
                animate: shouldAnimate
            )
            .frame(maxWidth: .infinity, maxHeight: 500)
        }
        .onAppear {
            // Delay animation start slightly for smooth appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldAnimate = true
            }
        }
        .accessibilityLabel("Loading, please wait")
    }
}

#Preview {
    TreeLoadingView()
}
