import 'package:flutter/material.dart';

import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/components/app_toggle.dart';
import '../../../design_system/components/buttons/app_button.dart';
import '../../../design_system/components/pickers/app_wheel_picker.dart';
import '../../../design_system/components/sheets/app_sheet.dart';
import '../../../design_system/components/tabs/animated_segmented_tabs.dart';
import '../../../design_system/constants/colors.dart';
import '../../../design_system/constants/decorations.dart';
import '../../../design_system/constants/spacing.dart';
import '../../../design_system/constants/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/blind_level.dart';
import '../../../models/game_types.dart';
import '../../../models/poker_game_state.dart' show formatBlindValue;
import '../../../models/single_hand_setup.dart';
import '../../../utils/decimal_input.dart';
import '../../../utils/number_formatter.dart';

/// "5/10 Cash · 6 players" text of the game pill.
String gamePillText(AppLocalizations l10n, SingleHandSetup s) {
  final game =
      s.gameType == GameType.cash ? l10n.singleHandCash : l10n.singleHandTourney;
  return '${_compact(s.smallBlind)}/${_compact(s.bigBlind)} $game · '
      '${l10n.singleHandV2Players(s.playerCount)}';
}

/// 5000 -> "5K", 1500 -> "1.5K"; small values stay exact (0.25).
String _compact(double v) =>
    v >= 1000 ? formatCompactNumber(v) : formatBlindValue(v);

/// The pill that opens the game sheet.
class GamePill extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const GamePill({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelChip()),
              ),
              const SizedBox(width: AppSpacing.xxxs),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short sheet behind the pill: game type, blinds (+ BB ante in tournaments)
/// and player count. Every tap applies at once through the callbacks, which
/// mutate [setup]; there is no Save.
class GamePillSheet extends StatefulWidget {
  final SingleHandSetup setup;

  /// Levels the player used or typed, shown next to the common ones.
  final Set<BlindLevel> extraLevels;
  final ValueChanged<GameType> onGameType;
  final ValueChanged<BlindLevel> onBlinds;
  final ValueChanged<bool> onAnte;
  final ValueChanged<int> onPlayers;

  /// Tracked session: the session fixes the game type (Cash/Tournament).
  final bool lockGameType;

  const GamePillSheet({
    super.key,
    required this.setup,
    required this.extraLevels,
    required this.onGameType,
    required this.onBlinds,
    required this.onAnte,
    required this.onPlayers,
    this.lockGameType = false,
  });

  static Future<void> show(
    BuildContext context, {
    required SingleHandSetup setup,
    required Set<BlindLevel> extraLevels,
    required ValueChanged<GameType> onGameType,
    required ValueChanged<BlindLevel> onBlinds,
    required ValueChanged<bool> onAnte,
    required ValueChanged<int> onPlayers,
    bool lockGameType = false,
  }) {
    return AppSheet.show<void>(
      context: context,
      title: AppLocalizations.of(context).singleHandV2GameTitle,
      heightFraction: null,
      scrollable: false,
      bodyPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xxs, AppSpacing.md, 0),
      body: GamePillSheet(
        setup: setup,
        extraLevels: extraLevels,
        onGameType: onGameType,
        onBlinds: onBlinds,
        onAnte: onAnte,
        onPlayers: onPlayers,
        lockGameType: lockGameType,
      ),
    );
  }

  @override
  State<GamePillSheet> createState() => _GamePillSheetState();
}

