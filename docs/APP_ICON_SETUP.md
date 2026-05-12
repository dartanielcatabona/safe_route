# Adding the App Logo and Launcher Icons

Place the provided logo image in the repository at:

- `assets/images/app_logo.svg`

Then run:

```bash
cd c:\safe_route
flutter pub get
```

Display in-app
- The app's splash screen (`SplashScreen` in `lib/main.dart`) now uses `assets/images/app_logo.svg` automatically.

Launcher icons (optional)
- To generate platform launcher icons from this artwork, use `flutter_launcher_icons`.

1. Add to `pubspec.yaml` (example):

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.10.0

flutter_icons:
  android: true
  ios: true
  image_path: assets/images/app_logo.svg
```

2. Run:

```bash
flutter pub get
flutter pub run flutter_launcher_icons:main
```

Notes
- Use a square, high-resolution source (512x512 or 1024x1024) for the best results.
- If you want me to automatically wire `flutter_launcher_icons` into the project and run it here, I can attempt that (may require network access and time to run). 
