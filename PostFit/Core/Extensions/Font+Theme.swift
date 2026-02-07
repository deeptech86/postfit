//
//  Font+Theme.swift
//  PostFit (MomCare)
//
//  Typography system for the MomCare app
//  Supports Dynamic Type for accessibility
//

import SwiftUI

// MARK: - MomCare Typography
extension Font {

    // MARK: - Display Fonts (for hero sections)
    /// Large display text for onboarding and hero sections
    static let momCareDisplayLarge = Font.system(size: 34, weight: .bold, design: .rounded)

    /// Medium display text for section headers
    static let momCareDisplayMedium = Font.system(size: 28, weight: .semibold, design: .rounded)

    // MARK: - Heading Fonts
    /// Primary heading (H1)
    static let momCareHeading1 = Font.system(size: 24, weight: .semibold, design: .rounded)

    /// Secondary heading (H2)
    static let momCareHeading2 = Font.system(size: 20, weight: .semibold, design: .rounded)

    /// Tertiary heading (H3)
    static let momCareHeading3 = Font.system(size: 17, weight: .semibold, design: .rounded)

    // MARK: - Body Fonts
    /// Primary body text
    static let momCareBody = Font.system(size: 16, weight: .regular, design: .rounded)

    /// Bold body text for emphasis
    static let momCareBodyBold = Font.system(size: 16, weight: .semibold, design: .rounded)

    /// Secondary body text (smaller)
    static let momCareBodySecondary = Font.system(size: 14, weight: .regular, design: .rounded)

    // MARK: - Caption Fonts
    /// Caption for metadata and timestamps
    static let momCareCaption = Font.system(size: 12, weight: .regular, design: .rounded)

    /// Caption bold for labels
    static let momCareCaptionBold = Font.system(size: 12, weight: .semibold, design: .rounded)

    // MARK: - Button Fonts
    /// Primary button text
    static let momCareButtonPrimary = Font.system(size: 17, weight: .semibold, design: .rounded)

    /// Secondary button text
    static let momCareButtonSecondary = Font.system(size: 15, weight: .medium, design: .rounded)

    // MARK: - Numeric Fonts
    /// Large numbers for stats and metrics
    static let momCareNumberLarge = Font.system(size: 48, weight: .bold, design: .rounded)

    /// Medium numbers for dashboard cards
    static let momCareNumberMedium = Font.system(size: 32, weight: .semibold, design: .rounded)

    /// Small numbers for inline metrics
    static let momCareNumberSmall = Font.system(size: 20, weight: .medium, design: .rounded)
}

// MARK: - Text Styles with Accessibility Support
struct MomCareTextStyle: ViewModifier {
    enum Style {
        case displayLarge
        case displayMedium
        case heading1
        case heading2
        case heading3
        case body
        case bodyBold
        case bodySecondary
        case caption
        case captionBold
        case buttonPrimary
        case buttonSecondary
        case numberLarge
        case numberMedium
        case numberSmall
    }

    let style: Style
    let color: Color

    init(_ style: Style, color: Color = .momCareTextPrimary) {
        self.style = style
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }

    private var font: Font {
        switch style {
        case .displayLarge: return .momCareDisplayLarge
        case .displayMedium: return .momCareDisplayMedium
        case .heading1: return .momCareHeading1
        case .heading2: return .momCareHeading2
        case .heading3: return .momCareHeading3
        case .body: return .momCareBody
        case .bodyBold: return .momCareBodyBold
        case .bodySecondary: return .momCareBodySecondary
        case .caption: return .momCareCaption
        case .captionBold: return .momCareCaptionBold
        case .buttonPrimary: return .momCareButtonPrimary
        case .buttonSecondary: return .momCareButtonSecondary
        case .numberLarge: return .momCareNumberLarge
        case .numberMedium: return .momCareNumberMedium
        case .numberSmall: return .momCareNumberSmall
        }
    }
}

extension View {
    func momCareTextStyle(_ style: MomCareTextStyle.Style, color: Color = .momCareTextPrimary) -> some View {
        modifier(MomCareTextStyle(style, color: color))
    }
}
