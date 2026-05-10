# SmartCityEmergencySystem

Real-time smart city emergency response platform for locating hospitals, checking live bed availability, and requesting emergency services.

## Project Layout

- `frontend_flutter/`: Flutter application (Material UI, Firebase Auth, Firestore, FCM, Google Maps, live hospital/ambulance markers)
- `backend_firebase/`: Firebase backend artifacts (Firestore schema JSON, Cloud Functions, Firestore security rules)

## Run the Flutter frontend

1. Open a terminal in:
   `SmartCityEmergencySystem/frontend_flutter`
2. Install dependencies:
   `flutter pub get`
3. Run the app:
   `flutter run`

> Note: You must also configure Firebase for your Flutter app (Android `google-services.json` and iOS `GoogleService-Info.plist`) for authentication, Firestore, and FCM to work.

## Firebase setup (required)

1. Create a Firebase project at https://console.firebase.google.com/
2. Enable services:
   - Authentication
     - Enable **Email/Password**
   - Firestore Database
     - Create it in production mode when ready
   - Cloud Messaging (FCM)
3. Add Firebase config files to the Flutter app (recommended: via FlutterFire):
   - For Android, download `google-services.json` from Firebase console and place it in:
     `android/app/google-services.json`
   - For iOS, download `GoogleService-Info.plist` and place it in:
     `ios/Runner/GoogleService-Info.plist`
4. Generate `firebase_options.dart` (required for Web and to avoid runtime init issues):
   - From `frontend_flutter/`, run:
     - `flutterfire configure --project=<YOUR_FIREBASE_PROJECT_ID> --platforms=android,ios,web`
   - This will create/overwrite:
     - `lib/firebase_options.dart`
     - Android/iOS config files
     - Web files for Firebase + FCM

5. Configure FCM:
   - Deploy security rules:
   - In Firebase CLI:
     - `firebase deploy --only firestore:rules`
   - Use `backend_firebase/firebase_rules.txt` as the rules source.

6. Google Maps API keys (required for `google_maps_flutter`):
   - Android: update `android/app/src/main/AndroidManifest.xml`
     - Replace `YOUR_GOOGLE_MAPS_API_KEY_ANDROID`
   - iOS: update `ios/Runner/AppDelegate.swift`
     - Replace `YOUR_GOOGLE_MAPS_API_KEY_IOS`
   - Web: update `web/index.html`
     - Replace `YOUR_GOOGLE_MAPS_API_KEY_WEB` in the Google Maps script tag.

7. Location permissions:
   - Android/iOS/web are configured for runtime permission via `geolocator`.
   - This repo includes baseline location permission keys in Android/iOS manifests/files; ensure they match your app name and store policy.

8. Deploy Cloud Functions:
   - In `backend_firebase/`, create/initialize a Firebase Functions project (if you don't have one yet):
     - `firebase init functions`
   - Copy `cloud_functions.js` into your functions `index.js` (or point `main` to it)
   - Deploy:
     - `firebase deploy --only functions`

## Firestore data format expected

The app expects (collection names):

- `users/{userId}`: `name`, `phone`, `role`, `fcmToken` (optional)
- `hospitals/{hospitalId}`: `name`, `location{latitude,longitude}`, `totalBeds`, `availableBeds`, `icuBeds`, `ownerUserId`
- `ambulances/{ambulanceId}`: `driverName`, `location{latitude,longitude}`, `status`, `assignedRequestId` (optional)
- `requests/{requestId}`: `userId`, `hospitalId`, `ambulanceId` (optional), `status`, `timestamp`, `userLocation{latitude,longitude}`, `message` (optional)

## How emergency works

1. User presses the panic button on `EmergencyScreen`.
2. App requests the user's location and calculates the nearest hospital.
3. App creates a document in `requests/`.
4. Cloud Function `onRequestCreated`:
   - Ensures nearest hospital is set (idempotent if already present)
   - Picks the nearest available ambulance
   - Updates `requests` status and assigns `ambulanceId`
   - Sends FCM notifications to the requester

## Suggested improvements (next steps)

- Add geospatial queries (e.g., GeoFirestore/H3) to avoid loading all hospitals/ambulances client-side
- Use transactions/locks for ambulance assignment to prevent double-booking under high traffic
- Add role-based hospital/admin UIs for updating bed counts and ambulance locations
- Add better notification deep-link handling (open the Home tab + switch to a sub-screen)

## Running on Android, iOS, and Web

1. Android (requires Android Studio/SDK):
   - `flutter run -d <android_device>`
2. Web:
   - `flutter run -d chrome`
   - or production build: `flutter build web`
3. iOS (requires macOS + Xcode):
   - `flutter run -d <ios_device>`

