import 'package:flutter/material.dart';
import '../../services/onboarding_service.dart';
import '../paywall_screen.dart';
import 'welcome_step.dart';
import 'nickname_step.dart';
import 'game_type_step.dart';
import 'journey_step.dart';
import 'weekly_hours_step.dart';
import 'purpose_step.dart';

/// Main onboarding flow controller.
///
/// Manages a PageView of 6 steps (5 if [skipNickname] is true).
/// Collects user preferences and persists them to Firestore on completion.
/// After onboarding, navigates to the paywall screen.
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

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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

    // Navigate to paywall screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaywallScreen(),
      ),
    );

    if (!mounted) return;

    if (widget.testMode) {
      // In test mode, just pop back to profile
      Navigator.pop(context);
    } else {
      // In real flow, go to home
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050B),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _steps,
      ),
    );
  }
}
