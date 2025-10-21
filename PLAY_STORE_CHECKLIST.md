# Play Store Submission Checklist for SplitX

## ✅ Completed Items

### 1. Privacy Policy
- [x] Privacy policy added to Profile screen
- [x] Privacy policy HTML file created (`privacy_policy.html`)
- [ ] **ACTION REQUIRED:** Host privacy policy on a public URL (e.g., GitHub Pages, your website, or Firebase Hosting)
- [ ] **ACTION REQUIRED:** Add privacy policy URL to Play Console

### 2. Terms of Service
- [x] Terms of Service added to Profile screen
- [ ] **OPTIONAL:** Create separate HTML file for Terms of Service

### 3. App Information
- [x] About section added with version number
- [x] Contact email: support@splitx.app

---

## 📋 Play Store Requirements Checklist

### App Content & Description

#### Store Listing
- [ ] **App Name:** SplitX (max 50 characters)
- [ ] **Short Description:** (max 80 characters)
  - Suggested: "Split bills easily with friends. Track expenses, settle payments via UPI."
- [ ] **Full Description:** (max 4000 characters)
  ```
  SplitX - The Smart Way to Split Bills

  Tired of awkward money conversations with friends? SplitX makes splitting bills and managing shared expenses effortless!

  ✨ KEY FEATURES:
  • Easy Expense Tracking - Add expenses and split them instantly
  • Smart Bill Splitting - Split equally or customize shares
  • UPI Integration - Pay directly through UPI apps (Google Pay, PhonePe, Paytm)
  • Group Management - Create groups for trips, roommates, or events
  • Real-time Notifications - Get notified about new expenses and payments
  • Settlement Tracking - See who owes what at a glance
  • Subscription Management - Track recurring bills together
  • Secure & Private - Your data is encrypted and secure

  💰 PERFECT FOR:
  • Roommates sharing rent and utilities
  • Friends splitting restaurant bills
  • Travel groups managing trip expenses
  • Couples tracking shared expenses
  • Event organizers managing group costs

  🔒 PRIVACY & SECURITY:
  • End-to-end encryption
  • Secure Firebase authentication
  • No data selling to third parties
  • Complete control over your data

  📱 HOW IT WORKS:
  1. Create a group or add friends
  2. Add expenses and split them
  3. Track balances in real-time
  4. Settle up via UPI with one tap

  Download SplitX today and say goodbye to money stress!

  Questions? Contact us at support@splitx.app
  ```

#### Graphics Assets Required
- [ ] **App Icon:** 512x512 PNG (32-bit with alpha)
- [ ] **Feature Graphic:** 1024x500 PNG or JPEG
- [ ] **Phone Screenshots:** At least 2, up to 8 (16:9 or 9:16 ratio)
  - Recommended: 1080x1920 or 1080x2340
  - Show: Home screen, expense tracking, group chat, payment flow, profile
- [ ] **7-inch Tablet Screenshots:** (Optional but recommended)
- [ ] **10-inch Tablet Screenshots:** (Optional)
- [ ] **Promo Video:** (Optional) YouTube URL

#### Categorization
- [ ] **App Category:** Finance
- [ ] **Tags:** expense tracker, bill splitting, UPI payments, group expenses

### App Access & Testing

- [ ] **App Access:** 
  - If login required, provide demo credentials:
    - Email: demo@splitx.app
    - Password: Demo@123456
- [ ] **Test Instructions:** Provide clear testing instructions

### Content Rating
- [ ] Complete content rating questionnaire
  - Expected rating: Everyone or Teen (due to UPI payments)

### Privacy & Security

- [x] Privacy Policy URL (must be hosted publicly)
- [ ] **Data Safety Section:** Declare what data you collect
  ```
  Data Collected:
  - Account info (email, username)
  - Financial info (UPI ID, expense data)
  - Messages (group chats)
  - Device info (for notifications)
  
  Data Usage:
  - App functionality
  - Analytics
  - Fraud prevention
  
  Data Sharing:
  - Shared with group members (expenses, messages)
  - No third-party sharing for advertising
  ```

### App Permissions
Review and justify all permissions in AndroidManifest.xml:
- [ ] INTERNET - Required for Firebase and data sync
- [ ] ACCESS_NETWORK_STATE - Check connectivity
- [ ] RECEIVE_BOOT_COMPLETED - For notifications
- [ ] VIBRATE - Notification alerts
- [ ] POST_NOTIFICATIONS - Push notifications (Android 13+)

