import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design_system/components/app_text_field.dart';
import '../../design_system/components/app_toggle.dart';
import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/dividers/list_separator.dart';
import '../../design_system/components/pickers/app_wheel_picker.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/components/tabs/animated_segmented_tabs.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/blind_level.dart';
import '../../models/game_types.dart';
import '../../models/hand_state_machine.dart';
import '../../models/poker_game_state.dart' show formatBlindValue;
import '../../models/single_hand_group.dart';
import '../../models/single_hand_setup.dart';
import '../../services/analytics_service.dart';
import '../../services/logger_service.dart';
import '../../services/single_hand_service.dart';
import '../../services/currency_service.dart';
import '../../utils/decimal_input.dart';
import '../../utils/number_formatter.dart';
import '../hole_cards_dialog.dart';
import '../playing_card_face.dart';

/// What the setup sheet hands back when the player taps "Start hand".
/// [group] null means "create a new group".
class SingleHandStart {
  final SingleHandSetup setup;
  final SingleHandGroup? group;
  const SingleHandStart(this.setup, this.group);
}

/// Setup sheet of the "Log a hand" flow: game, blinds, players, hero
/// position, one stack (in BB) and optional hero cards. Zero to two taps when
/// the last-used values fit.
class SingleHandSetupSheet extends StatefulWidget {
  final SingleHandSetup setup;

  /// Pre-selected target group ("Log another" keeps the same group). Null runs
  /// the suggestion rule.
  final SingleHandGroup? initialGroup;
  final bool keepGroup;

  const SingleHandSetupSheet({
    super.key,
    required this.setup,
    this.initialGroup,
    this.keepGroup = false,
  });

  /// Shows the sheet. Null when dismissed. Loads the last-used setup when
  /// [setup] is not given.
  static Future<SingleHandStart?> show(
    BuildContext context, {
    SingleHandSetup? setup,
    SingleHandGroup? group,
    bool keepGroup = false,
  }) async {
    final s = setup ?? await SingleHandSetup.loadLastUsed();
    if (!context.mounted) return null;
    return showModalBottomSheet<SingleHandStart>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SingleHandSetupSheet(
        setup: s,
        initialGroup: group,
        keepGroup: keepGroup,
      ),
    );
  }

  @override
  State<SingleHandSetupSheet> createState() => _SingleHandSetupSheetState();
}

