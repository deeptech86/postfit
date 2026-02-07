//
//  SignInView.swift
//  PostFit (MomCare)
//
//  Sign-in and authentication view
//  Supports Apple Sign-In, Google Sign-In, and email authentication
//

import SwiftUI
import AuthenticationServices

// MARK: - Sign In View
struct SignInView: View {
    @StateObject var viewModel: AuthenticationViewModel
    @State private var animateHeart = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "FDF8F5"),
                    Color(hex: "FFDEE2").opacity(0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Logo and Branding
                VStack(spacing: 24) {
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

                    // App Name
                    Text("MomCare")
                        .font(.momCareDisplayLarge)
                        .foregroundColor(.momCareTextPrimary)

                    // Tagline
                    Text("Your Postpartum Wellness Companion")
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }
                .padding(.top, 60)

                Spacer()
                Spacer()

                // Sign-In Buttons
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            // Set the nonce for security verification
                            request.nonce = viewModel.prepareAppleSignInNonce()
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    // Google Sign In
                    MomCareGoogleSignInButton {
                        handleGoogleSignIn()
                    }
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Terms and Privacy
                VStack(spacing: 12) {
                    Text("By continuing, you agree to our")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)

                    HStack(spacing: 8) {
                        Button(action: {
                            // Open Terms of Service
                            if let url = URL(string: "https://www.momcare.app/terms") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Terms of Service")
                                .font(.momCareCaption)
                                .foregroundColor(.momCarePrimary)
                                .underline()
                        }

                        Text("and")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)

                        Button(action: {
                            // Open Privacy Policy
                            if let url = URL(string: "https://www.momcare.app/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Privacy Policy")
                                .font(.momCareCaption)
                                .foregroundColor(.momCarePrimary)
                                .underline()
                        }
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }

            // Loading overlay
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .alert("Authentication Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: viewModel.authResponse) { _, response in
            handleAuthResponse(response)
        }
    }

    // MARK: - Authentication Handlers

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        // Check if this is a Personal Team / development environment error
        if case .failure(let error) = result {
            let nsError = error as NSError
            // Error 1000 = unknown error, often means capability not available (Personal Team)
            if nsError.domain == "com.apple.AuthenticationServices.AuthorizationError" && nsError.code == 1000 {
                // Use mock authentication for development
                print("⚠️ [Auth] Apple Sign-In not available (Personal Team?). Using mock authentication.")
                useMockAppleSignIn()
                return
            }
        }

        Task {
            await viewModel.handleAppleSignIn(result)
        }
    }

    private func useMockAppleSignIn() {
        // Create mock auth response for development
        let mockResponse = AuthResponse(
            sessionToken: "mock_apple_session_\(UUID().uuidString)",
            refreshToken: "mock_apple_refresh_\(UUID().uuidString)",
            user: UserDTO(
                id: "mock_apple_user_\(UUID().uuidString)",
                email: "developer@apple.mock",
                name: "Apple Developer",
                profileImageURL: nil,
                hasCompletedProfile: false
            ),
            isNewUser: true,
            expiresAt: Date().addingTimeInterval(86400 * 30) // 30 days
        )

        viewModel.setMockAuthResponse(mockResponse)
    }

    private func handleGoogleSignIn() {
        // Get the root view controller for presenting Google Sign-In
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            viewModel.clearError()
            return
        }

        // Find the topmost presented view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        Task {
            await viewModel.handleGoogleSignIn(presenting: topViewController)
        }
    }

    private func handleAuthResponse(_ response: AuthResponse?) {
        guard let response = response else { return }

        // Navigation is handled automatically by AppCoordinator based on auth state
        // The AuthenticationService updates the auth state, which triggers the AppCoordinator
        // to show the appropriate view (ProfileSetup, Dashboard, etc.)
    }
}

