//
//  ContentView.swift
//  PostFit (MomCare)
//
//  Root content view - now redirects to AppCoordinator
//  Kept for backward compatibility and testing
//
//  Created by Dip on 12/30/25.
//

import SwiftUI

/// Root content view for the MomCare app
/// This view serves as the main entry point and delegates to AppCoordinator
struct ContentView: View {
    @StateObject private var appState: AppState
    @StateObject private var authViewModel: AuthenticationViewModel

    init(appState: AppState, authViewModel: AuthenticationViewModel) {
        _appState = StateObject(wrappedValue: appState)
        _authViewModel = StateObject(wrappedValue: authViewModel)
    }

    var body: some View {
        // The app flow is now managed by AppCoordinator
        // which handles onboarding, auth, profile setup, and main navigation
        AppCoordinator(appState: appState, authViewModel: authViewModel)
    }
}

// MARK: - Preview Helpers

/// Creates preview dependencies for testing
@MainActor
private func createPreviewDependencies() -> (AppState, AuthenticationViewModel) {
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

    let appState = AppState(
        authService: authService,
        userDefaultsManager: userDefaultsManager
    )

    let authViewModel = AuthenticationViewModel(authService: authService)

    return (appState, authViewModel)
}

/// Preview for the main content flow
#Preview("App Flow") {
    let (appState, authViewModel) = createPreviewDependencies()
    ContentView(appState: appState, authViewModel: authViewModel)
}

/// Preview for the main dashboard directly
#Preview("Dashboard") {
    MainTabView()
}

/// Preview for onboarding flow
#Preview("Onboarding") {
    OnboardingView(isOnboardingComplete: .constant(false))
}

/// Preview for sign in
#Preview("Sign In") {
    let (_, authViewModel) = createPreviewDependencies()
    SignInView(viewModel: authViewModel)
}
