import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../l10n/app_localizations.dart';
import '../screens/paywall_screen.dart';
import '../screens/auth_screen_experimental.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import 'onboarding_prefs.dart';
import 'onboarding_state.dart';
import '../design_system/constants/decorations.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

TutorialCoachMark createOnboardingCoachMark({
  required List<TargetFocus> targets,
  required VoidCallback onFinish,
  VoidCallback? onSkip,
  required BuildContext context,
  bool hideSkip = false,
  bool showSkipInLastTarget = true,
}) {
  final l10n = AppLocalizations.of(context);
  return TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.85,
    paddingFocus: 12,
    hideSkip: hideSkip,
    showSkipInLastTarget: showSkipInLastTarget,
    // Bottom-center so it never overlaps tooltips (which now render centered).
    alignSkip: Alignment.bottomCenter,
    skipWidget: Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(
              l10n.onboardingSkipTour,
              style: AppTypography.bodySmall(color: Colors.white70)
                  .copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(height: 12),
          const _TourProgressIndicator(),
        ],
      ),
    ),
    onSkip: () {
      final wasReplay = OnboardingState.isReplay;
      OnboardingState.cancel();
      OnboardingPrefs.markOnboardingSeen();
      if (!wasReplay) {
        // Kill-safety first: if the app dies before the paywall below gets
        // shown, the next Home visit recovers it via the pending flag.
        OnboardingPrefs.setPostTourPaywallPending();
        // Then show the paywall right away, over whatever screen the skip
        // happened on (launch-promo variant included when the free month
        // is live). Small delay lets the overlay dismiss cleanly.
        Future.delayed(const Duration(milliseconds: 350), () {
          if (context.mounted) maybeShowPostTourPaywall(context);
        });
      }
      onSkip?.call();
      return true;
    },
    onFinish: onFinish,
  );
}

