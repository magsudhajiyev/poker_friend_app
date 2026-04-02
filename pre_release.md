# Pre-Release Checklist

Items that must be updated before publishing to app stores.

## App Store URLs
- [ ] **iOS App Store URL** — Replace placeholder in `lib/services/club_request_service.dart` (`PLACEHOLDER_APP_STORE_URL`)
- [ ] **Google Play Store URL** — Verify URL in `lib/services/club_request_service.dart` (`com.pokerfriend.app` package ID)
- [ ] Update any existing clubs in Firestore that have placeholder QR URLs

## App Store Listings
- [ ] App screenshots for both platforms
- [ ] App description and keywords
- [ ] Privacy policy URL
- [ ] Terms of service URL

## Firebase
- [ ] Register production SHA-1 fingerprint for Google Sign-In (Android)
- [ ] Verify Firestore security rules for production
- [ ] Enable App Check for production

## RevenueCat
- [ ] Configure production entitlements
- [ ] Verify subscription products on both stores

## Other
- [ ] Remove debug print statements
- [ ] Remove dev user bypass in onboarding (`FELwuk4XbvdibPCx9NesqP5dRIn1`)
- [ ] Test full flow on both iOS and Android physical devices
