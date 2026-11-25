import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/live_session_logic.dart';

/// Name shown for a running session. A session saved without a name (older
/// full sessions) reads "Cash session · Nov 25" / "Tournament · Nov 25".
String runningSessionLabel(AppLocalizations l10n, LiveSessionRecord r) {
  final name = r.name.trim();
  if (name.isNotEmpty) return name;
  final kind =
      r.gameType == 'tournament' ? l10n.setupTournament : l10n.setupCashGame;
  return '$kind · ${DateFormat.MMMd(l10n.localeName).format(r.startTime)}';
}
