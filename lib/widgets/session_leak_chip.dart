import 'package:flutter/material.dart';

import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../screens/leak_detector_screen.dart';
import '../services/analytics_service.dart';
import '../services/feature_flag_service.dart';
import '../services/session_leak_check.dart';

/// One-line leak feedback on the post-session summary — the per-session
/// trigger of the Leak Detector retention loop. Self-contained: loads its
/// own data, renders nothing while loading or when there is nothing worth
/// saying, and deep-links into the full report.
///
/// Deliberately OUTSIDE the summary card's RepaintBoundary: this is
/// personal coaching, not part of the shareable PNG.
///
/// PRE-GA TODO: English-only like the rest of the Leak Detector surface;
/// localize together with the report screen before public rollout.
class SessionLeakChip extends StatefulWidget {
  final String sessionId;

  const SessionLeakChip({super.key, required this.sessionId});

  @override
  State<SessionLeakChip> createState() => _SessionLeakChipState();
}

class _SessionLeakChipState extends State<SessionLeakChip> {
  SessionLeakChipData? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!FeatureFlagService.isEnabled(FeatureFlagService.leakDetector)) {
      return; // stays hidden
    }
    try {
      final data = await SessionLeakCheck.evaluateSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loaded = true;
      });
      if (data != null) {
        AnalyticsService.capture('leak_session_chip_shown', {
          'kind': data.kind.name,
          'finding_id': data.findingId,
          'relates_to_leak': data.relatesToCurrentLeak,
        });
      }
    } catch (_) {
      // The chip must never get in the way of the summary.
    }
  }

  String _pct(double v) => '${(v * 100).round()}%';

  ({IconData icon, Color color, String text, String cta}) _content(
      SessionLeakChipData d) {
    switch (d.kind) {
      case SessionLeakChipKind.aboveUsual:
      case SessionLeakChipKind.belowUsual:
        final dir =
            d.kind == SessionLeakChipKind.aboveUsual ? 'above' : 'below';
        // Direction goodness depends on the detector; the honest framing
        // is "different from your usual", amber when it's the player's
        // flagged leak, neutral otherwise.
        return (
          icon: d.relatesToCurrentLeak
              ? Icons.track_changes
              : Icons.insights_outlined,
          color: d.relatesToCurrentLeak
              ? AppColors.accentTertiary
              : AppColors.accentSecondary,
          text: '${d.title}: ${d.hits} of ${d.spots} spots '
              '(${_pct(d.sessionRate)}) — $dir your usual '
              '${_pct(d.usualRate!)}',
          cta: d.relatesToCurrentLeak ? 'your #1 leak' : 'see report',
        );
      case SessionLeakChipKind.nearUsual:
        return (
          icon: d.relatesToCurrentLeak
              ? Icons.track_changes
              : Icons.insights_outlined,
          color: AppColors.accentPrimary,
          text: '${d.title}: ${d.hits} of ${d.spots} spots '
              '(${_pct(d.sessionRate)}) — in line with your usual',
          cta: d.relatesToCurrentLeak ? 'your #1 leak' : 'see report',
        );
      case SessionLeakChipKind.factOnly:
        return (
          icon: Icons.query_stats,
          color: AppColors.accentSecondary,
          text: '${d.title}: ${d.hits} of ${d.spots} spots '
              '(${_pct(d.sessionRate)}) this session',
          cta: 'see your leak report',
        );
      case SessionLeakChipKind.unlockProgress:
        return (
          icon: Icons.lock_outline,
          color: AppColors.accentSecondary,
          text: '+${d.spots} spots toward ${d.title} — '
              '${d.remainingToUnlock} more for a verdict',
          cta: 'see progress',
        );
      case SessionLeakChipKind.unlockReady:
        return (
          icon: Icons.lock_open_rounded,
          color: AppColors.accentPrimary,
          text: '${d.title} has enough spots for a verdict now',
          cta: 'open report',
        );
      case SessionLeakChipKind.sessionBanked:
        final hands = d.handsAnalyzed == 1 ? '1 hand' : '${d.handsAnalyzed} hands';
        return (
          icon: Icons.savings_outlined,
          color: AppColors.textSecondary,
          text: d.spots > 0
              ? '$hands analyzed · ${d.spots} leak '
                  '${d.spots == 1 ? 'spot' : 'spots'} banked'
              : '$hands analyzed — leak spots build with longer sessions',
          cta: 'see your leak report',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: !_loaded || data == null
          ? const SizedBox.shrink()
          : _buildChip(data),
    );
  }

  Widget _buildChip(SessionLeakChipData d) {
    final c = _content(d);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          onTap: () {
            AnalyticsService.capture('leak_session_chip_tapped', {
              'kind': d.kind.name,
              'finding_id': d.findingId,
            });
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeakDetectorScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
              border: Border.all(color: c.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(c.icon, size: 16, color: c.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LEAK CHECK',
                          style: AppTypography.ibm(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: c.color)),
                      const SizedBox(height: 2),
                      Text(c.text,
                          style: AppTypography.ibm(
                              fontSize: 12.5,
                              color: Colors.white,
                              height: 1.35)),
                      const SizedBox(height: 2),
                      Text(c.cta,
                          style: AppTypography.ibm(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.color)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