Widget buildWelcomeCard({required VoidCallback onNext, required BuildContext context}) {
  final l10n = AppLocalizations.of(context);
  return Container(
    padding: const EdgeInsets.all(28),
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(AppDecorations.radius20),
      border: Border.all(
        color: AppColors.accentPrimary.withValues(alpha: 0.15),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentPrimary.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.onboardingWelcomeTitle,
          style: AppTypography.pageTitle().copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingWelcomeBody,
          style: AppTypography.bodySmall(
            color: Colors.white.withValues(alpha: 0.8),
          ).copyWith(fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
            ),
            child: Text(
              l10n.onboardingLetsGo,
              style: AppTypography.bodyLarge(color: Colors.black).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildTooltip({
  required String title,
  required String body,
  required VoidCallback onNext,
  required BuildContext context,
  bool isLast = false,
}) {
  final l10n = AppLocalizations.of(context);
  final screenW = MediaQuery.of(context).size.width;
  // Scale factor: 1.0 on iPhone 16 Pro (393pt), smaller on smaller devices
  final scale = (screenW / 393).clamp(0.8, 1.1);
  final pad = (20 * scale).roundToDouble();
  final margin = (20 * scale).roundToDouble();
  final titleSize = (18 * scale).clamp(15.0, 20.0);
  final bodySize = (14 * scale).clamp(12.0, 16.0);
  final btnSize = (15 * scale).clamp(13.0, 17.0);

  return Container(
    padding: EdgeInsets.all(pad),
    margin: EdgeInsets.symmetric(horizontal: margin),
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      border: Border.all(
        color: AppColors.accentPrimary.withValues(alpha: 0.15),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentPrimary.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.bodyLarge(color: Colors.white).copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          body,
          style: AppTypography.bodySmall(
            color: Colors.white.withValues(alpha: 0.8),
          ).copyWith(fontSize: bodySize, height: 1.5),
        ),
        SizedBox(height: 12 * scale),
        Align(
          alignment: isLast ? Alignment.center : Alignment.centerRight,
          child: GestureDetector(
            onTap: onNext,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 7 * scale,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              child: Text(
                isLast ? l10n.onboardingGotIt : l10n.onboardingNext,
                style: AppTypography.bodyLarge(color: AppColors.accentPrimary)
                    .copyWith(fontSize: btnSize, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Centered-modal tooltip content for a [TargetFocus]. Always renders the
/// tooltip at the vertical center of the screen with safe insets — 24px
/// below the status bar and 140px reserved at the bottom for the Skip pill.
/// Use in place of `TargetContent(align: ContentAlign.top/bottom, ...)`
/// so tooltips never spill off-screen on smaller viewports.
TargetContent centeredTooltipContent(
  Widget Function(BuildContext, TutorialCoachMarkController) builder,
) {
  return TargetContent(
    align: ContentAlign.custom,
    customPosition: CustomTargetContentPosition(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
    ),
    builder: (context, controller) => SafeArea(
      minimum: const EdgeInsets.only(top: 24, bottom: 140),
      child: Center(child: builder(context, controller)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Phase 0 — Home Screen Tour
// ---------------------------------------------------------------------------

class HomeTour {
  final GlobalKey fabKey;

  HomeTour({required this.fabKey});

  void show(BuildContext context) {
    final targets = <TargetFocus>[];

    // Step 0 — Welcome (no spotlight)
    targets.add(
      TargetFocus(
        identify: 'welcome',
        targetPosition: TargetPosition(
          const Size(0, 0),
          const Offset(-1000, -1000),
        ),
        shape: ShapeLightFocus.Circle,
        radius: 0,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: MediaQueryData.fromView(
                WidgetsBinding.instance.platformDispatcher.views.first,
              ).size.height *
                  0.3,
            ),
            builder: (context, controller) {
              return buildWelcomeCard(onNext: () => controller.next(), context: context);
            },
          ),
        ],
      ),
    );

    // Step 1 — FAB highlight
    if (fabKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'fab',
          keyTarget: fabKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 8,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingStartLoggingTitle,
                  body: l10n.onboardingStartLoggingBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) return;

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.advanceTo(1);
      },
    );
    coach.show(context: context);
  }

  static Future<void> resetAndShow(
    BuildContext context, {
    required GlobalKey fabKey,
  }) async {
    await OnboardingPrefs.resetOnboarding();
    OnboardingState.start();
    HomeTour(fabKey: fabKey).show(context);
  }
}

// ---------------------------------------------------------------------------
// Phase 1 — Logging Mode Selection Tour
// ---------------------------------------------------------------------------

class LoggingModeTour {
  final GlobalKey fullModeCardKey;

  LoggingModeTour({
    required this.fullModeCardKey,
  });

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 1) return;

    final targets = <TargetFocus>[];

    if (fullModeCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'full_mode',
          keyTarget: fullModeCardKey,
          shape: ShapeLightFocus.RRect,
          radius: AppDecorations.radiusXl,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingFullModeTitle,
                  body: l10n.onboardingFullModeBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) return;

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.advanceTo(2);
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 2 — Session Setup Tour (highlights session form fields)
// ---------------------------------------------------------------------------

class SessionSetupTour {
  final VoidCallback? onFinished;

  SessionSetupTour({this.onFinished});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 2) return;

    final targets = <TargetFocus>[];

    // No-spotlight instruction card centered on screen
    targets.add(
      TargetFocus(
        identify: 'session_setup',
        targetPosition: TargetPosition(
          const Size(0, 0),
          const Offset(-1000, -1000),
        ),
        shape: ShapeLightFocus.Circle,
        radius: 0,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: MediaQueryData.fromView(
                WidgetsBinding.instance.platformDispatcher.views.first,
              ).size.height *
                  0.3,
            ),
            builder: (context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.onboardingSessionSetupTitle,
                body: l10n.onboardingSessionSetupBody,
                onNext: () => controller.next(),
                context: context,
              );
            },
          ),
        ],
      ),
    );

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        // Mark table tour pending and notify the screen
        OnboardingState.tableTourPending = true;
        onFinished?.call();
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 3 — Table Setup Tour (highlights poker table)
// ---------------------------------------------------------------------------

class SeatSetupTour {
  final GlobalKey tableKey;

  SeatSetupTour({required this.tableKey});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3) return;

    final targets = <TargetFocus>[];

    if (tableKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'table',
          keyTarget: tableKey,
          shape: ShapeLightFocus.RRect,
          radius: 24,
          paddingFocus: 0,
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(top: 80),
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingTableSetupTitle,
                  body: l10n.onboardingTableSetupBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) return;

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.advanceTo(4);
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 3b — Seat Dialog Tour (runs inside the bottom sheet)
// ---------------------------------------------------------------------------

class SeatDialogTour {
  final GlobalKey seatToggleKey;
  final GlobalKey mySeatKey;
  final GlobalKey playerNameKey;
  final GlobalKey saveOpponentKey;

  SeatDialogTour({
    required this.seatToggleKey,
    required this.mySeatKey,
    required this.playerNameKey,
    required this.saveOpponentKey,
  });

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3 ||
        !OnboardingState.seatDialogTourPending) return;

    final targets = <TargetFocus>[];

    if (seatToggleKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'seat_toggle',
          keyTarget: seatToggleKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 8,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingSeatOpenTitle,
                  body: l10n.onboardingSeatOpenBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (mySeatKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'my_seat',
          keyTarget: mySeatKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 8,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingThisIsMySeatTitle,
                  body: l10n.onboardingThisIsMySeatBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (playerNameKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'player_name',
          keyTarget: playerNameKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingPlayerNameTitle,
                  body: l10n.onboardingPlayerNameBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (saveOpponentKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'save_opponent',
          keyTarget: saveOpponentKey,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingSaveOpponentTitle,
                  body: l10n.onboardingSaveOpponentBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      OnboardingState.seatDialogTourPending = false;
      OnboardingState.buttonTokenTourPending = true;
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.seatDialogTourPending = false;
        OnboardingState.buttonTokenTourPending = true;
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 3c — Button Token Tour (after seat dialog, before advancing)
// ---------------------------------------------------------------------------

class ButtonTokenTour {
  final GlobalKey buttonTokenKey;

  ButtonTokenTour({required this.buttonTokenKey});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3) return;

    final targets = <TargetFocus>[];

    if (buttonTokenKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'button_token',
          keyTarget: buttonTokenKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 16,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingDealerButtonTitle,
                  body: l10n.onboardingDealerButtonBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      OnboardingState.advanceTo(4);
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.advanceTo(4);
      },
    );
    coach.show(context: context);
  }
}

// Phase 4 — Hand Logging Tour is now handled by GuidedHandOverlay
// (see lib/onboarding/guided_hand_overlay.dart)

// ---------------------------------------------------------------------------
// Tour completion — shared by the phase-6 end and every phase-5/6 fallback
// ---------------------------------------------------------------------------

/// Ends the tour: completion dialog, then — for a guest — required sign-up and
/// the onboarding questions, then (once ever) the skippable post-tour paywall,
/// then a clean reset to Home. The tour can end several screens deep.
///
/// Guest funnel (value-first): the anonymous user experienced the tour first;
/// only now do we ask them to create an account (hard gate), answer the
/// onboarding questions, and see the paywall. A user who already had an account
/// before the tour keeps the original behavior (dialog → paywall → Home).
Future<void> finishOnboardingTour(BuildContext context) async {
  OnboardingState.complete();
  OnboardingPrefs.markOnboardingSeen();
  OnboardingPrefs.setBankrollTourPending();

  final isGuest = AuthService.isAnonymous && !OnboardingState.isReplay;
  if (isGuest) {
    // Persist the sign-up requirement NOW — before the dialog — so that if the
    // guest kills the app at any point after the tour, the next launch forces
    // them back into sign-up (AuthWrapper → GuestSignupGate) instead of letting
    // them keep using the app as a guest.
    await OnboardingPrefs.setPostTourSignupRequired();
  }

  if (isGuest) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OnboardingCompleteDialog(
        onDone: () {},
      ),
    );
    if (!context.mounted) return;
    // Required sign-up → questions → paywall → Home (same chain used on relaunch).
    await completeGuestSignup(context);
    return;
  }

  // Non-guest: the tour's final beats — bankroll step → "you're done" dialog
  // → paywall — run ON Home (the bankroll card lives there). Persist the
  // pending flag first so an app kill can't lose the wrap-up, then reset to
  // Home where HomeScreen picks it up (bankroll tip → showPostTourWrapUp).
  await OnboardingPrefs.setPostTourWrapUpPending();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}

/// Launch promo detection: true when this user was auto-granted the free Pro
/// month at sign-up (users-doc marker written by the grantFreeMonthOnSignup
/// Cloud Function) AND the RevenueCat 'pro' entitlement is actually live.
/// Also schedules the courtesy expiry reminders. Any failure → false, which
/// just means the normal paywall — never a broken state.
Future<bool> _detectLaunchPromo(BuildContext context) async {
  try {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.data()?['freeMonthGranted'] != true) return false;

    // Confirm the grant landed in RevenueCat (expiry lives on RC's servers —
    // the client never computes it).
    await SubscriptionService.refreshOnResume();
    final entitlement = SubscriptionService
        .customerInfo?.entitlements.all[SubscriptionService.premiumEntitlement];
    if (entitlement?.isActive != true) return false;

    if (context.mounted) _schedulePromoReminders(context, entitlement!);
    return true;
  } catch (_) {
    return false;
  }
}

/// Heal-on-open resync of the free-month expiry reminders ("1 day left" +
/// "has ended"). Local notifications are only as good as their scheduling
/// moment — if the app died before the post-tour paywall scheduled them,
/// they'd never fire. Called from Home on startup; idempotent (fixed
/// notification ids, cancelled before rescheduling). Cancels the reminders
/// outright when the promo is no longer the active entitlement (expired, or
/// superseded by a PAID subscription — a "free month ends tomorrow" reminder
/// would be wrong either way).
Future<void> syncPromoExpiryReminders(BuildContext context) async {
  try {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.data()?['freeMonthGranted'] != true) return;

    final entitlement = SubscriptionService
        .customerInfo?.entitlements.all[SubscriptionService.premiumEntitlement];
    final promoActive = entitlement?.isActive == true &&
        entitlement?.store == Store.promotional;
    if (!promoActive) {
      await NotificationService.cancelPromoExpiryReminders();
      return;
    }
    if (context.mounted) _schedulePromoReminders(context, entitlement!);
  } catch (_) {}
}

void _schedulePromoReminders(BuildContext context, EntitlementInfo entitlement) {
  final expiresAt = DateTime.tryParse(entitlement.expirationDate ?? '');
  if (expiresAt == null) return;
  final l10n = AppLocalizations.of(context);
  unawaited(NotificationService.schedulePromoExpiryReminders(
    expiresAt: expiresAt.toLocal(),
    warnTitle: l10n.promoNotifWarnTitle,
    warnBody: l10n.promoNotifWarnBody,
    endedTitle: l10n.promoNotifEndedTitle,
    endedBody: l10n.promoNotifEndedBody,
  ));
}

/// Shows the post-tour paywall AT MOST ONCE EVER — shared by the tour
/// completion wrap-up, the skip paths (coach-mark skip + mid-hand skip), and
/// Home's deferred-pending recovery. Applies the launch-promo variant
/// (celebration dialog + "1 MONTH FREE" badge on Pro monthly) when the free
/// Pro month is live. Clears the deferred-pending flag since the paywall is
/// being handled now.
Future<void> maybeShowPostTourPaywall(BuildContext context) async {
  if (await OnboardingPrefs.wasPostTourPaywallShown()) return;
  await OnboardingPrefs.markPostTourPaywallShown();
  await OnboardingPrefs.clearPostTourPaywallPending();
  if (!context.mounted) return;
  final launchPromo = await _detectLaunchPromo(context);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(showSkip: true, launchPromo: launchPromo),
    ),
  );
}

