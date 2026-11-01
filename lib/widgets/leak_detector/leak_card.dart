import 'package:flutter/material.dart';

import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/leak_engine.dart';
import '../../services/leak_focus_store.dart';
import 'band_gauge.dart';
import 'leak_detail.dart';
import 'leak_focus_strip.dart';
import 'leak_format.dart';
import 'leak_status_pill.dart';

/// THE leak layout. One card, collapsed or expanded in place (no layout
/// swap on tap). The emphasised card (#1 leak / current focus) differs only
/// by a stronger border, the finding's meaning on the collapsed face and the
/// goal strip.
///
/// Expansion state lives here, so toggling one card rebuilds only that card.
class LeakCard extends StatefulWidget {
  final LeakFinding finding;
  final Map<String, Map<String, dynamic>> handsByRef;
  final LeakCardActions actions;
  final LeakDelta? delta;
  final bool emphasis;
  final bool initiallyExpanded;

  /// Set when this finding is the player's committed focus goal.
  final LeakFocusGoal? focus;

  const LeakCard({
    super.key,
    required this.finding,
    required this.actions,
    this.handsByRef = const {},
    this.delta,
    this.emphasis = false,
    this.initiallyExpanded = false,
    this.focus,
  });

  @override
  State<LeakCard> createState() => _LeakCardState();
}

class _LeakCardState extends State<LeakCard> {
  late bool _expanded = widget.initiallyExpanded;

  LeakFinding get _f => widget.finding;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.actions.onToggle?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final status = leakStatusColor(_f);
    final emphasis = widget.emphasis;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(
          color: emphasis
              ? AppColors.tintStrong(status)
              : AppColors.tintBorder(status),
          width: emphasis ? AppSizes.borderEmphasis : AppSizes.hairline,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, status),
              _caption(context),
              if (emphasis) ..._focus(),
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.base),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? LeakDetail(
                        finding: _f,
                        handsByRef: widget.handsByRef,
                        actions: widget.actions)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color status) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      expanded: _expanded,
      excludeSemantics: true,
      label: l10n.leakCardSemantics(
        _f.title,
        leakStatusWord(l10n, _f),
        _expanded ? l10n.leakSemExpanded : l10n.leakSemCollapsed,
      ),
      onTap: _toggle,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(_f.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleBase(
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppMotion.of(context, AppMotion.fast),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: AppIconSize.lg, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              LeakStatusPill(finding: _f),
              if (widget.emphasis && !_expanded) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(_f.meaning,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.xs),
              BandGauge(
                title: _f.title,
                value: _f.value,
                bandLow: _f.bandLow,
                bandHigh: _f.bandHigh,
                markerColor: status,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "You X% · Healthy A–B% ⓘ · N spots" (+ delta). Tapping opens the band
  /// explainer; the whole line is a 44px target.
  Widget _caption(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final delta = widget.delta;
    final line = '${l10n.leakCaptionYou(leakPct(_f.value), leakPct(_f.bandLow), leakPct(_f.bandHigh))}'
        ' · ${l10n.leakSpotsCount(_f.sampleCount)}';
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$line. ${l10n.leakCaptionHint}'
          '${delta != null ? '. ${delta.text(l10n)}' : ''}',
      onTap: widget.actions.onShowBandInfo,
      child: InkWell(
        onTap: widget.actions.onShowBandInfo,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: line),
                    const TextSpan(text: ' '),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.info_outline,
                          size: AppIconSize.sm,
                          color: AppColors.textSecondary),
                    ),
                  ]),
                  style: AppTypography.caption(),
                ),
                if (delta != null)
                  Text(delta.text(l10n),
                      style: AppTypography.caption(color: delta.color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _focus() {
    final a = widget.actions;
    if (widget.focus == null && a.onSetFocus == null) return const [];
    return [
      const SizedBox(height: AppSpacing.xxs),
      LeakFocusStrip(
        finding: _f,
        focus: widget.focus,
        onSetFocus: a.onSetFocus,
        onClearFocus: a.onClearFocus,
      ),
    ];
  }
}
