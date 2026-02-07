# PostFit (MomCare) - Development Context

## Project Overview
PostFit is an iOS postpartum fitness and wellness tracking app built with SwiftUI. It includes features for exercise tracking, nutrition logging, hydration tracking, and user authentication.

## Recent Development Session Summary (February 2026)

### Authentication System

#### Apple Sign-In Implementation
- **Status**: Implemented with mock fallback for Personal Team accounts
- **Issue**: Error 1000 (`ASAuthorizationError.unknown`) occurs because Sign in with Apple requires a paid Apple Developer Program ($99/year)
- **Solution**: Added mock authentication fallback in `SignInView.swift` that detects error 1000 and creates a mock session for development

**Key files modified:**
- `PostFit/Features/Authentication/Services/AppleSignInService.swift` - Added `prepareNonce()` method
- `PostFit/Features/Authentication/Services/AuthenticationService.swift` - Added `prepareAppleSignInNonce()` method
- `PostFit/ViewModels/AuthenticationViewModel.swift` - Added `prepareAppleSignInNonce()` method
- `PostFit/Features/Onboarding/SignInView.swift` - Added nonce to Apple request + mock fallback for error 1000

**To enable real Apple Sign-In:**
1. Enroll in Apple Developer Program ($99/year)
2. Add "Sign in with Apple" capability in Xcode (Signing & Capabilities tab)
3. Remove mock fallback code from `handleAppleSignIn()` in SignInView.swift

#### Google Sign-In
- **Status**: Implemented and working
- Uses GoogleSignIn SDK with Firebase

### AI Usage Manager
- Updated to use Keychain storage instead of UserDefaults
- AI usage counter now persists across app reinstalls
- File: `PostFit/Core/Managers/AIUsageManager.swift`

### Dashboard Navigation
- Created `TabNavigationManager` for cross-app tab navigation
- Created `NutritionDataManager` for sharing nutrition data between views
- Dashboard quick actions now navigate to appropriate tabs:
  - "Log Meal" -> Nutrition tab (scrolls to Add Food)
  - "Add Water" -> Hydration tab
  - "Exercise" -> Exercise tab

### Exercise Features
- `ExerciseDataManager` tracks today's allocated exercise
- Dashboard shows exercise progress: "05/25 min" format
- Shows calories burned from exercise sessions

### Video Player Fixes
- Fixed video not playing on first click
- Issue was AVPlayer being created AFTER videoSource changed
- Solution: `setupAVPlayerSync()` creates player BEFORE changing videoSource
- YouTube player: Moved HTML loading from `updateUIView` to `makeUIView`

## Project Structure

```
PostFit/
├── Core/
│   ├── Managers/
│   │   ├── AIUsageManager.swift
│   │   ├── KeychainManager.swift
│   │   └── UserDefaultsManager.swift
│   ├── Navigation/
│   │   └── TabNavigationManager.swift
│   ├── Services/
│   │   └── CryptoUtilities.swift
│   └── Video/
│       └── YouTubeVideoPlayer.swift
├── Features/
│   ├── Authentication/
│   │   └── Services/
│   │       ├── AppleSignInService.swift
│   │       ├── AuthenticationService.swift
│   │       └── GoogleSignInService.swift
│   ├── Dashboard/
│   │   └── DashboardView.swift
│   ├── Exercise/
│   │   ├── ExerciseView.swift
│   │   └── ExerciseVideoPlayer.swift
│   ├── Nutrition/
│   │   ├── FoodTrackingView.swift
│   │   └── NutritionDataManager.swift
│   └── Onboarding/
│       └── SignInView.swift
├── ViewModels/
│   └── AuthenticationViewModel.swift
└── Models/
    └── (various model files)
```

## Known Issues / TODO

1. **Apple Sign-In**: Requires paid developer account for production
2. **Entitlements file**: Was cleared - may need to re-add capabilities through Xcode
3. **iCloud Sync**: Commented out in entitlements, needs provisioning profile update to enable

## Build Configuration

- **Bundle ID**: com.daipayan.postfit
- **Team**: Daipayan Sarkar (Personal Team)
- **Minimum iOS**: Check project settings
- **Signing**: Automatic with Xcode Managed Profile

## Dependencies

- Firebase (Authentication, Firestore, Storage)
- GoogleSignIn
- AVKit (video playback)
- WebKit (YouTube embed)
- AuthenticationServices (Apple Sign-In)
- CryptoKit (nonce generation)