class _SingleHandSetupSheetState extends State<SingleHandSetupSheet>
    with TickerProviderStateMixin {
  late final SingleHandSetup _s = widget.setup;
  late final TextEditingController _stackCtl = TextEditingController(
      text: formatBlindValue(widget.setup.stackUnit == StackUnit.bb
          ? widget.setup.stackBB
          : SingleHandSetup.bbToAmount(
              widget.setup.stackBB, widget.setup.bigBlind)));
  SingleHandGroup? _group;
  bool _groupLocked = false;
  bool _starting = false;

  /// Blinds the player had on each game type (restored when switching back).
  final Map<GameType, BlindLevel> _remembered = {};

  /// Custom / last-used levels added to each game type's wheel.
  final Map<GameType, Set<BlindLevel>> _extras = {
    GameType.cash: {},
    GameType.tournament: {},
  };

  /// Bumped to rebuild the blinds wheel when a "Custom…" pick is cancelled.
  int _blindsEpoch = 0;

  BlindLevel get _level => BlindLevel(_s.smallBlind, _s.bigBlind);

  List<BlindLevel> get _levels =>
      BlindLevel.merged(BlindLevel.baseFor(_s.gameType), _extras[_s.gameType]!);

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _groupLocked = widget.keepGroup;
    _extras[_s.gameType]!.add(_level);
    _gameTabs = TabController(
        length: 2,
        vsync: this,
        initialIndex: _s.gameType == GameType.cash ? 0 : 1)
      ..addListener(() {
        if (_gameTabs.indexIsChanging) return;
        _setGame(_gameTabs.index == 0 ? GameType.cash : GameType.tournament);
      });
    _unitTabs =
        TabController(length: 2, vsync: this, initialIndex: _s.stackUnit.index)
          ..addListener(() {
            if (_unitTabs.indexIsChanging) return;
            setState(() => _s.stackUnit = StackUnit.values[_unitTabs.index]);
          });
    _spreadTabs = TabController(
        length: StackSpread.values.length,
        vsync: this,
        initialIndex: _s.stackSpread.index)
      ..addListener(() {
        if (_spreadTabs.indexIsChanging) return;
        setState(() => _s.stackSpread = StackSpread.values[_spreadTabs.index]);
      });
    if (!_groupLocked && _group == null) _refreshSuggestion();
  }

  /// Chips-or-money / BB input unit tabs (index = [StackUnit] index).
  late final TabController _unitTabs;

  /// Typed stack in BB at the current blinds and unit; null when empty/zero.
  double? get _stackBB => SingleHandSetup.stackToBB(
      parseDecimal(_stackCtl.text), _s.stackUnit, _s.bigBlind);

  /// Same / Near / Similar stack spread tabs.
  late final TabController _spreadTabs;

  /// Cash / Tournament tabs (same component as Session History).
  late final TabController _gameTabs;

  @override
  void dispose() {
    _gameTabs.dispose();
    _spreadTabs.dispose();
    _unitTabs.dispose();
    _stackCtl.dispose();
    super.dispose();
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
    final next = _remembered[t] ?? BlindLevel.defaultFor(t);
    final bb = _stackBB;
    setState(() {
      _s.gameType = t;
      _applyLevel(next);
      if (bb != null) {
        _stackCtl.text = formatBlindValue(_s.stackUnit == StackUnit.bb
            ? bb
            : SingleHandSetup.bbToAmount(bb, _s.bigBlind));
      }
    });
    _unitTabs.index = _s.stackUnit.index;
    _refreshSuggestion();
  }

  Future<void> _pickGroup() async {
    final l10n = AppLocalizations.of(context);
    List<SingleHandGroup> groups = const [];
    try {
      groups = await SingleHandService.recentGroups(limit: 5);
    } catch (e) {
      LoggerService.log('SingleHand groups failed: $e',
          level: LogLevel.WARNING);
    }
    if (!mounted) return;
    final picked = await AppSheet.show<_GroupPick>(
      context: context,
      title: l10n.singleHandChooseGroup,
      heightFraction: null,
      body: _GroupList(groups: groups, selected: _group?.sessionId),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _group = picked.group;
      _groupLocked = true;
    });
  }

  void _applyLevel(BlindLevel l) {
    _s.smallBlind = l.sb;
    _s.bigBlind = l.bb;
    _extras[_s.gameType]!.add(l);
  }

  void _onLevel(BlindLevel l) {
    if (l.isCustom) {
      _customBlinds();
      return;
    }
    if (l == _level) return;
    setState(() => _applyLevel(l));
    _refreshSuggestion();
  }

  Future<void> _customBlinds() async {
    final r = await AppSheet.show<_BlindsEdit>(
      context: context,
      title: AppLocalizations.of(context).singleHandBlinds,
      heightFraction: null,
      body: _BlindsEditor(sb: _s.smallBlind, bb: _s.bigBlind),
    );
    if (!mounted) return;
    setState(() {
      if (r == null) {
        _blindsEpoch++; // snap the wheel back to the current level
      } else {
        _applyLevel(BlindLevel(r.sb, r.bb));
        _blindsEpoch++;
      }
    });
    if (r != null) _refreshSuggestion();
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
    final stack = _stackBB;
    if (stack == null) return;
    _starting = true;
    _s.stackBB = stack;
    _s.rollStacks();
    try {
      await _s.saveAsLastUsed();
    } catch (e) {
      LoggerService.log('SingleHand save setup: $e', level: LogLevel.WARNING);
    }
    AnalyticsService.singleHandStarted(newGroup: _group == null);
    if (mounted) Navigator.pop(context, SingleHandStart(_s, _group));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final positions = SingleHandSetup.positionsFor(_s.playerCount);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return AppSheet(
      title: l10n.singleHandCardTitle,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _groupRow(l10n),
                  const SizedBox(height: AppSpacing.xs),
                  _gameSelector(l10n),
                  const SizedBox(height: AppSpacing.xs),
                  _wheels(l10n, positions),
                  const SizedBox(height: AppSpacing.xs),
                  _anteRow(l10n),
                  const SizedBox(height: AppSpacing.xs),
                  _stackRow(l10n),
                  const SizedBox(height: AppSpacing.xs),
                  _cardsRow(l10n),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
                top: AppSpacing.xs, bottom: safeBottom + AppSpacing.xl),
            child: AppButton(
              label: l10n.singleHandStart,
              fullWidth: true,
              onTap: _start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupRow(AppLocalizations l10n) {
    final g = _group;
    final text = g == null
        ? l10n.singleHandNewGroup
        : '${g.name} · ${l10n.singleHandGroupHands(g.handCount)}';
    return _SettingRow(
      onTap: _pickGroup,
      child: Text(
        l10n.singleHandAddingTo(text),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.listRowLabel(),
      ),
    );
  }

  Widget _gameSelector(AppLocalizations l10n) {
    return AnimatedSegmentedTabs(
      controller: _gameTabs,
      labels: [l10n.singleHandCash, l10n.singleHandTourney],
    );
  }

  Widget _anteRow(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(l10n.singleHandBBAnte, style: AppTypography.bodyMedium()),
        ),
        AppToggle(
          value: _s.hasBBante,
          onChanged: (v) => setState(() => _s.hasBBante = v),
        ),
      ],
    );
  }

  static const double _wheelFraction = 0.24;
  static const double _wheelMax = 260;

  /// 5000 -> "5K", 1500 -> "1.5K"; small values stay exact (0.25).
  static String _compactBlind(double v) =>
      v >= 1000 ? formatCompactNumber(v) : formatBlindValue(v);

  Widget _wheels(AppLocalizations l10n, List<String> positions) {
    Widget column(int flex, String label, Widget wheel) => Expanded(
          flex: flex,
          child: Column(
            children: [
              Text(label,
                  style: AppTypography.label(color: AppColors.textSecondary)),
              wheel,
            ],
          ),
        );
    return Row(
      children: [
        column(
          5,
          l10n.singleHandBlinds,
          AppWheelPicker<BlindLevel>(
            heightFraction: _wheelFraction,
            maxHeight: _wheelMax,
            key: ValueKey('blinds$_blindsEpoch'),
            items: _levels,
            selected: _level,
            labelBuilder: (b) => b.isCustom
                ? l10n.singleHandCustomBlinds
                : '${_compactBlind(b.sb)}/${_compactBlind(b.bb)}',
            onChanged: _onLevel,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        column(
          3,
          l10n.singleHandPlayers,
          AppWheelPicker<int>(
            heightFraction: _wheelFraction,
            maxHeight: _wheelMax,
            items: const [2, 3, 4, 5, 6, 7, 8, 9],
            selected: _s.playerCount,
            labelBuilder: (n) => '$n',
            onChanged: _setPlayers,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        column(
          4,
          l10n.singleHandYouAre,
          AppWheelPicker<String>(
            heightFraction: _wheelFraction,
            maxHeight: _wheelMax,
            items: positions,
            selected: _s.heroPosition,
            labelBuilder: (p) => p,
            onChanged: (p) => setState(() => _s.heroPosition = p),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) =>
      NumberFormat('#,##0.##', Localizations.localeOf(context).toString())
          .format(v);

  String _amountLabel(AppLocalizations l10n) => _s.gameType == GameType.cash
      ? CurrencyService.symbol
      : l10n.singleHandUnitChips;

  /// "= 260 BB" when typing chips/money, "= 10,400 chips" / "= $200" in BB.
  String? _conversionLine(AppLocalizations l10n, double? bb) {
    if (bb == null) return null;
    if (_s.stackUnit == StackUnit.amount) {
      return l10n.singleHandStackEqualsBB(_fmt(bb));
    }
    final amount = SingleHandSetup.bbToAmount(bb, _s.bigBlind);
    return _s.gameType == GameType.cash
        ? '= ${CurrencyService.formatCash(amount)}'
        : l10n.singleHandStackEqualsChips(_fmt(amount));
  }

  Widget _stackWarning(AppLocalizations l10n, double bb) {
    final low = bb < 1;
    final high = bb > 1000;
    if (!low && !high) return const SizedBox.shrink();
    final cash = _s.gameType == GameType.cash;
    final text = low
        ? l10n.singleHandStackWarnLow
        : (cash
            ? l10n.singleHandStackWarnMoney(_fmt(bb))
            : l10n.singleHandStackWarnChips(_fmt(bb)));
    final fixUnit = low ? StackUnit.bb : StackUnit.amount;
    final fix = low
        ? l10n.singleHandUseBB
        : (cash ? l10n.singleHandUseMoney : l10n.singleHandUseChips);
    final showFix = _s.stackUnit != fixUnit;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        border: Border.all(color: AppColors.warningAmber),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: AppColors.warningAmber),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(text,
                style: AppTypography.bodySmall(color: AppColors.warningAmber)),
          ),
          if (showFix)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _s.stackUnit = fixUnit);
                _unitTabs.index = fixUnit.index;
              },
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xxs),
                child: Text(fix,
                    style: AppTypography.bodySmall(
                        color: AppColors.accentPrimary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stackRow(AppLocalizations l10n) {
    final bb = _stackBB;
    final line = _conversionLine(l10n, bb);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.4,
              child: AppTextField(
                label: l10n.singleHandStack,
                hint: '100',
                controller: _stackCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter()],
                showClearButton: false,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedSegmentedTabs(
                controller: _unitTabs,
                labels: [_amountLabel(l10n), 'BB'],
              ),
            ),
          ],
        ),
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxxs),
            child: Text(line,
                style: AppTypography.bodySmall(color: AppColors.textSecondary)),
          ),
        if (bb != null) _stackWarning(l10n, bb),
        const SizedBox(height: AppSpacing.xxs),
        AnimatedSegmentedTabs(
          controller: _spreadTabs,
          labels: [
            l10n.singleHandSpreadSame,
            l10n.singleHandSpreadNear,
            l10n.singleHandSpreadSimilar,
          ],
        ),
      ],
    );
  }

  Widget _cardsRow(AppLocalizations l10n) {
    final cards = [_s.card1, _s.card2].whereType<String>().toList();
    final w = PlayingCardFace.responsiveWidth(context);
    return _SettingRow(
      onTap: _pickCards,
      child: Row(
        children: [
          Expanded(
            child:
                Text(l10n.singleHandCards, style: AppTypography.listRowLabel()),
          ),
          if (cards.isEmpty)
            Text(l10n.singleHandAddCards,
                style:
                    AppTypography.listRowLabel(color: AppColors.accentPrimary))
          else
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xxxs),
                child: PlayingCardFace(c, width: w),
              ),
        ],
      ),
    );
  }
}

