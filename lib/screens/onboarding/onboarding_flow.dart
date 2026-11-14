import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/feature_flag_service.dart';
import '../../services/onboarding_service.dart';
import 'welcome_step.dart';
import 'demo_challenge_step.dart';
import 'daily_challenge_info_step.dart';
import 'nickname_step.dart';
import 'game_type_step.dart';
import 'currency_step.dart';
import 'journey_step.dart';
import 'weekly_hours_step.dart';
import 'purpose_step.dart';
import 'onboarding_scaffold.dart';
import '../../design_system/constants/colors.dart';

/// Main onboarding flow controller.
///
/// Manages a PageView of 7 steps (6 if [skipNickname] is true).
/// Collects user preferences and persists them to Firestore on completion.
/// After onboarding, lands on Home — the paywall shows after the guided tour.
class OnboardingFlow extends StatefulWidget {
  /// If true, skip the nickname claim step (user already has a username).
  final bool skipNickname;

  /// If true, skip Firestore writes and pop back when done (for dev testing).
  final bool testMode;

  const OnboardingFlow({
    super.key,
    this.skipNickname = false,
    this.testMode = false,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageController;
  late List<Widget> _steps;
  int _currentStep = 0;

  // Collected onboarding data
  String? _gameType;
  String? _pokerJourney;
  int _monthlySessions = 10;
  final List<String> _purposes = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _steps = _buildSteps();
    // The demo step depends on the daily_challenge flag, which loads
    // asynchronously (SharedPreferences cache, then Firestore). On a fresh
    // install the flag often is not resolved yet when onboarding opens, so
    // rebuild the step list when it lands — but only while still on Welcome
    // (step 0), i.e. before the user could have reached where the demo is
    // inserted. Once past Welcome the listener detaches and the list is fixed.
    FeatureFlagService.revision.addListener(_onFlagsChanged);
  }

  void _onFlagsChanged() {
    if (!mounted) return;
    // The daily_challenge steps (demo spot + the DC info screen) are APPENDED
    // at the end, so a rebuild never shifts the step the user is currently on
    // — safe to apply any time the daily_challenge flag resolves (it loads
    // async; on a fresh install it often lands while the user is still
    // answering the questions). Only rebuild when the count actually changes
    // and the current index stays valid.
    final rebuilt = _buildSteps();
    if (rebuilt.length != _steps.length && _currentStep < rebuilt.length) {
      setState(() => _steps = rebuilt);
    }
  }

  @override
  void dispose() {
    FeatureFlagService.revision.removeListener(_onFlagsChanged);
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildSteps() {
    // The Daily Challenge demo is the LAST step (value-first: the user answers
    // the setup questions, then plays one real spot before the post-tour
    // paywall). Only when the feature is live — a flag-off or test build omits
    // it, and then the questions' terminal step completes onboarding directly.
    final hasDemo = !widget.testMode &&
        FeatureFlagService.isEnabled(FeatureFlagService.dailyChallenge);

    final steps = <Widget>[
      WelcomeStep(onContinue: _nextStep),
    ];

    if (!widget.skipNickname) {
      steps.add(NicknameStep(onContinue: _nextStep, onBack: _previousStep));
    }

    steps.addAll([
      GameTypeStep(
        onBack: _previousStep,
        onContinue: (value) {
          _gameType = value;
          _nextStep();
        },
      ),
      // Currency: persisted locally right away (CurrencyService), so cash
      // amounts are correct from the very first logged session.
      CurrencyStep(
        onBack: _previousStep,
        onContinue: (code) {
          CurrencyService.setCurrency(code);
          _nextStep();
        },
      ),
      JourneyStep(
        onBack: _previousStep,
        onContinue: (value) {
          _pokerJourney = value;
          _nextStep();
        },
      ),
      WeeklyHoursStep(
        onBack: _previousStep,
        onContinue: (value) {
          _monthlySessions = value;
          _nextStep();
        },
      ),
      PurposeStep(
        onBack: _previousStep,
        onContinue: (values) {
          _purposes.clear();
          _purposes.addAll(values);
          // With the demo last, Purpose advances to it; otherwise it is the
          // terminal step and completes onboarding.
          hasDemo ? _nextStep() : _completeOnboarding();
        },
      ),
    ]);

    if (hasDemo) {
      // Demo spot → a final info screen about the ongoing Daily Challenge →
      // finish onboarding (Home + in-app tour).
      steps.add(DemoChallengeStep(
        onContinue: _nextStep,
        onBack: _previousStep,
      ));
      steps.add(DailyChallengeInfoStep(
        onContinue: _completeOnboarding,
        onBack: _previousStep,
      ));
    }

    return steps;
  }

  // Duration/curve for the card-deal transition. 520ms + easeOutCubic
  // matches the "dealt from off-table" feel — long enough for the tilt
  // and settle to read, short enough not to slow the flow down.
  static const _dealDuration = Duration(milliseconds: 520);
  static const _dealCurve = Curves.easeOutCubic;

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      HapticFeedback.selectionClick();
      setState(() => _currentStep++);
      _pageController.nextPage(duration: _dealDuration, curve: _dealCurve);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: _dealDuration,
        curve: _dealCurve,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // Save data to Firestore (skip in test mode)
    if (!widget.testMode) {
      if (_gameType != null && _pokerJourney != null) {
        await OnboardingService.saveOnboardingData(
          gameType: _gameType!,
          pokerJourney: _pokerJourney!,
          monthlySessions: _monthlySessions,
          purposes: _purposes,
        );
      } else {
        await OnboardingService.markOnboardingComplete();
      }
    }

    if (!mounted) return;

    // No paywall here anymore — it shows AFTER the guided tour (value first),
    // via finishOnboardingTour / the pending-flag fallback on Home.

    if (widget.testMode) {
      // In test mode, just pop back to profile
      Navigator.pop(context);
    } else {
      // In real flow, go to home. Drop the startup prefetch snapshot first —
      // it predates the flag writes above, and the gate re-runs after this
      // reset (a stale hasCompletedOnboarding:false replays onboarding).
      AuthService.clearPrefetchedUserDoc();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Persistent progress bar overlay — one instance across all steps so
    // the morphing pill actually tweens between positions instead of being
    // rebuilt (and snapping to its target) with every PageView child.
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              return _DealTransition(
                controller: _pageController,
                index: index,
                fallbackPage: _currentStep.toDouble(),
                child: _steps[index],
              );
            },
          ),
          Positioned(
            top: topInset + 8,
            left: 24,
            right: 24,
            child: OnboardingProgressBar(
              currentStep: _currentStep + 1,
              totalSteps: _steps.length,
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies a "card-deal" transform to a PageView child based on its
/// distance from the current page position.
///
/// The incoming card tilts on Y (perspective 3D), scales down slightly,
/// and fades — combined with PageView's built-in horizontal slide this
/// reads as a card being dealt onto the table rather than a flat swipe.
/// Neutralizes to identity when the page is fully in view so the step
/// content lands crisp.
class _DealTransition extends StatelessWidget {
  final PageController controller;
  final int index;
  final double fallbackPage;
  final Widget child;

  const _DealTransition({
    required this.controller,
    required this.index,
    required this.fallbackPage,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        // Guarded read — PageController.page throws before the first
        // build establishes dimensions.
        double page = fallbackPage;
        if (controller.positions.isNotEmpty &&
            controller.position.haveDimensions) {
          page = controller.page ?? fallbackPage;
        }
        final delta = (index - page).clamp(-1.0, 1.0);
        final absDelta = delta.abs();

        // Tilt: incoming card enters ~20° pre-tilt on Y axis.
        // Scale: subtle depth cue, 1.0 in view → 0.92 off-screen.
        // Opacity: hard fade in the last 40% so the deal feels crisp.
        final tilt = delta * 0.35; // ~20°
        final scale = 1.0 - (absDelta * 0.08);
        final opacity = (1.0 - absDelta * 1.6).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective
              ..rotateY(tilt)
              ..scaleByDouble(scale, scale, 1.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }
}
