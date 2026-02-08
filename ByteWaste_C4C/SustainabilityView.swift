//
//  SustainabilityView.swift
//  ByteWaste_C4C
//
//  Placeholder for sustainability/eco tips
//

import SwiftUI

struct SustainabilityView: View {
    var body: some View {
        ZStack {
            Color.appCream.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.appPrimaryGreen)

                Text("Sustainability")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.linearGradient(
                        colors: [.appGradientTop, .appGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                Text("Coming Soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SustainabilityView()
}
