# Firebase Setup Guide for Poker Logger

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Name your project: `poker-logger` or similar
4. **Disable Google Analytics** (not needed for this app)
5. Click **"Create project"**

## Step 2: Add Flutter App to Firebase

### For Android:
1. In Firebase Console, click **"Add app"** → **Android**
2. **Android package name**: `com.example.poker_logger`
3. **App nickname**: `Poker Logger`
4. **Debug signing certificate SHA-1**: Leave empty for now
5. Click **"Register app"**
6. **Download** `google-services.json`
7. Place it in: `android/app/google-services.json`

### For iOS (optional):
1. Click **"Add app"** → **iOS**
2. **iOS bundle ID**: `com.example.pokerLogger`
3. **App nickname**: `Poker Logger`
4. Download `GoogleService-Info.plist`
5. Place it in: `ios/Runner/GoogleService-Info.plist`

## Step 3: Configure Android

### Edit `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

### Edit `android/app/build.gradle`:
Add at the **bottom** of the file:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## Step 4: Set Up Firestore Database

1. In Firebase Console, go to **"Firestore Database"**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (we'll secure it later)
4. Select your **region** (choose closest to your location)
5. Click **"Done"**

## Step 5: Configure Firestore Security Rules

In Firestore → **Rules** tab, replace with:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for poker hands
    match /poker_hands/{handId} {
      allow read, write: if true; // For now - we'll add auth later
    }
    
    // Allow read/write for poker sessions
    match /poker_sessions/{sessionId} {
      allow read, write: if true;
    }
  }
}
```

## Step 6: Update Flutter Dependencies

Run in your terminal:
```bash
flutter pub get
```

## Step 7: Initialize Firebase in Your App

The `main.dart` will need to be updated to initialize Firebase:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(PokerTrackerApp());
}
```

## Expected File Structure

After setup, you should have:
```
poker_logger/
├── android/
│   └── app/
│       └── google-services.json  ← Android config
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist  ← iOS config (optional)
├── lib/
│   └── ... (your Flutter code)
└── pubspec.yaml  ← Updated with Firebase deps
```

## Test Setup

To verify Firebase is working, we'll create a simple test in the next step that:
1. Connects to Firestore
2. Saves a test poker hand
3. Retrieves it back

## Firestore Data Structure (Planned)

```javascript
// Collection: poker_sessions
{
  "sessionId": "auto-generated",
  "blinds": "1/2",
  "playerCount": 6,
  "startTime": "timestamp",
  "endTime": "timestamp" // when session ends
}

// Collection: poker_hands  
{
  "handId": "auto-generated",
  "sessionId": "reference-to-session",
  "handNumber": 1,
  "buttonPosition": 1,
  "actions": [
    {
      "player": 4,
      "action": "bet",
      "street": "preflop",
      "timestamp": "2024-01-01T10:30:00Z"
    },
    // ... more actions
  ],
  "startTime": "timestamp",
  "endTime": "timestamp"
}
```

## Security Notes

- **Test mode** allows anyone to read/write - only for development
- For production, you'll want to add authentication
- Consider rate limiting and data validation rules

## Next Steps

1. Complete the setup above
2. Run `flutter pub get`
3. I'll help you create Firebase service classes to save/retrieve poker hands
4. Test the connection with a simple write/read operation

Let me know when you've completed these steps!