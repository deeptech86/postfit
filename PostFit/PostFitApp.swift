//
//  PostFitApp.swift
//  PostFit (MomCare)
//
//  Main app entry point for MomCare - Postpartum Health & Wellness App
//  A supportive companion for new mothers on their wellness journey
//
//  Created by Dip on 12/30/25.
//

import SwiftUI
import GoogleSignIn
// import FirebaseCore  // Uncomment after adding Firebase package

@main
struct PostFitApp: App {
    // MARK: - Dependencies

    private let keychainManager: KeychainManager
    private let userDefaultsManager: UserDefaultsManager
    private let cryptoUtilities: CryptoUtilities
    private let apiClient: APIClientProtocol
    private let appleSignInService: AppleSignInService
    private let googleSignInService: GoogleSignInService
    private let authService: AuthenticationService

    // MARK: - State

    @StateObject private var appState: AppState
    @StateObject private var authViewModel: AuthenticationViewModel

    // MARK: - Initialization

    init() {
        // Initialize Firebase (uncomment after adding Firebase package)
        // FirebaseApp.configure()

        // Initialize core dependencies
        let keychainManager = KeychainManager()
        let userDefaultsManager = UserDefaultsManager()
        let cryptoUtilities = CryptoUtilities()

        // Initialize API client (real backend at localhost:3000 in DEBUG mode)
        let apiClient: APIClientProtocol = APIClient()

        // Initialize authentication services
        let appleSignInService = AppleSignInService(
            keychainManager: keychainManager,
            cryptoUtilities: cryptoUtilities
        )

        let googleSignInService = GoogleSignInService(
            keychainManager: keychainManager,
            clientID: Constants.Google.clientID
        )

        let authService = AuthenticationService(
            apiClient: apiClient,
            keychainManager: keychainManager,
            userDefaultsManager: userDefaultsManager,
            appleSignInService: appleSignInService,
            googleSignInService: googleSignInService
        )

        // Store dependencies
        self.keychainManager = keychainManager
        self.userDefaultsManager = userDefaultsManager
        self.cryptoUtilities = cryptoUtilities
        self.apiClient = apiClient
        self.appleSignInService = appleSignInService
        self.googleSignInService = googleSignInService
        self.authService = authService

        // Initialize app state with dependencies
        let appState = AppState(
            authService: authService,
            userDefaultsManager: userDefaultsManager
        )
        _appState = StateObject(wrappedValue: appState)

        // Initialize auth view model
        let authViewModel = AuthenticationViewModel(authService: authService)
        _authViewModel = StateObject(wrappedValue: authViewModel)

        // Defer appearance configuration to avoid blocking app launch (performance optimization)
        DispatchQueue.main.async {
            Self.configureAppearance()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator(appState: appState, authViewModel: authViewModel)
                .environmentObject(appState)
                .preferredColorScheme(.light) // Default to light mode for calm, nurturing feel
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
    }

    // MARK: - URL Handling

    /// Handle incoming URLs (for Google Sign-In callback)
    private func handleOpenURL(_ url: URL) {
        #if DEBUG
        print("📱 [App] Received URL: \(url)")
        #endif

        // Handle Google Sign-In URL callback
        GIDSignIn.sharedInstance.handle(url)
    }

    /// Configure global UI appearance settings (static to allow deferred async call)
    private static func configureAppearance() {
        // Navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor(Color.momCareBackground)
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.momCareTextPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.momCareTextPrimary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        navigationBarAppearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance

        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.momCareCardBackground)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Page control appearance (for onboarding)
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Color.momCarePrimary)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(Color.momCarePrimary.opacity(0.3))

        // Slider appearance
        UISlider.appearance().minimumTrackTintColor = UIColor(Color.momCarePrimary)

        // Switch appearance
        UISwitch.appearance().onTintColor = UIColor(Color.momCarePrimary)
    }
}
