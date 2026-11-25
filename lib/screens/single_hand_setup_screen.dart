import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/components/app_text_field.dart';
import '../design_system/components/buttons/app_button.dart';
import '../design_system/components/sheets/app_sheet.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../models/blind_level.dart';
import '../models/game_types.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart' show formatBlindValue;
import '../models/single_hand_group.dart';
import '../models/single_hand_setup.dart';
import '../services/analytics_service.dart';
import '../services/currency_service.dart';
import '../services/logger_service.dart';
import '../services/single_hand_service.dart';
import '../utils/decimal_input.dart';
import '../widgets/hole_cards_dialog.dart';
import '../widgets/playing_card_face.dart';
import '../widgets/single_hand/single_hand_setup_sheet.dart' show SingleHandStart;
import '../widgets/single_hand/v2/game_pill_sheet.dart';
import '../widgets/single_hand/v2/mini_table_seat_picker.dart';
import '../widgets/single_hand/v2/stack_drag_control.dart';

/// "Log a hand" setup, v2 (flag `single_hand_v2`): a full screen with a game
/// pill, a mini table to pick the seat, one drag for the stack and optional
/// cards. Returns the same [SingleHandStart] as the old sheet.
/// See docs/features/single-hand-setup-v2.md.
class SingleHandSetupScreen extends StatefulWidget {
  final SingleHandSetup setup;

  /// Pre-selected target group ("Log another" keeps the same group). Null runs
  /// the suggestion rule. The group is never shown on this screen.
  final SingleHandGroup? initialGroup;
  final bool keepGroup;

  const SingleHandSetupScreen({
    super.key,
    required this.setup,
    this.initialGroup,
    this.keepGroup = false,
  });

  static const String hintPrefsKey = 'single_hand_v2_stack_hint_seen';

  /// Pushes the screen. Null when closed. Loads the last-used setup when
  /// [setup] is not given.
  static Future<SingleHandStart?> show(
    BuildContext context, {
    SingleHandSetup? setup,
    SingleHandGroup? group,
    bool keepGroup = false,
  }) async {
    final s = setup ?? await SingleHandSetup.loadLastUsed();
    if (!context.mounted) return null;
    return Navigator.of(context).push<SingleHandStart>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SingleHandSetupScreen(
          setup: s,
          initialGroup: group,
          keepGroup: keepGroup,
        ),
      ),
    );
  }

  @override
  State<SingleHandSetupScreen> createState() => _SingleHandSetupScreenState();
}

class _SingleHandSetupScreenState extends State<SingleHandSetupScreen> {
  late final SingleHandSetup _s = widget.setup;
  SingleHandGroup? _group;
  late final bool _groupLocked = widget.keepGroup;
  bool _starting = false;

  /// Blinds the player had on each game type (restored when switching back).
  final Map<GameType, BlindLevel> _remembered = {};
  final Set<BlindLevel> _extras = {};

