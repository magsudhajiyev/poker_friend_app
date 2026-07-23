import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/currency_service.dart';
import '../../services/onboarding_service.dart';
import 'welcome_step.dart';
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

  /// If true, pop back to the caller (with `true`) on completion instead of
  /// resetting the nav stack to Home. Lets the guest post-tour chain continue
  /// into the paywall after the questions finish.
  final bool popOnComplete;

  const OnboardingFlow({
    super.key,
    this.skipNickname = false,
    this.testMode = false,
    this.popOnComplete = false,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageController;
  late final List<Widget> _steps;
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildSteps() {
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
          _completeOnboarding();
        },
      ),
    ]);

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
    } else if (widget.popOnComplete) {
      // Guest post-tour chain: pop back so the caller can continue to the paywall.
      Navigator.pop(context, true);
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
