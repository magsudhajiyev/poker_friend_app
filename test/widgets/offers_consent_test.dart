import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/offers_consent_sheet.dart';

void main() {
  bool due({
    bool flagOn = true,
    bool signedIn = true,
    bool decided = false,
    bool prompted = false,
    bool dayOverride = false,
    bool onboarding = false,
  }) =>
      OffersConsentSheet.shouldPrompt(
        flagOn: flagOn,
        signedIn: signedIn,
        alreadyDecided: decided,
        alreadyPrompted: prompted,
        dayOverride: dayOverride,
        onboardingActive: onboarding,
      );

  test('prompts once, only with the flag on and a signed-in user', () {
    expect(due(), isTrue);
    expect(due(flagOn: false), isFalse, reason: 'flag off = no behaviour change');
    expect(due(signedIn: false), isFalse);
  });

  test('never asks again after a choice or a previous prompt', () {
    expect(due(decided: true), isFalse);
    expect(due(prompted: true), isFalse);
  });

  test('admin day-override runs never prompt', () {
    expect(due(dayOverride: true), isFalse);
  });

  test('never during onboarding or the tour, but due again afterwards', () {
    expect(due(onboarding: true), isFalse);
    expect(due(onboarding: false), isTrue);
  });

  test('the hard-paywall entry obeys the same once-only rule', () {
    // Same pure decision: a user who already chose or was prompted is never
    // asked again from the paywall either.
    expect(due(decided: true), isFalse);
    expect(due(prompted: true), isFalse);
    expect(due(flagOn: false), isFalse, reason: 'flag off = no behaviour change');
  });
}
