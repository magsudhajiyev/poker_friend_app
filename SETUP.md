# Development Environment Setup for Final Table

## Required Tools & Versions

| Tool | Version | Install |
|------|---------|---------|
| **Flutter** | **3.38.10** (CRITICAL — do NOT use 3.41.x) | `git clone https://github.com/flutter/flutter.git -b 3.38.10` |
| **Dart** | 3.10.9 (bundled with Flutter) | Comes with Flutter |
| **Xcode** | 26.x (for iOS builds) | Mac App Store |
| **Android Studio** | Latest | https://developer.android.com/studio |
| **Android SDK** | 36.1.0 | Via Android Studio SDK Manager |
| **Java/JDK** | 17 or 21 (bundled with Android Studio) | Comes with Android Studio |
| **Kotlin** | 2.1.0 | Configured in project |
| **Gradle** | 8.12 | Auto-downloaded by project |
| **CocoaPods** | 1.16.x | `sudo gem install cocoapods` |
| **Ruby** | 2.6+ (macOS built-in works) | Pre-installed on macOS |
| **Node.js** | 25.x (optional, for backend) | `brew install node` |
| **Git** | 2.x | `brew install git` |

## iOS-Specific

- **Minimum iOS deployment target**: 15.5
- **iOS Simulator**: Use **iOS 18.5** runtime (Flutter 3.38 does NOT support iOS 26 simulators)
  - Download via Xcode → Settings → Platforms → iOS → Get
  - iPhone 16 Pro simulator recommended

## Android-Specific

- **compileSdk / targetSdk / minSdk**: Managed by Flutter (auto from `flutter.compileSdkVersion`)
- **NDK**: Managed by Flutter
- **Build files**: Kotlin DSL (`.gradle.kts`)
- **Debug keystore**: Each machine generates its own — SHA-1 must be registered in Firebase Console

## Step-by-Step Setup

```bash
# 1. Install Flutter 3.38.10
git clone https://github.com/flutter/flutter.git -b 3.38.10 ~/flutter
export PATH="$HOME/flutter/bin:$PATH"
# Add to ~/.zshrc permanently

# 2. Verify Flutter installation
flutter doctor -v

# 3. Clone the repo
git clone <repo-url>
cd poker_friend_app

# 4. Create .env file from template
cp .env.example .env
# Edit .env and fill in actual API keys

# 5. Get dependencies
flutter pub get

# 6. iOS setup (Mac only)
cd ios && pod install && cd ..

# 7. Run
flutter run --debug
```

## Environment Variables (.env)

Copy from `.env.example` and fill in real values:

| Key | Purpose | Where to get |
|-----|---------|--------------|
| `SONIOX_API_KEY` | Speech-to-text | https://soniox.com/ |
| `REVENUECAT_IOS_API_KEY` | iOS subscriptions | https://app.revenuecat.com/ |
| `REVENUECAT_ANDROID_API_KEY` | Android subscriptions | https://app.revenuecat.com/ |
| `RESEND_API_KEY` | Email sending (dealer invitations) | https://resend.com/ |
| `WEBSOCKET_SERVER_URL` | Real-time sync server | Local: `http://<your-ip>:8000` |
| `API_SERVER_URL` | REST API server | Local: `http://<your-ip>:8000` |
| `ENVIRONMENT` | App environment | `development` or `production` |

## Firebase Setup

The Firebase config files are already in the repo:
- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`

### Google Sign-In (Android)

Each machine's debug keystore has a unique SHA-1. It must be registered in Firebase Console for Google Sign-In to work:

```bash
# Get your debug keystore SHA-1
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
```

Then add the SHA-1 fingerprint in:
**Firebase Console → Project Settings → Your Apps → Android → Add fingerprint**

## Important Constraints

- **DO NOT upgrade Flutter to 3.41.x** — known Firestore write performance regression
- iOS 18.5 and iOS 26.1 simulator runtimes can coexist
- All Firebase/plugin dependencies are pinned to Flutter 3.38-compatible versions
- If you get `INSTALL_FAILED_UPDATE_INCOMPATIBLE` on Android, uninstall the app first (keystore mismatch)
