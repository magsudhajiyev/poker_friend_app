# Xiaomi Battery Optimization Troubleshooting Guide

**Priority:** Low
**Status:** Todo
**Added:** 2026-02-26

## Context

Users on Xiaomi/MIUI devices experience network issues due to aggressive battery optimization:
- DNS resolution failures to `firestore.googleapis.com`
- Firebase connections dropping
- Previously caused random logouts (now fixed with auth resilience)

## Current Mitigations (Already Implemented)

1. ✅ Auth state resilience (prevents random logout during network glitches)
2. ✅ Firestore offline persistence (queues writes, syncs when connected)
3. ✅ FCM fire-and-forget pattern (non-blocking notifications)

## Proposed Enhancement

Add an optional troubleshooting screen that:
1. Detects Xiaomi/MIUI devices using `device_info_plus`
2. Shows instructions to disable battery optimization manually
3. Opens device settings with a button

## Why Not Request Permission Automatically?

**Google Play would reject the app.**

The `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission is restricted to:
- VoIP/calling apps
- IoT device companions
- Peripheral apps

A poker app doesn't qualify. Apps using this permission without approval get rejected for "Device and Network Abuse policy violation."

## Implementation Notes

### Option A: Simple Settings Link
```dart
// Open battery optimization settings (allowed by Google Play)
final intent = AndroidIntent(
  action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
);
await intent.launch();
```

### Option B: Use dontkillmyapp.com Library
- Library: `doki` (doubledotlabs/doki)
- Shows manufacturer-specific instructions automatically
- Includes Xiaomi-specific steps

### Where to Add
- Settings screen → "Troubleshooting" section
- Or separate "Connection Issues?" button that appears only on Xiaomi devices

## References

- https://dontkillmyapp.com/xiaomi
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://support.google.com/googleplay/android-developer/thread/255896306

## Decision

Skip for now. The auth resilience and offline persistence fixes already handle the main issues. This enhancement can be added later if users continue to report problems.
