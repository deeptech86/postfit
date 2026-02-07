//
//  MainTabView.swift
//  PostFit (MomCare)
//
//  Main tab bar navigation for the app
//  Clean, accessible navigation between main features
//

import SwiftUI

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var tabNavigationManager = TabNavigationManager.shared
    @State private var previousTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case nutrition = "Nutrition"
        case exercise = "Exercise"
        case hydration = "Hydration"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .nutrition: return "fork.knife"
            case .exercise: return "figure.run"
            case .hydration: return "drop.fill"
            case .profile: return "person.fill"
            }
        }

        var selectedIcon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .nutrition: return "fork.knife"
            case .exercise: return "figure.run"
            case .hydration: return "drop.fill"
            case .profile: return "person.fill"
            }
        }

        var color: Color {
            switch self {
            case .dashboard: return .momCarePrimary
            case .nutrition: return .momCareNutrition
            case .exercise: return .momCareExercise
            case .hydration: return .momCareHydration
            case .profile: return .momCarePrimary
            }
        }

        /// Convert from TabNavigationManager.Tab
        static func from(_ navTab: TabNavigationManager.Tab) -> Tab {
            switch navTab {
            case .dashboard: return .dashboard
            case .nutrition: return .nutrition
            case .exercise: return .exercise
            case .hydration: return .hydration
            case .profile: return .profile
            }
        }

        /// Convert to TabNavigationManager.Tab
        var asNavTab: TabNavigationManager.Tab {
            switch self {
            case .dashboard: return .dashboard
            case .nutrition: return .nutrition
            case .exercise: return .exercise
            case .hydration: return .hydration
            case .profile: return .profile
            }
        }
    }

    private var selectedTab: Binding<Tab> {
        Binding(
            get: { Tab.from(tabNavigationManager.selectedTab) },
            set: { tabNavigationManager.selectedTab = $0.asNavTab }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: selectedTab) {
                DashboardView()
                    .tag(Tab.dashboard)

                FoodTrackingView()
                    .tag(Tab.nutrition)

                ExerciseView()
                    .tag(Tab.exercise)

                HydrationView()
                    .tag(Tab.hydration)

                ProfileView()
                    .tag(Tab.profile)
            }
            .onChange(of: tabNavigationManager.selectedTab) { oldValue, _ in
                // Haptic feedback on tab change
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }

            // Custom tab bar
            CustomTabBar(selectedTab: selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 28) // Extra padding for safe area
        .background(
            TabBarBackground()
        )
    }
}

struct TabBarButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon with animation
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(tab.color.opacity(0.15))
                            .frame(width: 48, height: 48)
                    }

                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? tab.color : .momCareTextTertiary)
                }
                .frame(height: 48)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                // Label
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tab.color : .momCareTextTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TabBarBackground: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top border/shadow
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 4)

            // Main background
            Rectangle()
                .fill(Color.momCareCardBackground)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }
}

// MARK: - App Coordinator
struct AppCoordinator: View {
    @StateObject private var appState: AppState
    private let authViewModel: AuthenticationViewModel

    init(appState: AppState, authViewModel: AuthenticationViewModel) {
        _appState = StateObject(wrappedValue: appState)
        self.authViewModel = authViewModel
    }

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingFlow(appState: appState)
            } else if !appState.isAuthenticated {
                SignInView(viewModel: authViewModel)
            } else if !appState.hasCompletedProfileSetup {
                NavigationView {
                    ProfileSetupView(isProfileComplete: $appState.hasCompletedProfileSetup)
                }
            } else if !appState.hasAcceptedDisclaimer {
                MedicalDisclaimerView(hasAcceptedDisclaimer: $appState.hasAcceptedDisclaimer)
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.hasCompletedProfileSetup)
        .animation(.easeInOut, value: appState.hasAcceptedDisclaimer)
    }
}

// MARK: - Onboarding Flow
struct OnboardingFlow: View {
    @ObservedObject var appState: AppState

    var body: some View {
        OnboardingView(isOnboardingComplete: $appState.hasCompletedOnboarding)
    }
}

// MARK: - App State
class AppState: ObservableObject {
    // MARK: - Authentication Service
    private let authService: AuthenticationService
    private let userDefaultsManager: UserDefaultsManager

    // MARK: - Onboarding & Setup Flags
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            userDefaultsManager.saveBool(hasCompletedOnboarding, forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
        }
    }

    @Published var hasCompletedProfileSetup: Bool {
        didSet {
            userDefaultsManager.saveBool(hasCompletedProfileSetup, forKey: UserDefaultsManager.Keys.hasCompletedProfileSetup)
        }
    }

    @Published var hasAcceptedDisclaimer: Bool {
        didSet {
            userDefaultsManager.saveBool(hasAcceptedDisclaimer, forKey: UserDefaultsManager.Keys.hasAcceptedDisclaimer)
        }
    }

    // MARK: - User Data
    @Published var currentUser: User?
    @Published var currentSession: AuthSession?

    // MARK: - Authentication State
    @Published var isAuthenticated: Bool = false

    // MARK: - Initialization

    init(authService: AuthenticationService, userDefaultsManager: UserDefaultsManager) {
        self.authService = authService
        self.userDefaultsManager = userDefaultsManager

        // Load persisted flags
        self.hasCompletedOnboarding = userDefaultsManager.retrieveBool(forKey: UserDefaultsManager.Keys.hasCompletedOnboarding)
        self.hasCompletedProfileSetup = userDefaultsManager.retrieveBool(forKey: UserDefaultsManager.Keys.hasCompletedProfileSetup)
        self.hasAcceptedDisclaimer = userDefaultsManager.retrieveBool(forKey: UserDefaultsManager.Keys.hasAcceptedDisclaimer)

        // Initialize authentication state
        self.isAuthenticated = authService.isAuthenticated

        // Observe auth service changes
        setupAuthObserver()
    }

    // MARK: - Auth Observer

    private func setupAuthObserver() {
        // Observe session changes from AuthenticationService
        authService.$currentSession
            .assign(to: &$currentSession)

        // Observe authentication state changes
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
    }

    // MARK: - Public Methods

    /// Reset all app state (for testing or logout)
    func reset() {
        Task {
            await signOut()
        }
        hasCompletedOnboarding = false
        hasCompletedProfileSetup = false
        hasAcceptedDisclaimer = false
        currentUser = nil
    }

    /// Sign out user
    func signOut() async {
        await authService.signOut()
        currentUser = nil
        currentSession = nil
    }

    /// Update user data from auth response
    func updateUser(from authResponse: AuthResponse) {
        // Convert UserDTO to User model
        // Note: This is a simplified conversion, you may need to expand this
        let user = User(
            id: UUID(uuidString: authResponse.user.id) ?? UUID(),
            email: authResponse.user.email,
            name: authResponse.user.name,
            profileImageURL: authResponse.user.profileImageURL
        )
        currentUser = user

        // Update profile setup status if available
        if authResponse.user.hasCompletedProfile {
            hasCompletedProfileSetup = true
        }
    }
}

// MARK: - Preview
#Preview("Main Tab View") {
    MainTabView()
}

#Preview("App Coordinator") {
    @MainActor func createPreviewDependencies() -> (AppState, AuthenticationViewModel) {
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

    let (appState, authViewModel) = createPreviewDependencies()
    return AppCoordinator(appState: appState, authViewModel: authViewModel)
}
