# TODO: Deep Link App-Not-Installed Handling

**Date**: 2026-02-19
**Status**: Pending
**Priority**: Medium

## Context

We implemented email-based dealer invitations with deep linking (`pkr://invite/{clubId}/{invitationId}`). Currently, when a user clicks the email link:
- If app is installed: App opens and auto-accepts invitation
- If app is NOT installed: Nothing happens (link fails silently)

## Required Work

### Option 1: Universal Links (Recommended)

1. **iOS - Associated Domains**
   - Add `apple-app-site-association` file to web server
   - Configure Associated Domains in Xcode
   - Use HTTPS URLs: `https://pokerlogger.app/invite/...`

2. **Android - App Links**
   - Add `assetlinks.json` to web server
   - Configure `autoVerify="true"` in AndroidManifest
   - Use HTTPS URLs

3. **Web Server**
   - Set up domain (e.g., pokerlogger.app)
   - Host apple-app-site-association and assetlinks.json
   - Create fallback web page for when app not installed

### Option 2: Fallback Web Page

1. Create simple landing page at `https://pokerlogger.app/invite/{clubId}/{invitationId}`
2. Page detects platform (iOS/Android)
3. Shows "Download from App Store / Play Store" buttons
4. Stores invitation parameters in URL for app to pick up after install

### Option 3: Firebase Dynamic Links (Deprecated)

Firebase Dynamic Links is being deprecated in August 2025. Not recommended for new implementations.

## Implementation Files

When implementing, update:
- `android/app/src/main/AndroidManifest.xml` - Add App Links verification
- `ios/Runner/Runner.entitlements` - Add Associated Domains
- `ios/Runner/Info.plist` - Add associated domains capability
- `lib/services/deep_link_service.dart` - Handle HTTPS URLs
- Web server configuration

## Current State

- Email sending: Working (Resend API)
- Deep linking: Working (pkr:// scheme)
- App-not-installed: Not handled

## References

- [Apple Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Android App Links](https://developer.android.com/training/app-links)
- [app_links package](https://pub.dev/packages/app_links)
