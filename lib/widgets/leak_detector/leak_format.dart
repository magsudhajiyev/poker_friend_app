import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import '../../services/leak_snapshot_store.dart';

/// Whole-number percentage text for a 0..1 frequency ("42%").
String leakPct(double v) => '${(v * 100).round()}%';

/// Status colour of a finding: healthy = brand, otherwise amber/red by
/// severity. Colour is NEVER the only signal; pair with [leakStatusIcon] and
/// [leakStatusWord].
Color leakStatusColor(LeakFinding f) {
  if (!f.isLeak) return AppColors.accentPrimary;
  return f.severity > 0.5 ? AppColors.accentDanger : AppColors.accentTertiary;
}

IconData leakStatusIcon(LeakFinding f) {
  if (!f.isLeak) return Icons.check_circle_outline;
  return f.verdict == LeakVerdict.confirmed
      ? Icons.error_outline
      : Icons.warning_amber_rounded;
}

String leakStatusWord(AppLocalizations l10n, LeakFinding f) {
  if (!f.isLeak) return l10n.leakStatusHealthy;
  return f.verdict == LeakVerdict.confirmed
      ? l10n.leakStatusConfirmed
      : l10n.leakStatusEmerging;
}

/// Direction of a movement since the previous visit, relative to the
/// healthy band (not relative to the raw number).
enum LeakDeltaKind { closer, further, flat }

class LeakDelta {
  final int points; // absolute, > 0
  final LeakDeltaKind kind;
  const LeakDelta(this.points, this.kind);

  Color get color => switch (kind) {
        LeakDeltaKind.closer => AppColors.accentPrimary,
        LeakDeltaKind.further => AppColors.accentDanger,
        LeakDeltaKind.flat => AppColors.textSecondary,
      };

  String text(AppLocalizations l10n) => switch (kind) {
        LeakDeltaKind.closer => l10n.leakDeltaCloser(points),
        LeakDeltaKind.further => l10n.leakDeltaFurther(points),
        LeakDeltaKind.flat => l10n.leakDeltaMoved(points),
      };

  /// Null when there is no usable previous reading or nothing moved.
  static LeakDelta? compute(LeakFinding f, LeakSnapshotEntry? prev) {
    if (prev == null || prev.verdict == LeakVerdict.insufficientData) {
      return null;
    }
    final pts = ((f.value - prev.value) * 100).round().abs();
    if (pts == 0) return null;
    double dist(double v) => v < f.bandLow
        ? f.bandLow - v
        : (v > f.bandHigh ? v - f.bandHigh : 0);
    final moved = dist(prev.value) - dist(f.value);
    final kind = moved > 0.001
        ? LeakDeltaKind.closer
        : moved < -0.001
            ? LeakDeltaKind.further
            : LeakDeltaKind.flat;
    return LeakDelta(pts, kind);
  }
}

/// "3d ago", "2mo ago", "today" (localized).
String leakRelativeDate(AppLocalizations l10n, DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inDays >= 30) return l10n.leakRelMonths((d.inDays / 30).floor());
  if (d.inDays >= 1) return l10n.leakRelDays(d.inDays);
  if (d.inHours >= 1) return l10n.leakRelHours(d.inHours);
  return l10n.leakRelToday;
}

final RegExp _cardPattern = RegExp(r'(?:10|[2-9TJQKA])[♠♥♦♣]');

/// "A♠K♦" -> ["A♠", "K♦"]; empty for null / unparseable input.
List<String> splitHoleCards(String? raw) {
  if (raw == null) return const [];
  return _cardPattern.allMatches(raw).map((m) => m.group(0)!).toList();
}
