import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../screens/paywall_screen.dart';
import '../screens/auth_screen_experimental.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../services/auth_service.dart';
import 'onboarding_prefs.dart';
import 'onboarding_state.dart';
import '../design_system/constants/decorations.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

TutorialCoachMark _createCoachMark({
  required List<TargetFocus> targets,
  required VoidCallback onFinish,
  VoidCallback? onSkip,
  required BuildContext context,
}) {
  final l10n = AppLocalizations.of(context);
  return TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.85,
    paddingFocus: 12,
    hideSkip: false,
    // Top-left so it never overlaps the bottom-right + FAB / action buttons
    alignSkip: Alignment.topLeft,
    skipWidget: Padding(
      padding: EdgeInsets.only(
          left: 16, top: MediaQuery.of(context).padding.top + 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(
          l10n.onboardingSkipTour,
          style: AppTypography.bodySmall(color: Colors.white70).copyWith(fontSize: 15),
        ),
      ),
    ),
    onSkip: () {
      final wasReplay = OnboardingState.isReplay;
      OnboardingState.cancel();
      OnboardingPrefs.markOnboardingSeen();
      if (!wasReplay) {
        // Don't push the paywall from mid-tour contexts — the next Home
        // visit shows it once via the pending flag
        OnboardingPrefs.setPostTourPaywallPending();
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
        color: AppColors.tealPrimary.withValues(alpha: 0.15),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.tealPrimary.withValues(alpha: 0.08),
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
              backgroundColor: AppColors.tealPrimary,
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
  return Container(
    padding: const EdgeInsets.all(24),
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      border: Border.all(
        color: AppColors.tealPrimary.withValues(alpha: 0.15),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.tealPrimary.withValues(alpha: 0.08),
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
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppTypography.bodySmall(
            color: Colors.white.withValues(alpha: 0.8),
          ).copyWith(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tealPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
              ),
              child: Text(
                isLast ? l10n.onboardingGotIt : l10n.onboardingNext,
                style: AppTypography.bodyLarge(color: AppColors.tealPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
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
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
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
  final GlobalKey individualModeCardKey;

  LoggingModeTour({
    required this.fullModeCardKey,
    required this.individualModeCardKey,
  });

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 1) return;

    final targets = <TargetFocus>[];
    final isReplay = OnboardingState.isReplay;
    final isIndividual = OnboardingState.isIndividualMode;

    // During replay, only highlight the relevant mode card
    final showFull = !isReplay || !isIndividual;
    final showIndividual = !isReplay || isIndividual;

    if (showFull && fullModeCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'full_mode',
          keyTarget: fullModeCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingFullModeTitle,
                  body: l10n.onboardingFullModeBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: isReplay && !isIndividual,
                );
              },
            ),
          ],
        ),
      );
    }

    if (showIndividual && individualModeCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'individual_mode',
          keyTarget: individualModeCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingIndividualModeTitle,
                  body: l10n.onboardingIndividualModeBody,
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

    final coach = _createCoachMark(
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

    final coach = _createCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        if (OnboardingState.isIndividualMode) {
          OnboardingState.advanceTo(3);
          OnboardingState.individualTrackingTourPending = true;
        } else {
          // Mark table tour pending and notify the screen
          OnboardingState.tableTourPending = true;
          onFinished?.call();
        }
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

    final coach = _createCoachMark(
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
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
Future<void> finishOnboardingTour(BuildContext context,
    {bool showPaywall = true}) async {
  OnboardingState.complete();
  OnboardingPrefs.markOnboardingSeen();

  final isGuest = AuthService.isAnonymous && !OnboardingState.isReplay;
  if (isGuest) {
    // Persist the sign-up requirement NOW — before the dialog — so that if the
    // guest kills the app at any point after the tour, the next launch forces
    // them back into sign-up (AuthWrapper → GuestSignupGate) instead of letting
    // them keep using the app as a guest.
    await OnboardingPrefs.setPostTourSignupRequired();
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OnboardingCompleteDialog(
      onDone: () => Navigator.of(ctx).pop(),
    ),
  );
  if (!context.mounted) return;

  if (isGuest) {
    // Required sign-up → questions → paywall → Home (same chain used on relaunch).
    await completeGuestSignup(context);
    return;
  }

  // Non-guest: skippable paywall (at most once ever), then Home.
  if (showPaywall && !(await OnboardingPrefs.wasPostTourPaywallShown())) {
    await OnboardingPrefs.markPostTourPaywallShown();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaywallScreen(showSkip: true),
      ),
    );
  }

  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
    if (!(await OnboardingPrefs.wasPostTourPaywallShown())) {
      await OnboardingPrefs.markPostTourPaywallShown();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PaywallScreen(showSkip: true),
        ),
      );
    }
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
        child: CircularProgressIndicator(color: AppColors.tealPrimary),
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
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        // Hand off to phase 6: the user now taps the real Sessions icon,
        // and SessionHistoryScreen picks the tour up in initState.
        OnboardingState.advanceTo(6);
        OnboardingState.sessionHistoryTourPending = true;
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
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
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
      targets: targets,
      context: context,
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
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
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

    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'hand_tools_row',
        keyTarget: toolsRowKey,
        shape: ShapeLightFocus.RRect,
        radius: 24,
        paddingFocus: 8,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
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

    final coach = _createCoachMark(
      targets: targets,
      context: context,
      onFinish: onNext,
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
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
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

    final coach = _createCoachMark(
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
    return Center(
      child: Container(
        width: 309,
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(color: AppColors.neutral800),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 114,
              offset: Offset(20, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.tealPrimary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.guidedTourCompleteTitle,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.guidedTourCompleteBody,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 15,
                height: 1.44,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
                child: Center(
                  child: Text(
                    l10n.commonDone,
                    style: AppTypography.ibm(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 3 (individual mode) — Individual Tracking Tour
// ---------------------------------------------------------------------------

class IndividualTrackingTour {
  final GlobalKey updateStackButtonKey;
  final GlobalKey logHandButtonKey;

  IndividualTrackingTour({
    required this.updateStackButtonKey,
    required this.logHandButtonKey,
  });

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3 ||
        !OnboardingState.individualTrackingTourPending) return;

    final targets = <TargetFocus>[];

    if (updateStackButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'update_stack_btn',
          keyTarget: updateStackButtonKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingUpdateStackTitle,
                  body: l10n.onboardingUpdateStackBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (logHandButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'log_hand_btn',
          keyTarget: logHandButtonKey,
          shape: ShapeLightFocus.RRect,
          radius: 60,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingLogAHandTitle,
                  body: l10n.onboardingLogAHandBody,
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
      OnboardingState.individualTrackingTourPending = false;
      OnboardingState.quickStackUpdateTourPending = true;
      return;
    }

    final coach = _createCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.individualTrackingTourPending = false;
        OnboardingState.quickStackUpdateTourPending = true;
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 3 (individual mode) — Quick Stack Update Tour
// ---------------------------------------------------------------------------

class QuickStackUpdateTour {
  final GlobalKey seatToggleKey;
  final GlobalKey buttonIndicatorKey;
  final GlobalKey playerNameAreaKey;
  final GlobalKey stackSliderKey;

  QuickStackUpdateTour({
    required this.seatToggleKey,
    required this.buttonIndicatorKey,
    required this.playerNameAreaKey,
    required this.stackSliderKey,
  });

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 3 ||
        !OnboardingState.quickStackUpdateTourPending) return;

    final targets = <TargetFocus>[];

    if (seatToggleKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'seat_toggle_qsu',
          keyTarget: seatToggleKey,
          shape: ShapeLightFocus.RRect,
          radius: 5,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingMarkSeatOpenTitle,
                  body: l10n.onboardingMarkSeatOpenBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (buttonIndicatorKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'button_indicator_qsu',
          keyTarget: buttonIndicatorKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingDealerButtonQsuTitle,
                  body: l10n.onboardingDealerButtonQsuBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (playerNameAreaKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'player_name_qsu',
          keyTarget: playerNameAreaKey,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          paddingFocus: 4,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingAssignPlayerTitle,
                  body: l10n.onboardingAssignPlayerBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    if (stackSliderKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'stack_slider_qsu',
          keyTarget: stackSliderKey,
          shape: ShapeLightFocus.RRect,
          radius: 8,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingAdjustStackTitle,
                  body: l10n.onboardingAdjustStackBody,
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
      OnboardingState.quickStackUpdateTourPending = false;
      OnboardingState.advanceTo(4);
      return;
    }

    final coach = _createCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.quickStackUpdateTourPending = false;
        OnboardingState.advanceTo(4);
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 3 (individual mode) — Individual Stop Session Tour
// ---------------------------------------------------------------------------

class IndividualStopSessionTour {
  final GlobalKey stopSessionButtonKey;

  IndividualStopSessionTour({required this.stopSessionButtonKey});

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        !OnboardingState.individualStopSessionTourPending) return;

    final targets = <TargetFocus>[];

    if (stopSessionButtonKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'stop_session_btn',
          keyTarget: stopSessionButtonKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                final l10n = AppLocalizations.of(context);
                return buildTooltip(
                  title: l10n.onboardingEndSessionTitle,
                  body: l10n.onboardingEndSessionBody,
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
      OnboardingState.individualStopSessionTourPending = false;
      OnboardingState.advanceTo(5);
      return;
    }

    final coach = _createCoachMark(
      targets: targets,
      context: context,
      onFinish: () {
        OnboardingState.individualStopSessionTourPending = false;
        OnboardingState.advanceTo(5);
      },
    );
    coach.show(context: context);
  }
}
