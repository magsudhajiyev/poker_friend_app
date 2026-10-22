import 'package:flutter/material.dart';

import '../onboarding/onboarding_prefs.dart';
import '../onboarding/onboarding_state.dart';
import '../services/feature_flag_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';

/// HARD PAYWALL GATE — the app-entry choke point for the hard paywall.
///
/// Wraps the app shell. When the `hard_paywall` flag is ON and the signed-in,
/// onboarded user has NO access, it shows the non-dismissible paywall instead
/// of [child]; the user must start a subscription (card on file to begin the
/// trial) to get in. It re-evaluates on every entitlement change (so a
/// just-purchased / just-restored user flows straight into the app, and a
/// trial-expired / cancelled user is caught on the next launch) and on flag
/// changes (so the gate can be switched on/off remotely).
///
/// FIRST-RUN ORDER (user decision): onboarding → guided tour → blocking
/// paywall → app. The gate therefore does NOT block until the user has
/// finished the first run (the post-tour paywall point,
/// [OnboardingPrefs.wasPostTourPaywallShown]); that first-run paywall is the
/// one made non-dismissible there. On every launch AFTER that, this gate is
/// the enforcement (trial expired, cancelled, reinstall, new device).
///
/// Step 6a scope: access = any active subscription ([SubscriptionService.
/// isPremium], which already folds in partner grants + the debug override).
/// The 30-day grace month for pre-launch accounts and the club-subscription
/// bypass are added in Step 6b at the single [_hasAccess] decision point.
///
/// When the flag is OFF the gate is transparent — it always shows [child].
class HardPaywallGate extends StatefulWidget {
  final Widget child;

  const HardPaywallGate({super.key, required this.child});

  /// The single access decision. Step 6b extends this (grace month, club sub).
  static bool _hasAccess() => SubscriptionService.isPremium;

  @override
  State<HardPaywallGate> createState() => _HardPaywallGateState();
}

class _HardPaywallGateState extends State<HardPaywallGate> {
  /// Whether the first run (onboarding + tour, up to the post-tour paywall)
  /// has completed. Until then the gate stays transparent so the tour runs.
  /// Null = still loading (don't block yet).
  bool? _firstRunDone;

  @override
  void initState() {
    super.initState();
    OnboardingPrefs.wasPostTourPaywallShown().then((shown) {
      if (mounted) setState(() => _firstRunDone = shown);
    });
  }

  bool _shouldBlock() =>
      _firstRunDone == true &&
      // NEVER block mid-tour: the guided first-hand tour navigates through the
      // app (tapping +, logging a hand…), and the hard wall must not interrupt
      // it. The tour runs its OWN non-dismissible paywall when it finishes
      // (maybeShowPostTourPaywall); after that isOnboardingActive is false and
      // this gate takes over for every later launch.
      !OnboardingState.isOnboardingActive &&
      FeatureFlagService.isEnabled(FeatureFlagService.hardPaywall) &&
      !HardPaywallGate._hasAccess();

  @override
  Widget build(BuildContext context) {
    // Rebuild when the flag changes…
    return ValueListenableBuilder<int>(
      valueListenable: FeatureFlagService.revision,
      builder: (context, _, __) {
        // …when the tour starts/ends…
        return ValueListenableBuilder<int>(
          valueListenable: OnboardingState.notifier,
          builder: (context, _, __) {
            // …and when the subscription status changes.
            return StreamBuilder<bool>(
              stream: SubscriptionService.premiumStatusStream,
              builder: (context, _) {
                if (_shouldBlock()) {
                  // Non-dismissible: no skip, no back, system back blocked.
                  // The paywall's own success flow updates the entitlement,
                  // which re-emits on premiumStatusStream and rebuilds this
                  // to [child].
                  return const PaywallScreen(hardGate: true);
                }
                return widget.child;
              },
            );
          },
        );
      },
    );
  }
}
