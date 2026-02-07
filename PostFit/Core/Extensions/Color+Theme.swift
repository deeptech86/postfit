//
//  Color+Theme.swift
//  PostFit (MomCare)
//
//  Design System: Calm and nurturing color palette for postpartum wellness
//  Following the design philosophy of soft colors, rounded corners, and gentle animations
//

import SwiftUI

// MARK: - MomCare Color Palette
extension Color {

    // MARK: - Primary Colors
    /// Primary brand color - soft rose pink for nurturing feel
    static let momCarePrimary = Color(hex: "E8A5B8")

    /// Secondary brand color - calming sage green
    static let momCareSecondary = Color(hex: "A8C5A8")

    /// Accent color - warm peach for highlights
    static let momCareAccent = Color(hex: "F5C9A6")

    // MARK: - Background Colors
    /// Main background - warm off-white
    static let momCareBackground = Color(hex: "FDF8F5")

    /// Card background - pure white
    static let momCareCardBackground = Color(hex: "FFFFFF")

    /// Secondary background - subtle lavender tint
    static let momCareSecondaryBackground = Color(hex: "F5F0F8")

    // MARK: - Text Colors
    /// Primary text - soft charcoal (not harsh black)
    static let momCareTextPrimary = Color(hex: "2D2D2D")

    /// Secondary text - muted gray
    static let momCareTextSecondary = Color(hex: "6B6B6B")

    /// Tertiary text - light gray for hints
    static let momCareTextTertiary = Color(hex: "9B9B9B")

    // MARK: - Semantic Colors
    /// Success - soft green for achievements
    static let momCareSuccess = Color(hex: "7CB87C")

    /// Warning - gentle amber for alerts
    static let momCareWarning = Color(hex: "E5B85C")

    /// Error - muted coral for errors (not aggressive red)
    static let momCareError = Color(hex: "D98E8E")

    /// Info - calm blue for information
    static let momCareInfo = Color(hex: "7BA3C9")

    // MARK: - Feature-Specific Colors
    /// Hydration - refreshing blue
    static let momCareHydration = Color(hex: "87CEEB")

    /// Exercise - energizing coral
    static let momCareExercise = Color(hex: "F4A5A5")

    /// Nutrition - healthy green
    static let momCareNutrition = Color(hex: "98D8AA")

    /// Sleep - calming purple
    static let momCareSleep = Color(hex: "B4A7D6")

    /// Mental health - soothing teal
    static let momCareMentalHealth = Color(hex: "8ECAE6")

    /// Baby care - soft yellow
    static let momCareBabyCare = Color(hex: "FFE5A0")

    // MARK: - Gradient Backgrounds
    /// Primary gradient for headers and hero sections
    static let momCarePrimaryGradient = LinearGradient(
        colors: [Color(hex: "FFDEE2"), Color(hex: "F5C9A6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Secondary gradient for cards
    static let momCareSecondaryGradient = LinearGradient(
        colors: [Color(hex: "E8F4EA"), Color(hex: "D4E8D4")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Calm gradient for relaxation features
    static let momCareCalmGradient = LinearGradient(
        colors: [Color(hex: "E8E0F0"), Color(hex: "D0E8F0")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Hex Color Initializer
extension Color {
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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
