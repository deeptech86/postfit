# Google Sign-In SDK Setup Guide

## Prerequisites
- Active Apple Developer Account
- Google Cloud Console Access

---

## Step 1: Get Google OAuth Client ID

### 1.1 Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project called "MomCare" (or select existing)
3. Enable the **Google Sign-In API**

### 1.2 Create OAuth 2.0 Credentials
1. Navigate to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth Client ID**
3. Select **iOS** as the application type
4. Configure:
   - **Name**: MomCare iOS
   - **Bundle ID**: `com.momcare.postfit`
5. Click **Create**
6. **Copy the Client ID** (format: `XXXXXXXXX.apps.googleusercontent.com`)

---

## Step 2: Add GoogleSignIn Swift Package

### 2.1 Open Xcode
1. Open `/Users/dipmacmini/Documents/postFit/PostFit/PostFit.xcodeproj` in Xcode

### 2.2 Add Package Dependency
1. In Xcode, go to **File** → **Add Package Dependencies...**
2. In the search bar, enter:
   ```
   https://github.com/google/GoogleSignIn-iOS
   ```
3. Select **GoogleSignIn-iOS** package
4. Choose version: **Exact Version** → `8.0.0` (or latest)
5. Click **Add Package**
6. In the package products dialog:
   - ✅ Check **GoogleSignIn** (add to PostFit target)
   - ✅ Check **GoogleSignInSwift** (add to PostFit target)
7. Click **Add Package**

---

## Step 3: Configure URL Scheme

### 3.1 Add Reversed Client ID
1. In Xcode, select the **PostFit** project in the navigator
2. Select the **PostFit** target
3. Go to the **Info** tab
4. Expand **URL Types** section (or add it if it doesn't exist)
5. Click the **+** button to add a new URL Type:
   - **Identifier**: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   - **URL Schemes**: Add your reversed client ID
     - Take your Client ID: `123456789-abc.apps.googleusercontent.com`
     - Reverse it to: `com.googleusercontent.apps.123456789-abc`
   - **Role**: Editor

**Example**:
```
Client ID: 123456789-abc.apps.googleusercontent.com
Reversed:  com.googleusercontent.apps.123456789-abc
```

---

## Step 4: Update Constants.swift

Replace the placeholder Google Client ID in Constants.swift:

```swift
enum Google {
    /// Google OAuth 2.0 Client ID for iOS
    static let clientID = "YOUR_ACTUAL_CLIENT_ID_HERE.apps.googleusercontent.com"

    /// Google OAuth scopes
    static let scopes = ["profile", "email"]

    /// Reversed client ID for URL scheme
    static var reversedClientID: String {
        clientID.components(separatedBy: ".").reversed().joined(separator: ".")
    }
}
```

**Replace** `YOUR_ACTUAL_CLIENT_ID_HERE.apps.googleusercontent.com` with your actual Client ID from Step 1.2.

---

## Step 5: Rebuild and Test

### 5.1 Clean Build Folder
1. In Xcode: **Product** → **Clean Build Folder** (⇧⌘K)

### 5.2 Rebuild Project
1. **Product** → **Build** (⌘B)
2. Fix any compilation errors if they appear

### 5.3 Run on Simulator
1. Select **iPhone 16 Pro** simulator
2. **Product** → **Run** (⌘R)

### 5.4 Test Google Sign-In
1. On the Sign-In screen, tap **Sign in with Google**
2. You should see the Google account selection popup
3. Select a Google account
4. App should navigate to "About Your Delivery" screen
5. **Verify scrolling works** by swiping up/down

---

## Verification Checklist

- [ ] Google Cloud project created
- [ ] OAuth Client ID obtained
- [ ] GoogleSignIn package added to Xcode project
- [ ] Reversed Client ID URL scheme configured in Info → URL Types
- [ ] Constants.swift updated with real Client ID
- [ ] Project builds without errors
- [ ] Google Sign-In popup appears in simulator
- [ ] Authentication succeeds and navigates to ProfileSetupView
- [ ] ProfileSetupView scrolls properly

---

## Troubleshooting

### Issue: "No such module 'GoogleSignIn'"
**Solution**: Make sure you added the package dependency correctly. Check **File** → **Package Dependencies** in Xcode.

### Issue: Google popup doesn't appear
**Solution**:
1. Check that URL scheme is configured correctly
2. Verify Client ID in Constants.swift is correct
3. Check console logs for errors

### Issue: "Invalid Client ID"
**Solution**: Verify the Bundle ID in Google Cloud Console matches `com.momcare.postfit`

### Issue: Scrolling still doesn't work
**Solution**:
1. Make sure you rebuilt the app after the ProfileSetupView fix
2. Try deleting the app from simulator and reinstalling
3. Check that the fix was applied to ProfileSetupView.swift line 60

---

## Files Modified

✅ `/PostFit/Features/Authentication/Services/GoogleSignInService.swift` - Real SDK implementation
✅ `/PostFit/PostFitApp.swift` - Google Sign-In URL handling enabled
✅ `/PostFit/Features/Profile/ProfileSetupView.swift` - ScrollView gesture fix (line 60)

---

## Next Steps After Setup

Once Google Sign-In is working:
1. Test the complete flow: Sign In → Profile Setup → Dashboard
2. Test sign-out functionality
3. Test with multiple Google accounts
4. Consider adding error handling for network failures
