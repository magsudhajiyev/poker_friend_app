import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import 'onboarding_prefs.dart';
import 'onboarding_state.dart';

// Dev user ID — never auto-complete for this user
const _devUserId = 'FELwuk4XbvdibPCx9NesqP5dRIn1';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

TutorialCoachMark _createCoachMark({
  required List<TargetFocus> targets,
  required VoidCallback onFinish,
  VoidCallback? onSkip,
}) {
  return TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.85,
    paddingFocus: 12,
    hideSkip: false,
    skipWidget: Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(
          'Skip tour',
          style: AppTypography.bodySmall(color: Colors.white70),
        ),
      ),
    ),
    onSkip: () {
      OnboardingState.cancel();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != _devUserId) {
        OnboardingPrefs.markOnboardingSeen();
      }
      onSkip?.call();
      return true;
    },
    onFinish: onFinish,
  );
}

Widget buildWelcomeCard({required VoidCallback onNext}) {
  return Container(
    padding: const EdgeInsets.all(28),
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: const Color(0xFF161618),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.buttonPrimary.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.buttonPrimary.withOpacity(0.1),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome to Final Table',
          style: AppTypography.pageTitle().copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Let\'s take a quick tour to get you started.',
          style: AppTypography.bodySmall(
            color: Colors.white.withOpacity(0.7),
          ).copyWith(height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Let\'s go',
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
  bool isLast = false,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF161618),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.bodyLarge(color: Colors.white).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppTypography.bodySmall(
            color: Colors.white.withOpacity(0.7),
          ).copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onNext,
            child: Text(
              isLast ? 'Got it' : 'Next',
              style: AppTypography.bodyLarge(color: AppColors.buttonPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
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
              return buildWelcomeCard(onNext: () => controller.next());
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
                return buildTooltip(
                  title: 'Start Logging',
                  body: 'Tap the + button to begin logging a hand.',
                  onNext: () => controller.next(),
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

    if (fullModeCardKey.currentContext != null) {
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
                return buildTooltip(
                  title: 'Full Logging Mode',
                  body:
                      'Track every action for every player across all streets. Perfect for serious analysis.',
                  onNext: () => controller.next(),
                );
              },
            ),
          ],
        ),
      );
    }

    if (individualModeCardKey.currentContext != null) {
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
                return buildTooltip(
                  title: 'Individual Logging Mode',
                  body:
                      'Quick profit/loss tracking for a single session. Now choose a mode to continue!',
                  onNext: () => controller.next(),
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
      onFinish: () {
        OnboardingState.advanceTo(2);
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 2 — Session Setup Tour
// ---------------------------------------------------------------------------

class SessionSetupTour {
  SessionSetupTour();

  void show(BuildContext context) {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 2) return;

    final targets = <TargetFocus>[];

    // No-spotlight instruction card
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
              return buildTooltip(
                title: 'Session Setup',
                body:
                    'Fill in your session details \u2014 name, buy-in, blinds \u2014 then tap Start Game.',
                onNext: () => controller.next(),
                isLast: true,
              );
            },
          ),
        ],
      ),
    );

    final coach = _createCoachMark(
      targets: targets,
      onFinish: () {
        OnboardingState.advanceTo(3);
      },
    );
    coach.show(context: context);
  }
}

// ---------------------------------------------------------------------------
// Phase 3 — Seat Setup Tour
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
          radius: 200,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: 'Setup Your Table',
                  body:
                      'Tap any seat to set up players. Let\'s walk through the seat dialog next.',
                  onNext: () => controller.next(),
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
      onFinish: () {
        // Stay at phase 3 — seat dialog tour still needs to run
        OnboardingState.seatDialogTourPending = true;
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
                return buildTooltip(
                  title: 'Seat Open',
                  body:
                      'Toggle to mark a seat as occupied or empty. Open seats are skipped during the hand.',
                  onNext: () => controller.next(),
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
                return buildTooltip(
                  title: 'This Is My Seat',
                  body:
                      'Tap here if this is your seat. It auto-fills your name and tracks your personal stats.',
                  onNext: () => controller.next(),
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
                return buildTooltip(
                  title: 'Player Name',
                  body:
                      'Type a name or pick from your saved opponents. Saved opponents track stats across sessions.',
                  onNext: () => controller.next(),
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
                return buildTooltip(
                  title: 'Save Opponent',
                  body:
                      'New name? Tap here to save them as an opponent. Their stats will be tracked automatically.',
                  onNext: () => controller.next(),
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
                return buildTooltip(
                  title: 'Dealer Button',
                  body:
                      'Drag this to the seat with the dealer position. It determines blinds and action order.',
                  onNext: () => controller.next(),
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
                return buildTooltip(
                  title: 'View Your Sessions',
                  body:
                      'Tap Sessions to see your session results, hand history, and stats.',
                  onNext: () => controller.next(),
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      _finishAndShowCompletion(context);
      return;
    }

    final coach = _createCoachMark(
      targets: targets,
      onFinish: () {
        _finishAndShowCompletion(context);
      },
    );
    coach.show(context: context);
  }

  void _finishAndShowCompletion(BuildContext context) {
    OnboardingState.complete();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != _devUserId) {
      OnboardingPrefs.markOnboardingSeen();
    }
    onComplete?.call();

    // Show completion dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OnboardingCompleteDialog(),
    );
  }
}

class _OnboardingCompleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161618),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉',
              style: TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re All Set!',
              style: GoogleFonts.ibmPlexSans(
                color: AppColors.buttonPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You are now familiar with hand logging. Enjoy the experience!',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                ),
                child: Text(
                  'Let\'s Go!',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
