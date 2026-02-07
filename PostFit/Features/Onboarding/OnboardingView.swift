//
//  OnboardingView.swift
//  PostFit (MomCare)
//
//  Welcome and onboarding flow for new users
//  Calm, nurturing design with encouraging messaging
//

import SwiftUI

// MARK: - Onboarding Container
struct OnboardingView: View {
    @State private var currentPage = 0
    @Binding var isOnboardingComplete: Bool

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Your Wellness Journey",
            subtitle: "A supportive companion designed specifically for new mothers like you.",
            imageName: "heart.circle.fill",
            imageColor: .momCarePrimary,
            features: []
        ),
        OnboardingPage(
            title: "Nourish Your Body",
            subtitle: "Smart food tracking that understands your unique nutritional needs as a new mom.",
            imageName: "leaf.fill",
            imageColor: .momCareNutrition,
            features: [
                "AI-powered food recognition",
                "Breastfeeding-adjusted calories",
                "Quick 15-minute recipes"
            ]
        ),
        OnboardingPage(
            title: "Move at Your Pace",
            subtitle: "Safe, medically-approved exercises tailored to your recovery stage.",
            imageName: "figure.mind.and.body",
            imageColor: .momCareExercise,
            features: [
                "Postpartum-safe workouts",
                "Pelvic floor exercises",
                "Progressive difficulty"
            ]
        ),
        OnboardingPage(
            title: "Rest & Recharge",
            subtitle: "Track your sleep, hydration, and mental wellness with gentle reminders.",
            imageName: "moon.stars.fill",
            imageColor: .momCareSleep,
            features: [
                "Smart hydration reminders",
                "Sleep quality tracking",
                "Mood check-ins"
            ]
        ),
        OnboardingPage(
            title: "Celebrate Every Step",
            subtitle: "Your journey is unique. We're here to support you every step of the way.",
            imageName: "star.fill",
            imageColor: .momCareAccent,
            features: [
                "Progress visualization",
                "Achievement badges",
                "Supportive community"
            ]
        )
    ]

    var body: some View {
        ZStack {
            // Background
            Color.momCareBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(.momCareButtonSecondary)
                        .foregroundColor(.momCareTextSecondary)
                        .padding()
                    }
                }
                .frame(height: 44)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicators and button
                VStack(spacing: 24) {
                    // Custom page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.momCarePrimary : Color.momCarePrimary.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.top, 16)

                    // Continue/Get Started button
                    if currentPage == pages.count - 1 {
                        MomCarePrimaryButton("Get Started", icon: "arrow.right") {
                            isOnboardingComplete = true
                        }
                        .padding(.horizontal, 32)
                    } else {
                        MomCarePrimaryButton("Continue") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let imageColor: Color
    let features: [String]
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
            ZStack {
                // Background circles for depth
                Circle()
                    .fill(page.imageColor.opacity(0.1))
                    .frame(width: 220, height: 220)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)

                Circle()
                    .fill(page.imageColor.opacity(0.15))
                    .frame(width: 180, height: 180)

                // Main icon
                Image(systemName: page.imageName)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(page.imageColor)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }
            .animation(
                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }

            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.momCareDisplayMedium)
                    .foregroundColor(.momCareTextPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            // Features list
            if !page.features.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(page.features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(page.imageColor)

                            Text(feature)
                                .font(.momCareBody)
                                .foregroundColor(.momCareTextPrimary)
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.subtitle)")
    }
}

// MARK: - Welcome Screen (First Launch)
struct WelcomeView: View {
    @State private var showOnboarding = false
    @State private var animateHeart = false

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "FDF8F5"),
                    Color(hex: "FFDEE2").opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and app name
                VStack(spacing: 20) {
                    // Animated heart logo
                    ZStack {
                        Circle()
                            .fill(Color.momCarePrimary.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .scaleEffect(animateHeart ? 1.1 : 1.0)

                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.momCarePrimary)
                            .scaleEffect(animateHeart ? 1.05 : 1.0)
                    }
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: animateHeart
                    )
                    .onAppear {
                        animateHeart = true
                    }

                    Text("MomCare")
                        .font(.momCareDisplayLarge)
                        .foregroundColor(.momCareTextPrimary)

                    Text("Your Postpartum Wellness Companion")
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextSecondary)
                }

                Spacer()

                // Value proposition
                VStack(spacing: 16) {
                    WelcomeFeatureRow(
                        icon: "camera.fill",
                        title: "Smart Food Tracking",
                        color: .momCareNutrition
                    )

                    WelcomeFeatureRow(
                        icon: "figure.mind.and.body",
                        title: "Safe Exercises",
                        color: .momCareExercise
                    )

                    WelcomeFeatureRow(
                        icon: "drop.fill",
                        title: "Hydration Reminders",
                        color: .momCareHydration
                    )

                    WelcomeFeatureRow(
                        icon: "heart.text.square.fill",
                        title: "Wellness Support",
                        color: .momCareMentalHealth
                    )
                }
                .padding(.horizontal, 48)

                Spacer()

                // CTA Button
                VStack(spacing: 16) {
                    MomCarePrimaryButton("Begin Your Journey", icon: "arrow.right") {
                        showOnboarding = true
                    }

                    Text("Join thousands of moms on their wellness journey")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isOnboardingComplete: .constant(false))
        }
    }
}

struct WelcomeFeatureRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.momCareBody)
                .foregroundColor(.momCareTextPrimary)

            Spacer()
        }
    }
}

// MARK: - Medical Disclaimer View
struct MedicalDisclaimerView: View {
    @Binding var hasAcceptedDisclaimer: Bool

    var body: some View {
        ZStack {
            Color.momCareBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.momCareInfo.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "stethoscope")
                        .font(.system(size: 44))
                        .foregroundColor(.momCareInfo)
                }

                // Title
                Text("Important Health Information")
                    .font(.momCareHeading1)
                    .foregroundColor(.momCareTextPrimary)
                    .multilineTextAlignment(.center)

                // Disclaimer text
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        DisclaimerItem(
                            icon: "exclamationmark.triangle.fill",
                            text: "This app is not a substitute for professional medical advice, diagnosis, or treatment."
                        )

                        DisclaimerItem(
                            icon: "person.fill",
                            text: "Always consult your healthcare provider before starting any weight loss or exercise program, especially postpartum."
                        )

                        DisclaimerItem(
                            icon: "heart.fill",
                            text: "If you are breastfeeding, maintain a minimum of 1,800 calories per day to support milk production."
                        )

                        DisclaimerItem(
                            icon: "clock.fill",
                            text: "Wait at least 6 weeks postpartum before starting exercise, unless cleared earlier by your doctor."
                        )

                        DisclaimerItem(
                            icon: "phone.fill",
                            text: "Report any concerning symptoms (excessive bleeding, severe depression, chest pain) to your healthcare provider immediately."
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxHeight: 320)

                Spacer()

                // Accept button
                VStack(spacing: 12) {
                    MomCarePrimaryButton("I Understand and Agree") {
                        hasAcceptedDisclaimer = true
                    }

                    Text("By continuing, you acknowledge that you have read and understood this disclaimer.")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

struct DisclaimerItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.momCareWarning)
                .frame(width: 24)

            Text(text)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Preview
#Preview("Onboarding") {
    OnboardingView(isOnboardingComplete: .constant(false))
}

#Preview("Welcome") {
    WelcomeView()
}

#Preview("Disclaimer") {
    MedicalDisclaimerView(hasAcceptedDisclaimer: .constant(false))
}