// MARK: - Email Sign In View
struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showForgotPassword = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.momCareBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Sign In with Email")
                                .font(.momCareHeading1)
                                .foregroundColor(.momCareTextPrimary)

                            Text("Enter your credentials to continue")
                                .font(.momCareBody)
                                .foregroundColor(.momCareTextSecondary)
                        }
                        .padding(.top, 32)

                        // Form fields
                        VStack(spacing: 20) {
                            MomCareTextField(
                                title: "Email",
                                placeholder: "your@email.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                icon: "envelope.fill"
                            )

                            MomCareSecureField(
                                title: "Password",
                                placeholder: "Enter your password",
                                text: $password,
                                icon: "lock.fill"
                            )

                            // Forgot password
                            HStack {
                                Spacer()
                                Button(action: {
                                    showForgotPassword = true
                                }) {
                                    Text("Forgot Password?")
                                        .font(.momCareCaption)
                                        .foregroundColor(.momCarePrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Sign In button
                        MomCarePrimaryButton("Sign In", isLoading: isLoading) {
                            signIn()
                        }
                        .padding(.horizontal, 24)
                        .disabled(email.isEmpty || password.isEmpty)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)

                        Spacer()
                    }
                }

                if isLoading {
                    LoadingOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.momCareTextSecondary)
                    }
                }
            }
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else { return }

        isLoading = true

        // Simulate network request
        // In production, implement actual authentication
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            // Note: This is a mock implementation. In production, use AuthenticationService
            dismiss()
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var agreedToTerms = false

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        agreedToTerms
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.momCareBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Your Account")
                                .font(.momCareHeading1)
                                .foregroundColor(.momCareTextPrimary)

                            Text("Join thousands of moms on their wellness journey")
                                .font(.momCareBody)
                                .foregroundColor(.momCareTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 32)

                        // Form fields
                        VStack(spacing: 20) {
                            MomCareTextField(
                                title: "Your Name",
                                placeholder: "Enter your name",
                                text: $name,
                                icon: "person.fill"
                            )

                            MomCareTextField(
                                title: "Email",
                                placeholder: "your@email.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                icon: "envelope.fill"
                            )

                            MomCareSecureField(
                                title: "Password",
                                placeholder: "At least 8 characters",
                                text: $password,
                                icon: "lock.fill"
                            )

                            if !password.isEmpty {
                                PasswordStrengthIndicator(password: password)
                            }

                            MomCareSecureField(
                                title: "Confirm Password",
                                placeholder: "Re-enter your password",
                                text: $confirmPassword,
                                icon: "lock.fill"
                            )

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.momCareError)
                                    Text("Passwords do not match")
                                        .font(.momCareCaption)
                                        .foregroundColor(.momCareError)
                                    Spacer()
                                }
                            }

                            // Terms agreement
                            HStack(alignment: .top, spacing: 12) {
                                Button(action: {
                                    agreedToTerms.toggle()
                                }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 22))
                                        .foregroundColor(agreedToTerms ? .momCarePrimary : .momCareTextTertiary)
                                }

                                Text("I agree to the Terms of Service and Privacy Policy")
                                    .font(.momCareCaption)
                                    .foregroundColor(.momCareTextSecondary)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)

                        // Sign Up button
                        MomCarePrimaryButton("Create Account", isLoading: isLoading) {
                            signUp()
                        }
                        .padding(.horizontal, 24)
                        .disabled(!isFormValid)
                        .opacity(!isFormValid ? 0.6 : 1.0)

                        Spacer()
                    }
                }

                if isLoading {
                    LoadingOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.momCareTextSecondary)
                    }
                }
            }
            .alert("Sign Up Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func signUp() {
        guard isFormValid else { return }

        isLoading = true

        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            // Note: This is a mock implementation. In production, use AuthenticationService
            dismiss()
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.momCareBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.momCarePrimary.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.momCarePrimary)
                    }
                    .padding(.top, 40)

                    // Header
                    VStack(spacing: 8) {
                        Text("Reset Password")
                            .font(.momCareHeading1)
                            .foregroundColor(.momCareTextPrimary)

                        Text("Enter your email and we'll send you a link to reset your password")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    // Email field
                    MomCareTextField(
                        title: "Email",
                        placeholder: "your@email.com",
                        text: $email,
                        keyboardType: .emailAddress,
                        icon: "envelope.fill"
                    )
                    .padding(.horizontal, 24)

                    // Submit button
                    MomCarePrimaryButton("Send Reset Link", isLoading: isLoading) {
                        sendResetLink()
                    }
                    .padding(.horizontal, 24)
                    .disabled(email.isEmpty)
                    .opacity(email.isEmpty ? 0.6 : 1.0)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.momCareTextSecondary)
                    }
                }
            }
            .alert("Check Your Email", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("We've sent a password reset link to \(email)")
            }
        }
    }

    private func sendResetLink() {
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            showSuccess = true
        }
    }
}