/// Post-tour wrap-up, run on Home AFTER the bankroll-card step: the
/// "you're done" completion dialog, then the skippable paywall (at most
/// once ever).
Future<void> showPostTourWrapUp(BuildContext context) async {
  await OnboardingPrefs.clearPostTourWrapUpPending();
  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OnboardingCompleteDialog(
      onDone: () {},
    ),
  );
  if (!context.mounted) return;

  await maybeShowPostTourPaywall(context);
}

/// The mandatory guest sign-up chain: hard-gate sign-up → onboarding questions
/// → skippable paywall → Home. Run at tour completion (for a guest) and again
/// on app relaunch if the guest killed the app before linking (GuestSignupGate).
Future<void> completeGuestSignup(BuildContext context) async {
  // 1. Required sign-up (hard gate). canDismiss:false → the screen can only
  //    leave via a successful link (pops `true`) or, on a credential conflict,
  //    by signing into the existing account (which resets the stack, unmounting
  //    `context` — handled by the mounted checks below).
  final linked = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AuthScreenExperimental(
        linkMode: true,
        canDismiss: false,
      ),
    ),
  );
  if (!context.mounted) return;

  if (linked == true) {
    // Account created — drop the relaunch gate.
    await OnboardingPrefs.clearPostTourSignupRequired();
    if (!context.mounted) return;

    // 2. Onboarding questions. skipNickname:false so the nickname step writes
    //    hasSetUsername:true (linking alone doesn't) — otherwise the final
    //    return to '/' would re-route back into OnboardingFlow. popOnComplete
    //    pops back here so we can continue to the paywall.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingFlow(
          skipNickname: false,
          popOnComplete: true,
        ),
      ),
    );
    if (!context.mounted) return;

    // 3. Skippable paywall (at most once ever).
    await maybeShowPostTourPaywall(context);
  }

  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}