/// Tappable surface row with a trailing chevron (group, blinds, cards).
class _SettingRow extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _SettingRow({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            Expanded(child: child),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _GroupPick {
  final SingleHandGroup? group;
  const _GroupPick(this.group);
}

class _GroupList extends StatelessWidget {
  final List<SingleHandGroup> groups;
  final String? selected;
  const _GroupList({required this.groups, required this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget row(String title, String? sub, bool sel, SingleHandGroup? g) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, _GroupPick(g)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.listRowLabel()),
                    if (sub != null)
                      Text(sub,
                          style: AppTypography.bodySmall(
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (sel) const Icon(Icons.check, color: AppColors.accentPrimary),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        row(l10n.singleHandNewGroup, null, selected == null, null),
        for (final g in groups) ...[
          const ListSeparator(),
          row(g.name, l10n.singleHandGroupHands(g.handCount),
              g.sessionId == selected, g),
        ],
      ],
    );
  }
}

class _BlindsEdit {
  final double sb;
  final double bb;
  const _BlindsEdit(this.sb, this.bb);
}

class _BlindsEditor extends StatefulWidget {
  final double sb;
  final double bb;
  const _BlindsEditor({required this.sb, required this.bb});

  @override
  State<_BlindsEditor> createState() => _BlindsEditorState();
}

class _BlindsEditorState extends State<_BlindsEditor> {
  // Start EMPTY: the current blinds are only the hint, so the player can type
  // straight away without deleting anything.
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
    Navigator.pop(context, _BlindsEdit(sb, bb));
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
