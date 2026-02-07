# 🔥 Firebase Storage Setup - Complete Step-by-Step Guide

Follow these steps **in order** to set up Firebase Storage for your exercise videos.

---

## ✅ **STEP 1: Create Firebase Project** (5 minutes)

### 1.1 Go to Firebase Console
- Open your browser and visit: **https://console.firebase.google.com/**
- Sign in with your Google account

### 1.2 Create New Project
1. Click **"Add project"** (big plus button)
2. **Project name**: Type `PostFit` or `MomCare`
3. Click **"Continue"**
4. **Google Analytics**: Toggle OFF (you can enable later)
5. Click **"Create project"**
6. Wait ~30 seconds for setup
7. Click **"Continue"** when done

✅ **Checkpoint**: You should now see your Firebase project dashboard

---

## ✅ **STEP 2: Add iOS App to Firebase** (3 minutes)

### 2.1 Register Your App
1. On Firebase dashboard, click the **iOS icon** (looks like ⊕ with Apple logo)
2. Fill in the form:
   - **iOS bundle ID**: `com.daipayan.postfit`
   - **App nickname**: `PostFit`
   - **App Store ID**: Leave empty for now
3. Click **"Register app"**

### 2.2 Download Config File
1. Click **"Download GoogleService-Info.plist"**
2. Save this file to your Downloads folder
3. Click **"Next"** (we'll add the SDK in Xcode)
4. Click **"Next"** again (skip the initialization code for now)
5. Click **"Continue to console"**

✅ **Checkpoint**: You should have `GoogleService-Info.plist` in your Downloads

---

## ✅ **STEP 3: Add Config File to Xcode** (2 minutes)

### 3.1 Open Xcode (Already open)
- Your PostFit project should be open in Xcode

### 3.2 Add GoogleService-Info.plist
1. In Xcode, find the **Project Navigator** (left sidebar)
2. Right-click on **"PostFit"** folder (the blue one at the top)
3. Select **"Add Files to PostFit..."**
4. Navigate to your **Downloads** folder
5. Select **GoogleService-Info.plist**
6. ✅ Check **"Copy items if needed"**
7. ✅ Check that **"PostFit" target is selected**
8. Click **"Add"**

### 3.3 Verify File Added
- You should see `GoogleService-Info.plist` in your Project Navigator
- Click on it and verify it shows Firebase configuration data

✅ **Checkpoint**: GoogleService-Info.plist is now in your Xcode project

---

## ✅ **STEP 4: Add Firebase SDK Package** (5 minutes)

### 4.1 Add Package Dependency
1. In Xcode menu: **File → Add Package Dependencies...**
2. In the search box, paste: `https://github.com/firebase/firebase-ios-sdk`
3. Press **Enter** or click **"Add Package"**

### 4.2 Select Version
- **Dependency Rule**: Select **"Up to Next Major Version"**
- **Version**: Should show `11.0.0` or higher
- Click **"Add Package"**

### 4.3 Select Products (IMPORTANT!)
You'll see a list of Firebase products. Select **ONLY** these:
- ✅ **FirebaseStorage**
- ✅ **FirebaseAuth** (optional, but recommended)

Scroll through and make sure ONLY these 2 are checked, then click **"Add Package"**

### 4.4 Wait for Package Download
- Xcode will download the packages (~1-2 minutes)
- You'll see progress in the top toolbar

✅ **Checkpoint**: You should see Firebase packages in Project Navigator under "Package Dependencies"

---

## ✅ **STEP 5: Enable Firebase Storage** (3 minutes)

### 5.1 Go to Storage in Firebase Console
1. Go back to **Firebase Console** in your browser
2. In the left menu, click **"Storage"** (or "Build" → "Storage")
3. Click **"Get started"**

### 5.2 Set Up Security Rules
1. You'll see a dialog about security rules
2. Select **"Start in production mode"**
3. Click **"Next"**

### 5.3 Choose Storage Location
1. Select closest region (e.g., **us-central1** or **us-east1**)
2. Click **"Done"**
3. Wait ~10 seconds for setup

### 5.4 Update Security Rules
1. Click the **"Rules"** tab at the top
2. You'll see default rules. **Replace everything** with:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Public read for exercise videos
    match /exercise-videos/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

3. Click **"Publish"**

✅ **Checkpoint**: Storage is now enabled and configured

---

## ✅ **STEP 6: Create Folder & Upload Videos** (10 minutes)

### 6.1 Create exercise-videos Folder
1. In Storage, click the **"Files"** tab
2. Click **"Create folder"**
3. Name: `exercise-videos`
4. Click **"Create"**

### 6.2 Upload Your Videos
1. Click on the **"exercise-videos"** folder
2. Click **"Upload file"** button
3. Select your exercise video files (or use test videos for now)

**Recommended naming:**
- `kegel-exercise.mp4`
- `gentle-walking.mp4`
- `breathing-exercise.mp4`
- `cat-cow-stretch.mp4`
- `pelvic-tilts.mp4`

4. Wait for uploads to complete (shows progress bar)

### 6.3 Get Download URLs
For each uploaded video:
1. Click on the video name
2. Click **"Download URL"** button at the top
3. **Copy the URL** - you'll need this!

**Save these URLs in a text file - you'll use them in the next step!**

Example URL format:
```
https://firebasestorage.googleapis.com/v0/b/postfit-xxxxx.appspot.com/o/exercise-videos%2Fkegel-exercise.mp4?alt=media&token=xxxxx
```

✅ **Checkpoint**: All 5 videos uploaded with URLs copied

---

## ✅ **STEP 7: Initialize Firebase in Code** (Already Done!)

The code has already been prepared. Just verify:

1. Check that `FirebaseStorageManager.swift` exists in your project
2. Check that `VideoManager.swift` exists in your project

✅ **Checkpoint**: Firebase code is ready

---

## ✅ **STEP 8: Update PostFitApp.swift** (2 minutes)

I'll update this file to initialize Firebase when the app starts.

---

## ✅ **STEP 9: Update Exercise Video URLs** (5 minutes)

Once you have your Firebase URLs from Step 6.3, I'll update the exercise data to use them.

---

## 🎯 **What's Next?**

After completing Steps 1-6 above:

1. **Share your Firebase URLs with me** (from Step 6.3)
2. I'll update the code to use your Firebase Storage URLs
3. I'll add Firebase initialization
4. We'll build and test!

---

## 📋 **Quick Checklist**

Before proceeding, make sure you have:
- [ ] Created Firebase project
- [ ] Added iOS app to Firebase
- [ ] Downloaded GoogleService-Info.plist
- [ ] Added plist to Xcode project
- [ ] Added Firebase SDK package to Xcode
- [ ] Enabled Firebase Storage
- [ ] Created exercise-videos folder
- [ ] Uploaded 5 video files
- [ ] Copied all 5 download URLs

---

## 🆘 **Troubleshooting**

### "Can't find GoogleService-Info.plist"
- Make sure you dragged it into Xcode project
- Check "Copy items if needed" was selected
- File should be in PostFit folder, not subfolder

### "Package resolution failed"
- Make sure you have internet connection
- Try: File → Packages → Reset Package Caches
- Try again

### "Storage rules error"
- Make sure you copied the rules exactly
- Click "Publish" after pasting
- Wait a few seconds for rules to apply

---

## 📞 **Need Help?**

If you get stuck on any step:
1. Take a screenshot of the error
2. Tell me which step number you're on
3. I'll help you fix it!

---

**Ready to start?** Begin with Step 1 and work your way down! 🚀