/// Shown by AuthWrapper when an anonymous user who has already finished the tour
/// relaunches the app: immediately (re-)presents the mandatory guest sign-up so
/// a guest can't bypass it by killing and reopening the app.
class GuestSignupGate extends StatefulWidget {
  const GuestSignupGate({super.key});

  @override
  State<GuestSignupGate> createState() => _GuestSignupGateState();
}

class _GuestSignupGateState extends State<GuestSignupGate> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started || !mounted) return;
      _started = true;
      completeGuestSignup(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accentPrimary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 5 — Session Result Tour (on home screen after session ends)
// ---------------------------------------------------------------------------

class SessionResultTour {
  final GlobalKey sessionsNavKey;
  final VoidCallback? onComplete;

  SessionResultTour({required this.sessionsNavKey, this.onComplete});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 5) return;

    final targets = <TargetFocus>[];

    if (sessionsNavKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'sessions_nav',
          keyTarget: sessionsNavKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 8,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingViewSessionsTitle,
                  body: l10n.onboardingViewSessionsBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      finishOnboardingTour(context);
      onComplete?.call();
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        // Hand off to phase 6: the user now taps the real Sessions icon,
        // and SessionHistoryScreen picks the tour up via notifier listener.
        // Set the pending flag BEFORE advanceTo — advanceTo fires the
        // notifier synchronously, so the listener must see the flag.
        OnboardingState.sessionHistoryTourPending = true;
        OnboardingState.advanceTo(6);
        onComplete?.call();
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 6a — Session History Tour (spotlights the tutorial session card)
// ---------------------------------------------------------------------------

class SessionHistoryTour {
  final GlobalKey sessionCardKey;

  SessionHistoryTour({required this.sessionCardKey});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6) return;

    final targets = <TargetFocus>[];

    if (sessionCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'tour_session_card',
          keyTarget: sessionCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingSessionHistoryCardTitle,
                  body: l10n.onboardingSessionHistoryCardBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      finishOnboardingTour(context);
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        // User now taps the real session card; SessionAnalyticsScreen
        // continues the tour on its hand list.
        OnboardingState.handListTourPending = true;
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 6b — Hand List Tour (spotlights "View Logged Hands" in analytics)
// ---------------------------------------------------------------------------

class HandListTour {
  final GlobalKey loggedHandsButtonKey;
  final GlobalKey? stackChartKey;

  HandListTour({required this.loggedHandsButtonKey, this.stackChartKey});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6) return;

    final targets = <TargetFocus>[];

    // Step 1 — the stack chart (this is the "see how your session went" moment)
    if (stackChartKey?.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'stack_chart',
          keyTarget: stackChartKey!,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          paddingFocus: 6,
          contents: [
            TargetContent(
              // Pin near the top so the card stays visible — the chart sits
              // low on screen and a bottom/attached card would clip off.
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(
                top: MediaQueryData.fromView(
                  WidgetsBinding.instance.platformDispatcher.views.first,
                ).size.height *
                    0.12,
              ),
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.guidedStackChartTitle,
                  body: l10n.guidedStackChartBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    // Step 2 — the "View Logged Hands" button
    if (loggedHandsButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'logged_hands_button',
          keyTarget: loggedHandsButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 26,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingHandListTitle,
                  body: l10n.onboardingHandListBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      finishOnboardingTour(context);
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      showSkipInLastTarget: false,
      onFinish: () {
        // User now taps the real button; SessionHandsScreen continues the
        // tour on the first hand card.
        OnboardingState.handCardTourPending = true;
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 6c — Hand Card Tour (inside the logged hands list)
// ---------------------------------------------------------------------------

class HandCardTour {
  final GlobalKey handCardKey;

  HandCardTour({required this.handCardKey});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6) return;

    final targets = <TargetFocus>[];

    if (handCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'tour_hand_card',
          keyTarget: handCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingHandCardTitle,
                  body: l10n.onboardingHandCardBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      finishOnboardingTour(context);
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        // User now taps the real hand card; HandActionsScreen continues
        // the tour on the AI analysis button.
        OnboardingState.aiAnalysisTourPending = true;
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 6d — Hand Tools Tour (inside hand details, before AI analysis)
// ---------------------------------------------------------------------------

/// Explains the BB / export / share / star buttons all at once by spotlighting
/// the whole tools row, then hands off to the AI analysis step via [onNext].
class HandToolsTour {
  final GlobalKey toolsRowKey;

  HandToolsTour({required this.toolsRowKey});

  void show(BuildContext context, {required VoidCallback onNext}) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6) {
      return;
    }

    if (toolsRowKey.currentContext == null) {
      onNext();
      return;
    }

    _showCoachMark(context, onFinish: onNext);
  }

  void _showCoachMark(BuildContext context, {required VoidCallback onFinish}) {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'hand_tools_row',
        keyTarget: toolsRowKey,
        shape: ShapeLightFocus.RRect,
        radius: 24,
        paddingFocus: 4,
        contents: [
          centeredTooltipContent((context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.onboardingHandToolsTitle,
                body: l10n.onboardingHandToolsBody,
                onNext: () => controller.next(),
                context: context,
              );
            },
          ),
        ],
      ),
    ];

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: onFinish,
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 6e — AI Analysis Tour (inside hand details)
// ---------------------------------------------------------------------------

class AiAnalysisTour {
  final GlobalKey aiButtonKey;

  AiAnalysisTour({required this.aiButtonKey});

  /// [onAnalyze] runs the free tour analysis; the caller ends the tour with
  /// [finishOnboardingTour] once the analysis has been shown.
  void show(BuildContext context, {required VoidCallback onAnalyze}) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6) return;

    final targets = <TargetFocus>[];

    if (aiButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'ai_analysis_button',
          keyTarget: aiButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          paddingFocus: 4,
          contents: [
            centeredTooltipContent((context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingAiAnalysisTitle,
                  body: l10n.onboardingAiAnalysisBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      // No spotlight possible — defer completion to when the user leaves the
      // hand-details screen (SessionHandsScreen runs finishOnboardingTour).
      OnboardingState.tourCompletionPending = true;
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      context: context,
      onFinish: onAnalyze,
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Completion Dialog
// ---------------------------------------------------------------------------

class _OnboardingCompleteDialog extends StatelessWidget {
  final VoidCallback onDone;
  const _OnboardingCompleteDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      showCloseButton: false,
      barrierDismissible: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.accentPrimary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.guidedTourCompleteTitle,
            style: AppTypography.ibm(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.guidedTourCompleteBody,
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.44,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: DialogActionBar.single(
        cancelLabel: l10n.commonDone,
        onCancel: onDone,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post-tour — Bankroll Card Tour (shown once on first Home visit after tour)
// ---------------------------------------------------------------------------

class BankrollCardTour {
  final GlobalKey bankrollCardKey;

  /// Invoked when the tip is finished OR skipped — Home chains the post-tour
  /// wrap-up (completion dialog + paywall) from here.
  final VoidCallback? onDone;

  BankrollCardTour({required this.bankrollCardKey, this.onDone});

  void show(BuildContext context) {
    if (bankrollCardKey.currentContext == null) return;

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'bankroll_card',
        keyTarget: bankrollCardKey,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        paddingFocus: 4,
        contents: [
          centeredTooltipContent((context, controller) {
              final l10n = AppLocalizations.of(context);
              return buildTooltip(
                title: l10n.onboardingBankrollCardTitle,
                body: l10n.onboardingBankrollCardBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 12,
      hideSkip: true,
      onFinish: () {
        OnboardingPrefs.clearBankrollTourPending();
        onDone?.call();
      },
      onSkip: () {
        OnboardingPrefs.clearBankrollTourPending();
        onDone?.call();
        return true;
      },
    );
    coach.show(context: context);
  }
}

/// Axis-aligned GLOBAL rect for [key]'s render box honoring EVERY ancestor
/// transform. tutorial_coach_mark's keyTarget path computes
/// `localToGlobal(Offset.zero) & size`, which mis-places the spotlight for
/// targets inside rotated subtrees (the poker table is a RotatedBox(3) and
/// every seat a RotatedBox(1)). Passing an explicit TargetPosition computed
/// via the full transform chain spotlights the true on-screen rect.
TargetPosition? transformedTargetPosition(GlobalKey key, {double inflate = 0}) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return null;
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  ).inflate(inflate);
  return TargetPosition(rect.size, rect.topLeft);
}

/// Bottom-of-tour progress bar — thin `accentPrimary` fill + "Step X of Y"
/// caption. Reads from [OnboardingState.notifier] so it self-rebuilds as
/// steps advance. Rendered inside [createOnboardingCoachMark]'s skipWidget so it
/// lives with the Skip pill at the bottom of the overlay.
class _TourProgressIndicator extends StatelessWidget {
  const _TourProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OnboardingState.notifier,
      builder: (context, _, __) {
        if (!OnboardingState.isOnboardingActive) {
          return const SizedBox.shrink();
        }
        final step = OnboardingState.displayStep;
        final total = OnboardingState.displayTotalSteps;
        final progress = OnboardingState.progress;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 4,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.12),
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(color: AppColors.accentPrimary),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).onboardingStepOf(step, total),
              style: AppTypography.bodySmall(
                color: Colors.white.withValues(alpha: 0.54),
              ).copyWith(fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

/// Local animated width helper — duplicated here to avoid a cross-file
/// private-widget import from `onboarding_progress_bar.dart`.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final AlignmentGeometry alignment;
  final Widget? child;

  const AnimatedFractionallySizedBox({
    super.key,
    required Duration duration,
    Curve curve = Curves.linear,
    required this.widthFactor,
    required this.alignment,
    this.child,
  }) : super(duration: duration, curve: curve);

  @override
  AnimatedWidgetBaseState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