class _GamePillSheetState extends State<GamePillSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.setup.gameType == GameType.cash ? 0 : 1)
    ..addListener(() {
      if (_tabs.indexIsChanging) return;
      final t = _tabs.index == 0 ? GameType.cash : GameType.tournament;
      if (t == widget.setup.gameType) return;
      widget.onGameType(t);
      setState(() {});
    });

  SingleHandSetup get _s => widget.setup;
  BlindLevel get _level => BlindLevel(_s.smallBlind, _s.bigBlind);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Bumped to rebuild the blinds wheel on the current level when "Custom…"
  /// is cancelled or after a new level was typed.
  int _epoch = 0;

  Future<void> _custom() async {
    final r = await AppSheet.show<BlindLevel>(
      context: context,
      title: AppLocalizations.of(context).singleHandBlinds,
      heightFraction: null,
      body: _CustomBlindsForm(sb: _s.smallBlind, bb: _s.bigBlind),
    );
    if (!mounted) return;
    if (r != null) widget.onBlinds(r);
    setState(() => _epoch++);
  }

  void _pickLevel(BlindLevel l) {
    if (l.isCustom) {
      _custom();
      return;
    }
    if (l == _level) return;
    widget.onBlinds(l);
    setState(() {});
  }

  static const double _wheelFraction = 0.2;
  static const double _wheelMax = 220;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levels = BlindLevel.merged(BlindLevel.baseFor(_s.gameType),
        {...widget.extraLevels, _level});
    // The sheet itself does not scroll (a vertical wheel inside a vertical
    // scroll view would fight for the drag); the wheels are sized from the
    // screen height instead.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          ignoring: widget.lockGameType,
          child: Opacity(
            opacity: widget.lockGameType ? 0.5 : 1,
            child: AnimatedSegmentedTabs(
              controller: _tabs,
              labels: [l10n.singleHandCash, l10n.singleHandTourney],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _wheelColumn(
              5,
              l10n.singleHandBlinds,
              AppWheelPicker<BlindLevel>(
                key: ValueKey('blinds$_epoch${_s.gameType.name}'),
                heightFraction: _wheelFraction,
                maxHeight: _wheelMax,
                items: levels,
                selected: _level,
                labelBuilder: (b) => b.isCustom
                    ? l10n.singleHandCustomBlinds
                    : '${_compact(b.sb)}/${_compact(b.bb)}',
                onChanged: _pickLevel,
              ),
              footer: _customButton(l10n),
            ),
            const SizedBox(width: AppSpacing.xxs),
            _wheelColumn(
              3,
              l10n.singleHandPlayers,
              AppWheelPicker<int>(
                heightFraction: _wheelFraction,
                maxHeight: _wheelMax,
                items: const [2, 3, 4, 5, 6, 7, 8, 9],
                selected: _s.playerCount,
                labelBuilder: (n) => '$n',
                onChanged: (n) {
                  if (n == _s.playerCount) return;
                  widget.onPlayers(n);
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        if (_s.gameType == GameType.tournament) ...[
          const SizedBox(height: AppSpacing.xxs),
          Row(children: [
            Expanded(
              child: Text(l10n.singleHandBBAnte,
                  style: AppTypography.bodyMedium()),
            ),
            AppToggle(
              value: _s.hasBBante,
              onChanged: (v) {
                widget.onAnte(v);
                setState(() {});
              },
            ),
          ]),
        ],
      ],
    );
  }

  Widget _wheelColumn(int flex, String label, Widget wheel, {Widget? footer}) =>
      Expanded(
        flex: flex,
        child: Column(children: [_label(label), wheel, if (footer != null) footer]),
      );

  /// Always-visible way into the custom blinds form (the wheel's last item
  /// is easy to miss).
  Widget _customButton(AppLocalizations l10n) => Semantics(
        button: true,
        label: l10n.singleHandV2CustomBlinds,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _custom,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Text(l10n.singleHandV2CustomBlinds,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.labelChip(color: AppColors.accentPrimary)),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: Text(text, style: AppTypography.label(color: AppColors.textSecondary)),
      );
}

/// Custom small/big blind entry. Starts empty: the current blinds are only the
/// hint, so the player types straight away.
class _CustomBlindsForm extends StatefulWidget {
  final double sb;
  final double bb;
  const _CustomBlindsForm({required this.sb, required this.bb});

  @override
  State<_CustomBlindsForm> createState() => _CustomBlindsFormState();
}

class _CustomBlindsFormState extends State<_CustomBlindsForm> {
  final _sb = TextEditingController();
  final _bb = TextEditingController();

  @override
  void dispose() {
    _sb.dispose();
    _bb.dispose();
    super.dispose();
  }

  void _save() {
    final sb = parseDecimal(_sb.text);
    final bb = parseDecimal(_bb.text);
    if (sb == null || bb == null || sb <= 0 || bb <= 0) return;
    Navigator.pop(context, BlindLevel(sb, bb));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatters = [DecimalInputFormatter()];
    const kb = TextInputType.numberWithOptions(decimal: true);
    return Column(
      children: [
        AppTextField(
          label: l10n.singleHandSmallBlind,
          hint: formatBlindValue(widget.sb),
          autofocus: true,
          controller: _sb,
          keyboardType: kb,
          inputFormatters: formatters,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppTextField(
          label: l10n.singleHandBigBlind,
          hint: formatBlindValue(widget.bb),
          controller: _bb,
          keyboardType: kb,
          inputFormatters: formatters,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: l10n.singleHandDone, fullWidth: true, onTap: _save),
      ],
    );
  }
}