### Technical Requirements

#### Build Configuration
- [ ] **Version Code:** 1
- [ ] **Version Name:** 1.0.0
- [ ] **Minimum SDK:** API 21 (Android 5.0) or higher
- [ ] **Target SDK:** API 34 (Android 14) - **REQUIRED by Google**
- [ ] **Compile SDK:** API 34

#### App Bundle
- [ ] Build release AAB (Android App Bundle)
  ```bash
  flutter build appbundle --release
  ```
- [ ] Sign with upload key
- [ ] Enable R8/ProGuard for code shrinking

#### Testing
- [ ] Test on multiple devices (different screen sizes)
- [ ] Test on Android 5.0+ devices
- [ ] Test all payment flows
- [ ] Test offline functionality
- [ ] Test push notifications
- [ ] No crashes or ANRs

### Compliance

- [ ] **Target Audience:** 13+ (due to financial transactions)
- [ ] **Ads:** Declare if app contains ads (No)
- [ ] **In-App Purchases:** Declare if applicable (No)
- [ ] **Content Guidelines:** Ensure compliance with Google Play policies

### Pre-Launch Report
- [ ] Review pre-launch report after upload
- [ ] Fix any crashes or issues found
- [ ] Test on Firebase Test Lab (optional but recommended)

---

## 🚀 Submission Steps

### 1. Prepare Assets
```bash
# Create release build
flutter clean
flutter pub get
flutter build appbundle --release

# Output location:
# build/app/outputs/bundle/release/app-release.aab
```

### 2. Create App in Play Console
1. Go to [Google Play Console](https://play.google.com/console)
2. Create new app
3. Fill in app details

### 3. Upload Privacy Policy
**Option 1: GitHub Pages (Free)**
```bash
# Create a GitHub repository
# Upload privacy_policy.html
# Enable GitHub Pages
# URL will be: https://yourusername.github.io/repo-name/privacy_policy.html
```

**Option 2: Firebase Hosting (Free)**
```bash
firebase init hosting
# Copy privacy_policy.html to public folder
firebase deploy --only hosting
```

### 4. Complete Store Listing
- Upload all graphics
- Write descriptions
- Add privacy policy URL
- Complete content rating

### 5. Upload App Bundle
- Upload AAB file
- Set up release (Production, Open Testing, or Closed Testing)
- Add release notes

### 6. Review & Submit
- Review all sections
- Submit for review
- Wait for approval (typically 1-3 days)

---

## 📱 Post-Launch

### Monitor
- [ ] Check crash reports in Play Console
- [ ] Monitor user reviews and ratings
- [ ] Track app performance metrics

### Update Strategy
- [ ] Plan regular updates
- [ ] Respond to user feedback
- [ ] Fix bugs promptly

---

## 🔧 Important Files to Update

### android/app/build.gradle
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.example.splitx"  // Change this!
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

### android/app/src/main/AndroidManifest.xml
- Ensure all permissions are necessary
- Add proper permission descriptions

### pubspec.yaml
```yaml
name: splitx
description: Split bills easily with friends
version: 1.0.0+1
```

---

## 📞 Support & Resources

- **Google Play Console:** https://play.google.com/console
- **Play Store Policies:** https://play.google.com/about/developer-content-policy/
- **Firebase Console:** https://console.firebase.google.com/
- **Flutter Release Guide:** https://docs.flutter.dev/deployment/android

---

## ⚠️ Common Rejection Reasons to Avoid

1. **Missing Privacy Policy** - ✅ Fixed
2. **Wrong Target SDK** - Check build.gradle
3. **Crashes on Launch** - Test thoroughly
4. **Missing Permissions Explanation** - Add in manifest
5. **Misleading Screenshots** - Show actual app features
6. **Incomplete Data Safety** - Be thorough and honest
7. **Copyright Issues** - Use only licensed assets

---

## 📝 Notes

- First review typically takes 3-7 days
- Subsequent updates are faster (1-2 days)
- Keep your signing key secure - you can't change it later!
- Enable app signing by Google Play for easier key management

**Good luck with your Play Store submission! 🎉**
