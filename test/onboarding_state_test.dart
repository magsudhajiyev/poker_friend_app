import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/onboarding/onboarding_state.dart';

void main() {
  // Static state leaks between tests — always reset first.
  setUp(() {
    OnboardingState.complete();
    OnboardingState.completeReplay();
  });

  group('display step mapping (normal tour, 7 phases)', () {
    test('phases map to steps 1-6 with 2+3 merged', () {
      OnboardingState.start();
      final expected = {0: 1, 1: 2, 2: 3, 3: 3, 4: 4, 5: 5, 6: 6};
      expected.forEach((phase, step) {
        OnboardingState.advanceTo(phase);
        expect(OnboardingState.displayStep, step,
            reason: 'phase $phase should display as step $step');
      });
      expect(OnboardingState.displayTotalSteps, 6);
    });

    test('totalPhases includes the new sessionReview phase', () {
      expect(OnboardingState.totalPhases, 7);
    });
  });

  group('display step mapping (replay)', () {
    test('replay offsets by one and keeps 4 total steps', () {
      OnboardingState.startFromPhase(1);
      final expected = {1: 1, 2: 2, 3: 2, 4: 3};
      expected.forEach((phase, step) {
        OnboardingState.advanceTo(phase);
        expect(OnboardingState.displayStep, step,
            reason: 'replay phase $phase should display as step $step');
      });
      expect(OnboardingState.displayTotalSteps, 4);
      OnboardingState.completeReplay();
    });
  });

  group('phase-6 pending flags', () {
    test('start() resets all phase-6 flags and tourSessionId', () {
      OnboardingState.sessionHistoryTourPending = true;
      OnboardingState.handListTourPending = true;
      OnboardingState.handCardTourPending = true;
      OnboardingState.aiAnalysisTourPending = true;
      OnboardingState.tourSessionId = 'session_123';

      OnboardingState.start();

      expect(OnboardingState.sessionHistoryTourPending, false);
      expect(OnboardingState.handListTourPending, false);
      expect(OnboardingState.handCardTourPending, false);
      expect(OnboardingState.aiAnalysisTourPending, false);
      expect(OnboardingState.tourSessionId, isNull);
    });

    test('complete() resets phase-6 flags', () {
      OnboardingState.start();
      OnboardingState.sessionHistoryTourPending = true;
      OnboardingState.handListTourPending = true;
      OnboardingState.handCardTourPending = true;
      OnboardingState.aiAnalysisTourPending = true;

      OnboardingState.complete();

      expect(OnboardingState.isOnboardingActive, false);
      expect(OnboardingState.sessionHistoryTourPending, false);
      expect(OnboardingState.handListTourPending, false);
      expect(OnboardingState.handCardTourPending, false);
      expect(OnboardingState.aiAnalysisTourPending, false);
    });

    test('cancel() resets phase-6 flags', () {
      OnboardingState.start();
      OnboardingState.advanceTo(6);
      OnboardingState.sessionHistoryTourPending = true;

      OnboardingState.cancel();

      expect(OnboardingState.isOnboardingActive, false);
      expect(OnboardingState.currentPhase, 0);
      expect(OnboardingState.sessionHistoryTourPending, false);
    });

    test('startFromPhase() (replay) resets phase-6 flags', () {
      OnboardingState.sessionHistoryTourPending = true;
      OnboardingState.handCardTourPending = true;

      OnboardingState.startFromPhase(4);

      expect(OnboardingState.isReplay, true);
      expect(OnboardingState.sessionHistoryTourPending, false);
      expect(OnboardingState.handCardTourPending, false);
      OnboardingState.completeReplay();
    });
  });

  group('tourSessionId survives phase advances', () {
    test('kept through phases, cleared only by start()', () {
      OnboardingState.start();
      OnboardingState.tourSessionId = 'session_abc';
      OnboardingState.advanceTo(5);
      OnboardingState.advanceTo(6);
      expect(OnboardingState.tourSessionId, 'session_abc');

      // complete() intentionally leaves it — fallbacks may still read it
      OnboardingState.complete();
      OnboardingState.start();
      expect(OnboardingState.tourSessionId, isNull);
    });
  });

  group('isGuidedHandActive', () {
    test('only true during phase 4 with an unfinished guided hand', () {
      OnboardingState.start();
      expect(OnboardingState.isGuidedHandActive, false);

      OnboardingState.advanceTo(4);
      OnboardingState.guidedHandPhase = GuidedPhase.heroTurn;
      expect(OnboardingState.isGuidedHandActive, true);

      OnboardingState.advanceTo(6);
      expect(OnboardingState.isGuidedHandActive, false,
          reason: 'phase 6 must not suppress hand saves');

      OnboardingState.advanceTo(4);
      OnboardingState.guidedHandPhase = GuidedPhase.done;
      expect(OnboardingState.isGuidedHandActive, false);
    });
  });
}
