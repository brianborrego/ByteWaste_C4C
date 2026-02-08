//
//  AppTheme.swift
//  ByteWaste_C4C
//
//  Centralized styling and theming for the app
//

import SwiftUI

// MARK: - Color Extensions
extension Color {
    // Primary Colors
    static let appPrimaryGreen = Color(hex: AppColors.primaryDarkGreen)
    static let appSecondaryGreen = Color(hex: AppColors.secondaryLightGreen)

    // Backgrounds
    static let appCream = Color(hex: AppColors.creamBackground)
    static let appWhite = Color(hex: AppColors.white)

    // UI Elements
    static let appIconGray = Color(hex: AppColors.iconGray)

    // Gradients
    static let appGradientTop = Color(hex: AppColors.gradientBrownTop)
    static let appGradientBottom = Color(hex: AppColors.gradientBrownBottom)

    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradients
extension LinearGradient {
    static let appTitleGradient = LinearGradient(
        gradient: Gradient(colors: [.appGradientTop, .appGradientBottom]),
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appWhite)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
