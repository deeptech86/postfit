# Firebase Storage Setup Guide for PostFit

## Step 1: Create Firebase Project

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Sign in with your Google account

2. **Create New Project**
   - Click "Add project"
   - Project name: `PostFit` (or `MomCare`)
   - Accept terms and click "Continue"
   - Disable Google Analytics (optional for now)
   - Click "Create project"

3. **Wait for Setup**
   - Firebase will create your project (~30 seconds)
   - Click "Continue" when done

---

## Step 2: Add iOS App to Firebase

1. **Register iOS App**
   - In Firebase Console, click the iOS icon (⊕ Add app)
   - Bundle ID: `com.daipayan.postfit` (from your Xcode project)
   - App nickname: `PostFit`
   - Click "Register app"

2. **Download GoogleService-Info.plist**
   - Download the `GoogleService-Info.plist` file
   - **IMPORTANT**: Save this file - you'll add it to Xcode next

3. **Add Config File to Xcode**
   - Open Xcode
   - Drag `GoogleService-Info.plist` into your Xcode project
   - Make sure "Copy items if needed" is checked
   - Target: PostFit (main app target)
   - Click "Finish"

---

## Step 3: Add Firebase SDK to Xcode

### Option A: Swift Package Manager (Recommended)

1. **Add Firebase Package**
   - In Xcode: File → Add Package Dependencies
   - Enter URL: `https://github.com/firebase/firebase-ios-sdk`
   - Version: Select "Up to Next Major Version" (10.0.0 or latest)
   - Click "Add Package"

2. **Select Products**
   - Check these frameworks:
     - ✅ FirebaseStorage
     - ✅ FirebaseAuth (optional, for user-specific storage)
   - Click "Add Package"

### Option B: CocoaPods (Alternative)

```ruby
# Add to Podfile
pod 'Firebase/Storage'

# Then run in terminal:
pod install
```

---

## Step 4: Enable Firebase Storage

1. **Go to Storage in Firebase Console**
   - In Firebase Console, click "Storage" in left menu
   - Click "Get Started"

2. **Configure Security Rules**
   - Start in **production mode** for now
   - Click "Next"

3. **Select Storage Location**
   - Choose closest region (e.g., `us-central1`)
   - Click "Done"

4. **Update Security Rules** (Important!)
   - Go to "Rules" tab
   - Replace with this:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow public read access to exercise videos
    match /exercise-videos/{videoFile} {
      allow read: if true;  // Public read
      allow write: if false; // Only you can upload
    }

    // Default deny all
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

   - Click "Publish"

---

## Step 5: Upload Your Exercise Videos

### Via Firebase Console (Easy Way):

1. **Create Folder Structure**
   - In Firebase Storage, click "Create folder"
   - Name: `exercise-videos`
   - Click "Create"

2. **Upload Videos**
   - Click on `exercise-videos` folder
   - Click "Upload file"
   - Upload your 5 exercise videos:
     - `kegel-exercise.mp4`
     - `gentle-walking.mp4`
     - `breathing-exercise.mp4`
     - `cat-cow-stretch.mp4`
     - `pelvic-tilts.mp4`

3. **Get Download URLs**
   - Click on each uploaded video
   - Click "Download URL" button
   - Copy the URL - you'll need these!

**Your URLs will look like:**
```
https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/exercise-videos%2Fkegel-exercise.mp4?alt=media&token=XXXX
```

---

## Step 6: Configure App with Firebase

### Update Info.plist (if needed)

Add these entries to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## Step 7: Initialize Firebase in App

This is done in code (see FirebaseStorageManager.swift)

---

## Step 8: Update Exercise URLs

Once videos are uploaded, update `HealthData.swift` with the Firebase URLs:

```swift
static let sampleKegel = Exercise(
    // ... other properties
    videoURL: "https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/exercise-videos%2Fkegel-exercise.mp4?alt=media&token=XXXX"
)
```

---

## Pricing & Limits

### Free Tier (Spark Plan):
- ✅ Storage: 5 GB
- ✅ Downloads: 1 GB/day
- ✅ Uploads: 20k/day

### Estimated Usage for PostFit:
- **5 videos × 10 MB** = 50 MB storage (~1% of free tier)
- **1,000 users × 5 videos × 10 MB** = 50 GB/month downloads
- **Cost**: Free for first ~1,000 users/month

### When to Upgrade:
- When you exceed 1 GB downloads per day
- Blaze Plan (pay-as-you-go): ~$0.026/GB

---

## Security Best Practices

1. ✅ Videos are public (read-only)
2. ✅ Only you can upload/delete (via Firebase Console)
3. ✅ No authentication needed for users
4. ✅ Direct download URLs (no API calls needed)

---

## Troubleshooting

### "Permission denied" error:
- Check Storage Rules allow public read
- Verify URL has `alt=media` parameter

### Videos won't download:
- Check internet connection
- Verify `GoogleService-Info.plist` is in project
- Check Firebase Console shows files uploaded

### App crashes on startup:
- Ensure Firebase is initialized in `PostFitApp.swift`
- Check `GoogleService-Info.plist` is added to target

---

## Next Steps

1. ✅ Create Firebase project
2. ✅ Add iOS app
3. ✅ Download GoogleService-Info.plist
4. ✅ Add Firebase SDK to Xcode
5. ✅ Enable Storage
6. ✅ Upload videos
7. ✅ Update exercise URLs in code
8. ✅ Test video playback

---

## Support Resources

- Firebase Storage Docs: https://firebase.google.com/docs/storage
- iOS Setup: https://firebase.google.com/docs/ios/setup
- Pricing: https://firebase.google.com/pricing

---

**Ready to proceed?** Follow the steps above, then I'll update the code with your Firebase URLs!
