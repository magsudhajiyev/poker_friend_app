import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/trial_reminder_service.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('names the plan and the price after the trial (annual)', () {
    final (title, body) = TrialReminderService.buildCopy(en,
        tier: 'elite', priceString: '\$189.99', isAnnual: true);
    expect(title, 'Your free trial ends tomorrow');
    expect(body,
        'After that, Elite costs \$189.99/year. Cancel anytime in your subscription settings.');
  });

  test('monthly price', () {
    final (_, body) = TrialReminderService.buildCopy(en,
        tier: 'pro', priceString: '\$19.99', isAnnual: false);
    expect(body, contains('Pro costs \$19.99/month'));
  });

  test('unknown price → no invented number', () {
    final (_, body) = TrialReminderService.buildCopy(en,
        tier: 'club', priceString: null, isAnnual: false);
    expect(body, 'After that, your Club subscription starts. Cancel anytime in your subscription settings.');
  });

  test('every language has the reminder copy', () {
    for (final code in ['de', 'es', 'fr', 'it', 'pt', 'ro', 'ru', 'pl', 'sk', 'uk']) {
      final l = lookupAppLocalizations(Locale(code));
      final (title, body) = TrialReminderService.buildCopy(l,
          tier: 'pro', priceString: '9,99 €', isAnnual: true);
      expect(title, isNotEmpty, reason: code);
      expect(body, contains('9,99 €'), reason: code);
      expect(body, contains('Pro'), reason: code);
    }
  });
}
