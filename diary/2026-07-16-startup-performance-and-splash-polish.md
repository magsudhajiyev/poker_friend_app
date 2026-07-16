# Startup Performance & Splash Polish

**Date**: 2026-07-16
**Branch**: design_v2

## Problem

1. **Slow startup**: App took ~3.5-4s from launch to home screen for returning users. The logo animation looped 2+ times before data was ready.
2. **Nav bar flash**: Bottom nav bar appeared for a single frame during the loading-to-home transition.
3. **Loading text slide-in**: "Loading your poker data" text slid in from the left (default MaterialPageRoute animation) and lagged.
4. **Logo position shift**: When the loading text faded in, the logo jumped upward because it was in a `Column` layout with the text.

## Root Causes

### Redundant Firestore reads
The `users/{uid}` document was read **4 separate times** during startup:
1. `AuthService.ensureUserDocument()` — checks if doc exists
2. `UsernameService.hasCompletedUsernameSetup()` — reads `hasSetUsername` field
3. `OnboardingService.hasCompletedOnboarding()` — reads `hasCompletedOnboarding` field
4. `BankrollService.syncFromFirestore()` — reads bankroll fields

Each read is ~200ms on a warm Firestore connection, totaling ~800ms of sequential I/O for the same document.

### Sequential AuthWrapper gates
AuthWrapper used two nested `FutureBuilder` widgets — the onboarding future was only created *after* the username future completed, adding unnecessary serialization.

### Video controller re-initialization
`LoopingSplashLogo` created a new `VideoPlayerController` in each widget instance. Transitioning SplashScreen → AuthWrapper → HomeScreen re-initialized the video 3 times (~200-400ms each).

### Sequential SharedPreferences reads
`main()` awaited 4 service inits (`LocaleService`, `CurrencyService`, `SkipHandScoutingService`, `FeatureFlagService`) sequentially before `runApp()`.

### Layout shift
Loading screen used a `Column` with `Expanded` logo + text below. When text faded in, it claimed space and pushed the logo upward.

## Fixes

### 1. User document prefetch (`splash_screen.dart`, `auth_service.dart`)
- Added `AuthService.prefetchUserDocument()` — fetches and caches the user doc as a `Map<String, dynamic>`.
- SplashScreen calls `prefetchUserDocument()` as soon as auth resolves, running **in parallel** with the video loop (free time).
- `ensureUserDocument()`, `hasCompletedUsernameSetup()`, `hasCompletedOnboarding()`, and `syncFromFirestore()` all check the prefetch cache first, avoiding redundant Firestore reads.
- Cache is cleared by HomeScreen after loading completes (`AuthService.clearPrefetchedUserDoc()`).

### 2. Combined AuthWrapper gate (`auth_wrapper.dart`)
- Replaced two nested `FutureBuilder<bool>` with a single `FutureBuilder<String>` that runs username + onboarding checks **in parallel** via `Future.wait()`.
- Returns route key: `'home'`, `'onboarding_skip'`, or `'onboarding_full'`.

### 3. Shared video controller (`looping_splash_logo.dart`)
- Rewrote to use a **static shared** `VideoPlayerController` that initializes once and persists across all screen transitions.
- `warmUp()` static method kicked off from `main()` before `runApp()` so the video is ready by the time SplashScreen mounts.
- `releaseShared()` called by HomeScreen after loading finishes to free video memory.

### 4. Parallel SharedPreferences init (`main.dart`)
- Changed 4 sequential `await` calls to `Future.wait()` — all 4 reads run in parallel.
- Added `unawaited(LoopingSplashLogo.warmUp())` after Firebase init.

### 5. Nav bar starts hidden (`main_shell.dart`)
- Changed `_navVisible` initial value from `true` to `false`.
- HomeScreen restores nav visibility after data loads (was already doing this).

### 6. Smooth transitions (`home_screen.dart`)
- SplashScreen → AuthWrapper uses standard `MaterialPageRoute` (crossfade via `PageRouteBuilder` was tried but reverted — see `diary/2026-07-16-system-back-button-and-pageroute-reload-bug.md`).
- Loading text uses `_LoadingLabel` widget with a dedicated `AnimationController` — pure 600ms fade with 150ms delay, no translate.

### 7. Logo position stability (`home_screen.dart`)
- Changed loading screen from `Column` layout (logo + text stacked) to `Stack` layout.
- Logo stays centered via its own `Center` widget; text is `Positioned` at the bottom.
- Text fade-in no longer causes any layout shift.

## Files Changed

| File | Change |
|---|---|
| `lib/main.dart` | Parallel SharedPrefs init, video warm-up |
| `lib/widgets/looping_splash_logo.dart` | Shared static VideoPlayerController |
| `lib/screens/splash_screen.dart` | Prefetch user doc on auth resolve, crossfade transition |
| `lib/screens/auth_wrapper.dart` | Combined startup gate, single FutureBuilder |
| `lib/screens/home_screen.dart` | Stack layout for loading, release shared resources, clear prefetch |
| `lib/widgets/main_shell.dart` | Nav bar starts hidden |
| `lib/services/auth_service.dart` | Prefetch user document cache |
| `lib/services/username_service.dart` | Read from prefetch cache |
| `lib/services/onboarding_service.dart` | Read from prefetch cache |
| `lib/services/bankroll_service.dart` | Read from prefetch cache |

## Performance Impact

| Phase | Before | After |
|---|---|---|
| `main()` pre-runApp | ~350ms (sequential) | ~300ms (parallel) |
| SplashScreen | ~2s (video loop, idle) | ~2s (video loop + prefetch user doc) |
| AuthWrapper gates | ~600ms (3 sequential Firestore reads) | ~5ms (cached) |
| HomeScreen bankroll sync | ~200ms (Firestore read) | ~5ms (cached) |
| **Total cold start** | **~3.5s** | **~2.5s** |

Target: everything ready within 2nd video loop cycle (~4s). Achieved with ~1s margin.
