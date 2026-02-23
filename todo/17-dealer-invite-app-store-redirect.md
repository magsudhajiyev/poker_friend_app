# Dealer Invite Email - App Store Redirect

## Feature Request
Email sent for dealer invites should redirect users to Google Play or App Store to download the app.

## Current Behavior
- Dealer invite email sent with link
- Link may not properly redirect to app stores
- New users don't have clear path to download app

## Expected Behavior
- Email contains smart link that:
  - Detects device type (iOS/Android)
  - Redirects to appropriate app store
  - Falls back to web page if on desktop
- After app install, deep link opens invite redemption screen

## Implementation Options

### Option 1: Firebase Dynamic Links (Deprecated)
- Firebase Dynamic Links being deprecated
- Not recommended for new implementation

### Option 2: Custom Smart Link
- Create web page that detects device
- Redirects to appropriate store
- URL format: `https://yourapp.com/invite/{code}`

### Option 3: Branch.io or Similar
- Third-party deep linking service
- Handles app store detection and deferred deep links

### Option 4: Simple Platform Detection
- Web page with JavaScript device detection
- Direct links to both stores with auto-redirect

## Files to Modify
- Email template (Firebase Functions or backend)
- `lib/screens/redeem_invitation_screen.dart` - handle deep link
- Create landing page for app store redirect

## Additional Considerations
- Handle case where app already installed (open directly)
- Pass invite code through app store redirect
- Track invite conversions

## Priority
Medium