// MARK: - Supporting Components

struct MomCareTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.momCareCaptionBold)
                .foregroundColor(.momCareTextSecondary)

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.momCareTextTertiary)
                        .frame(width: 24)
                }

                TextField(placeholder, text: $text)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.momCareTextTertiary.opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct MomCareSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    @State private var isSecure = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.momCareCaptionBold)
                .foregroundColor(.momCareTextSecondary)

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.momCareTextTertiary)
                        .frame(width: 24)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextPrimary)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.momCareBody)
                        .foregroundColor(.momCareTextPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.momCareTextTertiary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.momCareTextTertiary.opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: PasswordStrength {
        if password.count < 6 { return .weak }
        if password.count < 8 { return .fair }
        if password.count >= 8 && password.rangeOfCharacter(from: .decimalDigits) != nil { return .good }
        if password.count >= 10 && password.rangeOfCharacter(from: .uppercaseLetters) != nil { return .strong }
        return .good
    }

    enum PasswordStrength {
        case weak, fair, good, strong

        var color: Color {
            switch self {
            case .weak: return .momCareError
            case .fair: return .momCareWarning
            case .good: return .momCareInfo
            case .strong: return .momCareSuccess
            }
        }

        var text: String {
            switch self {
            case .weak: return "Weak"
            case .fair: return "Fair"
            case .good: return "Good"
            case .strong: return "Strong"
            }
        }

        var progress: Double {
            switch self {
            case .weak: return 0.25
            case .fair: return 0.5
            case .good: return 0.75
            case .strong: return 1.0
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.momCareTextTertiary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(strength.color)
                        .frame(width: geometry.size.width * strength.progress, height: 4)
                        .animation(.easeInOut, value: strength.progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text("Password strength: ")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)

                Text(strength.text)
                    .font(.momCareCaptionBold)
                    .foregroundColor(strength.color)
            }
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Please wait...")
                    .font(.momCareBody)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.momCareTextPrimary.opacity(0.9))
            )
        }
    }
}

// MARK: - Preview
#Preview("Sign In") {
    @MainActor func createPreviewViewModel() -> AuthenticationViewModel {
        let keychainManager = KeychainManager(service: "com.momcare.postfit.preview")
        let userDefaultsManager = UserDefaultsManager()
        let cryptoUtilities = CryptoUtilities()
        let apiClient: APIClientProtocol = MockAPIClient()

        let appleSignInService = AppleSignInService(
            keychainManager: keychainManager,
            cryptoUtilities: cryptoUtilities
        )

        let googleSignInService = GoogleSignInService(
            keychainManager: keychainManager
        )

        let authService = AuthenticationService(
            apiClient: apiClient,
            keychainManager: keychainManager,
            userDefaultsManager: userDefaultsManager,
            appleSignInService: appleSignInService,
            googleSignInService: googleSignInService
        )

        return AuthenticationViewModel(authService: authService)
    }

    return SignInView(viewModel: createPreviewViewModel())
}

#Preview("Email Sign In") {
    EmailSignInView()
}

#Preview("Sign Up") {
    SignUpView()
}