  BlindLevel get _level => BlindLevel(_s.smallBlind, _s.bigBlind);

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _extras.add(_level);
    if (!_groupLocked && _group == null) _refreshSuggestion();
  }

  Future<void> _refreshSuggestion() async {
    if (_groupLocked) return;
    try {
      final g = await SingleHandService.suggestedGroup(_s);
      if (mounted && !_groupLocked) setState(() => _group = g);
    } catch (e) {
      LoggerService.log('SingleHand suggest failed: $e',
          level: LogLevel.WARNING);
    }
  }

  void _setPlayers(int n) {
    final positions = SingleHandSetup.positionsFor(n);
    setState(() {
      _s.playerCount = n;
      if (!positions.contains(_s.heroPosition)) {
        _s.heroPosition = positions.contains('BTN') ? 'BTN' : positions.last;
      }
    });
  }

  void _setGame(GameType t) {
    if (_s.gameType == t) return;
    _remembered[_s.gameType] = _level;
    setState(() {
      _s.gameType = t;
      _applyLevel(_remembered[t] ?? BlindLevel.defaultFor(t));
    });
    _refreshSuggestion();
  }

  void _applyLevel(BlindLevel l) {
    _s.smallBlind = l.sb;
    _s.bigBlind = l.bb;
    _extras.add(l);
  }

  void _setBlinds(BlindLevel l) {
    if (l == _level) return;
    setState(() => _applyLevel(l));
    _refreshSuggestion();
  }

  Future<void> _openPill() => GamePillSheet.show(
        context,
        setup: _s,
        extraLevels: _extras,
        onGameType: _setGame,
        onBlinds: _setBlinds,
        onAnte: (v) => setState(() => _s.hasBBante = v),
        onPlayers: _setPlayers,
      );

  String _fmt(double v) =>
      NumberFormat('#,##0.##', Localizations.localeOf(context).toString())
          .format(v);

  bool get _cash => _s.gameType == GameType.cash;

  String _mainLabel(AppLocalizations l10n, double bb) {
    if (!_cash) return l10n.singleHandV2BBValue(_fmt(bb));
    final amount = SingleHandSetup.bbToAmount(bb, _s.bigBlind);
    return amount == amount.roundToDouble()
        ? CurrencyService.formatCashRounded(amount)
        : CurrencyService.formatCash(amount);
  }

  String _subLabel(AppLocalizations l10n, double bb) => _cash
      ? l10n.singleHandStackEqualsBB(_fmt(bb))
      : l10n.singleHandStackEqualsChips(
          _fmt(SingleHandSetup.bbToAmount(bb, _s.bigBlind)));

  Future<void> _typeStack() async {
    final l10n = AppLocalizations.of(context);
    final shown = _cash
        ? SingleHandSetup.bbToAmount(_s.stackBB, _s.bigBlind)
        : _s.stackBB;
    final bb = await AppSheet.show<double>(
      context: context,
      title: l10n.singleHandV2ExactTitle,
      heightFraction: null,
      body: _StackKeypad(
        initial: shown,
        unit: _cash ? StackUnit.amount : StackUnit.bb,
        bigBlind: _s.bigBlind,
        label: _cash ? CurrencyService.symbol : 'BB',
      ),
    );
    if (bb != null && mounted) setState(() => _s.stackBB = bb);
  }

  Future<void> _pickCards() async {
    final existing = (_s.card1 == null && _s.card2 == null)
        ? null
        : HoleCards(card1: _s.card1, card2: _s.card2);
    final r = await showDialog<HoleCards>(
      context: context,
      builder: (_) => HoleCardsDialog(
        existingCards: existing,
        title: AppLocalizations.of(context).singleHandCards,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _s.card1 = (r.card1 ?? '').isEmpty ? null : r.card1;
      _s.card2 = (r.card2 ?? '').isEmpty ? null : r.card2;
    });
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _s.saveAsLastUsed();
    } catch (e) {
      LoggerService.log('SingleHand save setup: $e', level: LogLevel.WARNING);
    }
    AnalyticsService.singleHandStarted(newGroup: _group == null, variant: 'v2');
    if (mounted) Navigator.pop(context, SingleHandStart(_s, _group));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs,
                AppSpacing.md, safeBottom + AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: c.maxHeight - safeBottom - AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(l10n),
                  _table(l10n),
                  _stack(l10n),
                  _cardsRow(l10n),
                  AppButton(
                      label: l10n.singleHandStart,
                      fullWidth: true,
                      onTap: _start),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(AppLocalizations l10n) {
    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: GamePill(text: gamePillText(l10n, _s), onTap: _openPill),
          ),
        ),
      ],
    );
  }

  Widget _table(AppLocalizations l10n) {
    return Column(
      children: [
        MiniTableSeatPicker(
          positions: SingleHandSetup.positionsFor(_s.playerCount),
          heroPosition: _s.heroPosition,
          onChanged: (p) => setState(() => _s.heroPosition = p),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(l10n.singleHandV2SeatHint,
            textAlign: TextAlign.center,
            style: AppTypography.caption(color: AppColors.textDisabled)),
      ],
    );
  }

  Widget _stack(AppLocalizations l10n) {
    return Column(
      children: [
        StackDragControl(
          steps: SingleHandSetup.stackStepsBB(_s.gameType),
          value: _s.stackBB,
          mainLabel: (v) => _mainLabel(l10n, v),
          subLabel: (v) => _subLabel(l10n, v),
          onChanged: (v) => setState(() => _s.stackBB = v),
          onTapNumber: _typeStack,
          hintPrefsKey: SingleHandSetupScreen.hintPrefsKey,
          semanticsLabel: l10n.singleHandV2StackLabel,
          increaseLabel: l10n.singleHandV2StackUp,
          decreaseLabel: l10n.singleHandV2StackDown,
        ),
        Text(l10n.singleHandV2StackHint,
            textAlign: TextAlign.center,
            style: AppTypography.caption(color: AppColors.textDisabled)),
      ],
    );
  }

  Widget _cardsRow(AppLocalizations l10n) {
    final cards = [_s.card1, _s.card2];
    final w = PlayingCardFace.responsiveWidth(context);
    return Semantics(
      button: true,
      label: l10n.singleHandCards,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pickCards,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in cards)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxxs),
                    child: c == null
                        ? _emptyCard(w)
                        : PlayingCardFace(c, width: w),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(l10n.singleHandCards,
                style: AppTypography.caption(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(double w) => Container(
        width: w,
        height: w * 1.4,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text('?', style: AppTypography.cardTitle()),
      );
}

/// Exact stack entry: cash in money, tournament in BB. Pops the value in BB.
class _StackKeypad extends StatefulWidget {
  final double initial;
  final StackUnit unit;
  final double bigBlind;
  final String label;
  const _StackKeypad(
      {required this.initial,
      required this.unit,
      required this.bigBlind,
      required this.label});

  @override
  State<_StackKeypad> createState() => _StackKeypadState();
}

class _StackKeypadState extends State<_StackKeypad> {
  late final TextEditingController _ctl =
      TextEditingController(text: formatBlindValue(widget.initial));

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _done() {
    final bb = SingleHandSetup.stackToBB(
        parseDecimal(_ctl.text), widget.unit, widget.bigBlind);
    if (bb == null) return;
    Navigator.pop(context, bb);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          label: '${AppLocalizations.of(context).singleHandStack} (${widget.label})',
          hint: '',
          autofocus: true,
          controller: _ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [DecimalInputFormatter()],
          showClearButton: false,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
            label: AppLocalizations.of(context).singleHandDone,
            fullWidth: true,
            onTap: _done),
      ],
    );
  }
}
