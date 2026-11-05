import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/notification_copy.dart';
import 'package:poker_logger/services/paid_nudge_copy.dart';
import 'package:poker_logger/services/paid_nudge_logic.dart';

/// Paid-nudge copy in every shipped locale: renders, no leftover
/// placeholders, recap omits zero values, nothing invented.
void main() {
  final locales = AppLocalizations.supportedLocales;
  const stats = TrialRecapStats(hands: 47, challenges: 3, accuracyPct: 82.3);

  test('11 locales are covered', () {
    expect(locales.length, 11);
  });

  for (final locale in locales) {
    group(locale.languageCode, () {
      final l10n = lookupAppLocalizations(Locale(locale.languageCode));

      test('every nudge type renders non-empty, no placeholders', () {
        for (final type in [
          EngagementNotifType.trialRecap,
          EngagementNotifType.missedDay,
          EngagementNotifType.paywallReturn,
        ]) {
          for (final trial in [true, false]) {
            final c = PaidNudgeCopy.build(l10n, type,
                coachName: 'Duke', stats: stats, trialAvailable: trial)!;
            expect(c.$1, isNotEmpty);
            expect(c.$2, isNotEmpty);
            expect('${c.$1} ${c.$2}'.contains('{'), isFalse,
                reason: '${type.id} left a placeholder');
            expect(c.$1.contains('Duke'), isTrue, reason: 'coach name in title');
          }
        }
      });

      test('recap states the real numbers', () {
        final c = PaidNudgeCopy.build(l10n, EngagementNotifType.trialRecap,
            coachName: 'Nova', stats: stats)!;
        for (final n in ['47', '3', '82']) {
          expect(c.$2.contains(n), isTrue, reason: 'body has $n: ${c.$2}');
        }
      });

      test('recap omits zero values', () {
        final c = PaidNudgeCopy.build(l10n, EngagementNotifType.trialRecap,
            coachName: 'Nova', stats: const TrialRecapStats(hands: 12))!;
        expect(c.$2.contains('12'), isTrue);
        expect(c.$2.contains('0'), isFalse, reason: c.$2);
      });
    });
  }

  test('a recap with nothing real is not sent', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
        PaidNudgeCopy.build(l10n, EngagementNotifType.trialRecap,
            coachName: 'Duke'),
        isNull);
  });

  test('plural forms follow the language', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.nudgeRecapHands(1), '1 hand logged');
    expect(en.nudgeRecapHands(2), '2 hands logged');
    final ru = lookupAppLocalizations(const Locale('ru'));
    expect(ru.nudgeRecapHands(2), contains('раздачи'));
    expect(ru.nudgeRecapHands(5), contains('раздач'));
  });

  test('paywall-return copy never states a price or a trial length', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final trial in [true, false]) {
      final c = PaidNudgeCopy.build(l10n, EngagementNotifType.paywallReturn,
          coachName: 'Vega', trialAvailable: trial)!;
      expect(RegExp(r'\d').hasMatch(c.$2), isFalse, reason: c.$2);
      expect(c.$2.contains(r'$'), isFalse);
    }
  });

  test('offer copy is not in the English catalog', () {
    expect(
        () => NotificationCopy.copyFor(EngagementNotifType.missedDay, 'nova', 0),
        throwsArgumentError);
  });
}
