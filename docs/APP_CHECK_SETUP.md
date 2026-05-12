# Firebase App Check — Setup & Verification

This document explains the current App Check setup in this project and steps to verify and enable production App Check.

Summary
- The app initializes App Check in `lib/services/firebase_service.dart`.
- In debug builds the code activates the debug provider; in release builds it activates Play Integrity (Android) and App Attest (iOS).

Quick checks
1. Confirm `firebase_app_check` is listed in `pubspec.yaml` (it is).
2. Ensure the app calls `FirebaseService.initialize()` early on (it does in `lib/main.dart`).
3. To verify in logs look for: "Firebase App Check enabled with debug provider" or any initialization failure messages.

Developer (local) workflow
- For local testing the debug provider is enabled by the app in debug mode. To use debug tokens see Firebase docs and add the generated debug token to the App Check debug tokens in the Firebase console.
- If you still see "No AppCheckProvider installed" in logs, ensure the app successfully completes `Firebase.initializeApp()` and that the `firebase_app_check` plugin is included in `pubspec.yaml` and rebuilt.

Production checklist
1. Android:
   - Enable Play Integrity in the Firebase Console App Check settings.
   - Add app signing and upload keys as required by Play Integrity.
   - Add your app's SHA-256 fingerprints to the Firebase project (for debug and release as needed).
2. iOS:
   - Enable DeviceCheck / App Attest in Firebase Console App Check settings.
   - Follow Apple's requirements to register your app for App Attest.
3. Web (if applicable):
   - Configure reCAPTCHA v3 keys in Firebase Console.

Notes on enforcement
- When App Check is enforced in the console, all requests are validated by Firebase. If your app doesn't initialize App Check correctly, you'll see token errors and requests may be rejected. During development you can use the debug provider or temporarily unenforce App Check in the console (as you already did).

Troubleshooting
- If you see "Firebase App Check token is invalid" or recaptcha/internal errors:
  - Confirm App Check initialized before making Firebase calls.
  - Temporarily unenforce App Check in console while debugging.
  - Check native setup (Play Integrity/DeviceCheck) if you enabled a provider.

References
- Firebase App Check docs: https://firebase.google.com/docs/app-check

If you want, I can:
- Re-run `flutter analyze` and resolve the dependency conflicts shown during analysis.
- Add a sanity check early in `main()` to log App Check initialization state.
- Walk through the native Android/iOS setup steps and add the exact commands/files to modify.
