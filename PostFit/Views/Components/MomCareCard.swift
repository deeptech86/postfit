//
//  MomCareCard.swift
//  PostFit (MomCare)
//
//  Reusable card components for the MomCare design system
//  Soft, rounded cards with gentle shadows for a nurturing feel
//

import SwiftUI

// MARK: - Basic Card
struct MomCareCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.momCareCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
    }
}

// MARK: - Feature Card (for dashboard)
struct MomCareFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let value: String?
    let unit: String?
    let action: () -> Void

    @State private var isPressed = false

    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color = .momCarePrimary,
        value: String? = nil,
        unit: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.value = value
        self.unit = unit
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Icon container
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(iconColor)
                    }

                    Spacer()

                    // Chevron for navigation hint
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.momCareTextTertiary)
                }

                // Value display (if provided)
                if let value = value {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.momCareNumberMedium)
                            .foregroundColor(.momCareTextPrimary)

                        if let unit = unit {
                            Text(unit)
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)

                    Text(subtitle)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.momCareCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Double tap to view details")
    }
}

// MARK: - Stats Card (compact)
struct MomCareStatsCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: Trend?

    enum Trend {
        case up(String)
        case down(String)
        case neutral(String)
    }

    init(
        title: String,
        value: String,
        unit: String,
        icon: String,
        color: Color = .momCarePrimary,
        trend: Trend? = nil
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.color = color
        self.trend = trend
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)

                Text(title)
                    .font(.momCareCaptionBold)
                    .foregroundColor(.momCareTextSecondary)

                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.momCareNumberSmall)
                    .foregroundColor(.momCareTextPrimary)

                Text(unit)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            if let trend = trend {
                HStack(spacing: 4) {
                    switch trend {
                    case .up(let text):
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.momCareSuccess)
                        Text(text)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareSuccess)
                    case .down(let text):
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.momCareError)
                        Text(text)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareError)
                    case .neutral(let text):
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.momCareTextTertiary)
                        Text(text)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.momCareCardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

// MARK: - Gradient Feature Card
struct MomCareGradientCard<Content: View>: View {
    let gradient: LinearGradient
    let content: Content

    init(
        gradient: LinearGradient = Color.momCarePrimaryGradient,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(gradient)
                    .shadow(color: Color.momCarePrimary.opacity(0.2), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Quick Action Card
struct MomCareQuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.momCareCaptionBold)
                    .foregroundColor(.momCareTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 90)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.momCareCardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
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

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MomCareCard {
                VStack(alignment: .leading) {
                    Text("Basic Card")
                        .font(.momCareHeading2)
                    Text("This is a basic card component with soft shadow")
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextSecondary)
                }
            }

            MomCareFeatureCard(
                title: "Today's Hydration",
                subtitle: "Tap to log water intake",
                icon: "drop.fill",
                iconColor: .momCareHydration,
                value: "6",
                unit: "/ 8 glasses"
            ) {
                print("Hydration tapped")
            }

            HStack(spacing: 12) {
                MomCareStatsCard(
                    title: "Calories",
                    value: "1,842",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .momCareNutrition,
                    trend: .up("+5%")
                )

                MomCareStatsCard(
                    title: "Steps",
                    value: "4,521",
                    unit: "steps",
                    icon: "figure.walk",
                    color: .momCareExercise,
                    trend: .down("-200")
                )
            }

            MomCareGradientCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back!")
                        .font(.momCareHeading2)
                        .foregroundColor(.momCareTextPrimary)
                    Text("You're making great progress on your wellness journey.")
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextSecondary)
                }
            }

            HStack(spacing: 12) {
                MomCareQuickActionCard(
                    title: "Log Meal",
                    icon: "camera.fill",
                    color: .momCareNutrition
                ) {}

                MomCareQuickActionCard(
                    title: "Add Water",
                    icon: "drop.fill",
                    color: .momCareHydration
                ) {}

                MomCareQuickActionCard(
                    title: "Exercise",
                    icon: "figure.run",
                    color: .momCareExercise
                ) {}
            }
        }
        .padding()
    }
    .background(Color.momCareBackground)
}
