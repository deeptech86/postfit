//
//  MomCareButton.swift
//  PostFit (MomCare)
//
//  Reusable button components following the MomCare design system
//  Gentle, encouraging design with smooth animations
//

import SwiftUI

// MARK: - Button Styles
enum MomCareButtonStyle {
    case primary
    case secondary
    case tertiary
    case outline
    case destructive
}

enum MomCareButtonSize {
    case large
    case medium
    case small

    var height: CGFloat {
        switch self {
        case .large: return 56
        case .medium: return 48
        case .small: return 36
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large: return 24
        case .medium: return 20
        case .small: return 16
        }
    }

    var font: Font {
        switch self {
        case .large: return .momCareButtonPrimary
        case .medium: return .momCareButtonSecondary
        case .small: return .momCareCaption
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .large: return 16
        case .medium: return 12
        case .small: return 8
        }
    }
}

// MARK: - Primary Button
struct MomCarePrimaryButton: View {
    let title: String
    let icon: String?
    let size: MomCareButtonSize
    let isLoading: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        size: MomCareButtonSize = .large,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: {
            if !isLoading {
                // Haptic feedback for encouragement
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(size.font)
                    }
                    Text(title)
                        .font(size.font)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(Color.momCarePrimary)
                    .shadow(color: Color.momCarePrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "Double tap to activate")
    }
}

// MARK: - Secondary Button
struct MomCareSecondaryButton: View {
    let title: String
    let icon: String?
    let size: MomCareButtonSize
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        size: MomCareButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                Text(title)
                    .font(size.font)
            }
            .foregroundColor(.momCarePrimary)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(Color.momCarePrimary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(Color.momCarePrimary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
    }
}

// MARK: - Outline Button
struct MomCareOutlineButton: View {
    let title: String
    let icon: String?
    let size: MomCareButtonSize
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        size: MomCareButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                Text(title)
                    .font(size.font)
            }
            .foregroundColor(.momCareTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(Color.momCareTextTertiary.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
    }
}

// MARK: - Icon Button
struct MomCareIconButton: View {
    let icon: String
    let size: CGFloat
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    init(
        icon: String,
        size: CGFloat = 44,
        color: Color = .momCarePrimary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color.opacity(0.1))
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(icon)
    }
}

// MARK: - Apple Sign In Button Style
struct MomCareAppleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))
                Text("Continue with Apple")
                    .font(.momCareButtonPrimary)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
            )
        }
        .accessibilityLabel("Sign in with Apple")
    }
}

// MARK: - Google Sign In Button Style
struct MomCareGoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google "G" logo representation
                Text("G")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.red)
                Text("Continue with Google")
                    .font(.momCareButtonPrimary)
                    .foregroundColor(.momCareTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.momCareTextTertiary.opacity(0.3), lineWidth: 1)
            )
        }
        .accessibilityLabel("Sign in with Google")
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MomCarePrimaryButton("Get Started", icon: "arrow.right") {
            print("Primary tapped")
        }

        MomCarePrimaryButton("Loading...", isLoading: true) {
            print("Loading tapped")
        }

        MomCareSecondaryButton("Learn More", icon: "info.circle") {
            print("Secondary tapped")
        }

        MomCareOutlineButton("Skip for Now") {
            print("Outline tapped")
        }

        HStack(spacing: 16) {
            MomCareIconButton(icon: "heart.fill", color: .momCarePrimary) {
                print("Heart tapped")
            }
            MomCareIconButton(icon: "plus", color: .momCareSecondary) {
                print("Plus tapped")
            }
            MomCareIconButton(icon: "camera.fill", color: .momCareAccent) {
                print("Camera tapped")
            }
        }

        MomCareAppleSignInButton {
            print("Apple sign in")
        }

        MomCareGoogleSignInButton {
            print("Google sign in")
        }
    }
    .padding()
    .background(Color.momCareBackground)
}
