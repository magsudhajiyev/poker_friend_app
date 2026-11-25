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
import '../models/tracked_session.dart';
import '../services/analytics_service.dart';
import '../services/currency_service.dart';
import '../services/logger_service.dart';
import '../services/single_hand_service.dart';
import '../utils/decimal_input.dart';
import '../widgets/hole_cards_dialog.dart';
import '../widgets/playing_card_face.dart';
import '../widgets/single_hand/saving_to_sheet.dart';
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

  /// A running tracked session the hand is saved inside (D23). Its game type
  /// is locked; the "Saving to" line lets the player pick a hand group.
  final SingleHandSessionTarget? session;

  /// One line shown instead of the "Saving to" line (e.g. the running full
  /// session cannot be resumed, so the hand goes to a hand group).
  final String? note;

  const SingleHandSetupScreen({
    super.key,
    required this.setup,
    this.initialGroup,
    this.keepGroup = false,
    this.session,
    this.note,
  });

  static const String hintPrefsKey = 'single_hand_v2_stack_hint_seen';

  /// Pushes the screen. Null when closed. Loads the last-used setup when
  /// [setup] is not given.
  static Future<SingleHandStart?> show(
    BuildContext context, {
    SingleHandSetup? setup,
    SingleHandGroup? group,
    bool keepGroup = false,
    SingleHandSessionTarget? session,
    String? note,
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
          session: session,
          note: note,
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

  /// Tracked session target; null once the player picked a hand group.
  late SingleHandSessionTarget? _session = widget.session;


  /// The player chose a group (or "new") on the Saving-to sheet: no suggestion.
  bool _pickedGroup = false;

  /// Blinds the player had on each game type (restored when switching back).
  final Map<GameType, BlindLevel> _remembered = {};
  final Set<BlindLevel> _extras = {};

  BlindLevel get _level => BlindLevel(_s.smallBlind, _s.bigBlind);

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    final locked =
        widget.session?.isFull == true ? null : widget.session?.gameType;
    if (locked != null && _s.gameType != locked) {
      _s.gameType = locked;
      _applyLevel(BlindLevel.defaultFor(locked));
    }
    _extras.add(_level);
    if (!_groupLocked && _group == null && _session == null) {
      _refreshSuggestion();
    }
  }

  Future<void> _refreshSuggestion() async {
    if (_groupLocked || _session != null || _pickedGroup) return;
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

  /// The session fixes the game type; a hand group does not.
  bool get _gameLocked => _session != null && !_session!.isFull;

  void _setGame(GameType t) {
    if (_s.gameType == t || _gameLocked) return;
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
        lockGameType: _gameLocked,
      );

  Future<void> _pickTarget() async {
    final session = widget.session;
    if (session == null) return;
    final choice = await SavingToSheet.show(context,
        session: session, sessionSelected: _session != null);
    if (choice == null || !mounted) return;
    setState(() {
      if (choice.session) {
        _session = session;
        _pickedGroup = false;
        _group = null;
        if (!session.isFull && _s.gameType != session.gameType) {
          _s.gameType = session.gameType;
          _applyLevel(BlindLevel.defaultFor(session.gameType));
        }
      } else {
        _session = null;
        _pickedGroup = true;
        _group = choice.group;
      }
    });
  }

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

  /// A session-forced game type (and its blinds) must not become the player's
  /// last-used setup: keep the stored game type and blinds, save the rest.
  Future<void> _saveLastUsed() async {
    if (widget.session == null || widget.session!.isFull) {
      return _s.saveAsLastUsed();
    }
    final last = await SingleHandSetup.loadLastUsed();
    final type = _s.gameType, sb = _s.smallBlind, bb = _s.bigBlind;
    _s.gameType = last.gameType;
    _s.smallBlind = last.smallBlind;
    _s.bigBlind = last.bigBlind;
    try {
      await _s.saveAsLastUsed();
    } finally {
      _s.gameType = type;
      _s.smallBlind = sb;
      _s.bigBlind = bb;
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _saveLastUsed();
    } catch (e) {
      LoggerService.log('SingleHand save setup: $e', level: LogLevel.WARNING);
    }
    AnalyticsService.singleHandStarted(
        newGroup: _group == null && _session == null, variant: 'v2');
    if (mounted) {
      Navigator.pop(context, SingleHandStart(_s, _group, session: _session));
    }
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
                  if (widget.session != null) _savingTo(l10n),
                  if (widget.session == null && widget.note != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                      child: Text(widget.note!,
                          key: const ValueKey('setup-note'),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall(
                              color: AppColors.textSecondary)),
                    ),
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

  /// "Saving to <session>" line (D23): tap to pick a hand group instead.
  Widget _savingTo(AppLocalizations l10n) {
    final inSession = _session != null;
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const ValueKey('saving-to'),
        behavior: HitTestBehavior.opaque,
        onTap: _pickTarget,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  inSession
                      ? (_session!.isFull
                          ? l10n.trackedSavingToResumeTable(_session!.name)
                          : l10n.trackedSavingTo(_session!.name))
                      : l10n.trackedSavingToGroup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.bodySmall(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xxxs),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
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
