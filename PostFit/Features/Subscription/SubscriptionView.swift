//
//  SubscriptionView.swift
//  PostFit (MomCare)
//
//  Subscription paywall view with 7-day free trial
//  Shows premium features and subscription options
//

import SwiftUI
import StoreKit

// MARK: - Subscription View
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedProduct: Product?
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var isEligibleForTrial = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    SubscriptionHeader()

                    // Premium Features
                    PremiumFeaturesSection()

                    // Subscription Options
                    if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                        ProgressView("Loading options...")
                            .padding()
                    } else if subscriptionManager.products.isEmpty {
                        Text("Unable to load subscription options")
                            .foregroundColor(.momCareTextSecondary)
                            .padding()

                        Button("Retry") {
                            Task {
                                await subscriptionManager.loadProducts()
                            }
                        }
                        .foregroundColor(.momCarePrimary)
                    } else {
                        SubscriptionOptionsSection(
                            products: subscriptionManager.products,
                            selectedProduct: $selectedProduct,
                            isEligibleForTrial: isEligibleForTrial
                        )
                    }

                    // Subscribe Button
                    if let product = selectedProduct {
                        SubscribeButton(
                            product: product,
                            isLoading: subscriptionManager.isLoading,
                            isEligibleForTrial: isEligibleForTrial
                        ) {
                            Task {
                                let success = await subscriptionManager.purchase(product)
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    }

                    // Error Message
                    if let error = subscriptionManager.errorMessage {
                        Text(error)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Restore & Legal
                    VStack(spacing: 16) {
                        Button("Restore Purchases") {
                            Task {
                                await subscriptionManager.restorePurchases()
                            }
                        }
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCarePrimary)

                        HStack(spacing: 16) {
                            Button("Terms of Use") {
                                showTerms = true
                            }

                            Text("•")
                                .foregroundColor(.momCareTextTertiary)

                            Button("Privacy Policy") {
                                showPrivacy = true
                            }
                        }
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)

                        // Subscription disclaimer
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                            .font(.system(size: 10))
                            .foregroundColor(.momCareTextTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.momCareTextSecondary)
                }
            }
            .task {
                // Check trial eligibility
                isEligibleForTrial = await subscriptionManager.checkTrialEligibility()

                // Select first product by default
                if selectedProduct == nil, let first = subscriptionManager.products.first {
                    selectedProduct = first
                }
            }
            .sheet(isPresented: $showTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
        }
    }
}

// MARK: - Subscription Header
struct SubscriptionHeader: View {
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.momCarePrimary, .momCareAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Unlock Your Full Potential")
                    .font(.momCareHeading1)
                    .foregroundColor(.momCareTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Get personalized support for your postpartum journey")
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Premium Features Section
struct PremiumFeaturesSection: View {
    let features = [
        ("sparkles", "AI Food Recognition", "Snap a photo and get instant nutrition info"),
        ("fork.knife", "Personalized Meal Plans", "Tailored to your postpartum needs"),
        ("figure.run", "Full Exercise Library", "Safe workouts for every recovery stage"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Track your progress with detailed insights"),
        ("person.fill.questionmark", "Expert Consultations", "Get advice from postpartum specialists")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(features, id: \.1) { icon, title, subtitle in
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.momCarePrimary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.momCareBodyBold)
                            .foregroundColor(.momCareTextPrimary)

                        Text(subtitle)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.momCareSuccess)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.momCareCardBackground)
        )
    }
}

// MARK: - Subscription Options Section
struct SubscriptionOptionsSection: View {
    let products: [Product]
    @Binding var selectedProduct: Product?
    let isEligibleForTrial: Bool

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        VStack(spacing: 12) {
            ForEach(products, id: \.id) { product in
                SubscriptionOptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isEligibleForTrial: isEligibleForTrial,
                    trialInfo: subscriptionManager.trialInfo(for: product),
                    periodInfo: subscriptionManager.subscriptionPeriod(for: product)
                ) {
                    selectedProduct = product
                }
            }
        }
    }
}

// MARK: - Subscription Option Card
struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let isEligibleForTrial: Bool
    let trialInfo: String?
    let periodInfo: String?
    let onSelect: () -> Void

    private var isYearly: Bool {
        product.id.contains("yearly")
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.momCareBodyBold)
                            .foregroundColor(.momCareTextPrimary)

                        if isYearly {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.momCareAccent)
                                )
                        }
                    }

                    if isEligibleForTrial, let trial = trialInfo {
                        Text(trial)
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCareSuccess)
                    }

                    if let period = periodInfo {
                        Text("Then \(product.displayPrice)/\(period)")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextSecondary)
                    }
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.momCarePrimary : Color.momCareTextTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.momCarePrimary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.momCarePrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Subscribe Button
struct SubscribeButton: View {
    let product: Product
    let isLoading: Bool
    let isEligibleForTrial: Bool
    let onSubscribe: () -> Void

    var body: some View {
        Button(action: onSubscribe) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }

                Text(buttonTitle)
                    .font(.momCareButtonPrimary)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.momCarePrimary, .momCarePrimary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .disabled(isLoading)
    }

    private var buttonTitle: String {
        if isEligibleForTrial {
            return "Start Free Trial"
        } else {
            return "Subscribe Now"
        }
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text("""
                Terms of Service

                Last updated: February 2026

                1. Subscription Terms
                By subscribing to PostFit Premium, you agree to these terms...

                2. Free Trial
                New subscribers may be eligible for a 7-day free trial. You will be charged after the trial period unless you cancel at least 24 hours before the trial ends.

                3. Billing
                Payment will be charged to your Apple ID account. Subscriptions automatically renew unless canceled.

                4. Cancellation
                You can cancel your subscription anytime through your App Store account settings.

                [Full terms would go here]
                """)
                .font(.momCareBody)
                .foregroundColor(.momCareTextPrimary)
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text("""
                Privacy Policy

                Last updated: February 2026

                Your privacy is important to us. This policy explains how PostFit collects, uses, and protects your information.

                1. Data Collection
                We collect information you provide directly, such as health data and preferences.

                2. Data Usage
                Your data is used to personalize your experience and provide our services.

                3. Data Protection
                All data is encrypted and stored securely.

                [Full privacy policy would go here]
                """)
                .font(.momCareBody)
                .foregroundColor(.momCareTextPrimary)
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.momCarePrimary)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SubscriptionView()
}
