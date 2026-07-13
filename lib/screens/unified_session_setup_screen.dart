import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/currency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart' show formatBlindValue;
import '../services/display_identity_service.dart';
import '../widgets/poker_table_widget.dart';
import '../widgets/seat_config_sheet.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'poker_hand_screen.dart';
import 'session_details_screen.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/components/headers/top_nav_bar.dart';

class UnifiedSessionSetupScreen extends StatefulWidget {
  const UnifiedSessionSetupScreen({super.key});

  @override
  State<UnifiedSessionSetupScreen> createState() =>
      _UnifiedSessionSetupScreenState();
}

class _UnifiedSessionSetupScreenState extends State<UnifiedSessionSetupScreen> {
  // ─── Onboarding ─────────────────────────────────────────────────
  final GlobalKey _tableSectionKey = GlobalKey(debugLabel: 'tableSection');
  final ScrollController _scrollController = ScrollController();

  // ─── Form controllers ────────────────────────────────────────────
  final TextEditingController _sessionNameController = TextEditingController();
  final TextEditingController _buyInController = TextEditingController();
  final TextEditingController _startingStackController = TextEditingController();
  final TextEditingController _sbController = TextEditingController(text: '1');
  final TextEditingController _bbController = TextEditingController(text: '2');
  final FocusNode _sbFocusNode = FocusNode();
  final FocusNode _bbFocusNode = FocusNode();
  final FocusNode _buyInFocusNode = FocusNode();
  final FocusNode _startingStackFocusNode = FocusNode();
  bool _isSBFocused = false;
  bool _isBBFocused = false;
  bool _isBuyInFocused = false;
  bool _isStartingStackFocused = false;

  // ─── Session settings ────────────────────────────────────────────
  GameType _gameType = GameType.cash;
  double _smallBlind = 1.0;
  double _bigBlind = 2.0;
  bool _hasBBante = false;

  // ─── Table state ─────────────────────────────────────────────────
  int _buttonPosition = 1;
  int? _heroSeat;
  final Map<int, bool> _seatActive = {};
  final Map<int, String> _seatNames = {};
  final Map<int, double> _seatStacks = {};
  String _heroName = '';

  // ─── SharedPreferences keys ──────────────────────────────────────
  static const _kLastGameType = 'unified_last_game_type';
  static const _kLastSmallBlind = 'unified_last_sb';
  static const _kLastBigBlind = 'unified_last_bb';
  static const _kLastBuyIn = 'unified_last_buyin';
  static const _kLastHasBBante = 'unified_last_bb_ante';

  // ─── Validation ──────────────────────────────────────────────────
  bool get _isFormValid {
    final sb = double.tryParse(_sbController.text);
    final bb = double.tryParse(_bbController.text);
    final hasBlinds = (sb != null && sb > 0) && (bb != null && bb > 0);
    final hasBuyIn = _buyInController.text.isNotEmpty &&
        double.tryParse(_buyInController.text) != null;
    final hasHero = _heroSeat != null;

    if (_gameType == GameType.tournament) {
      final stack = double.tryParse(_startingStackController.text);
      return hasBlinds && hasBuyIn && hasHero && stack != null && stack >= _bigBlind;
    }

    return hasBlinds && hasBuyIn && hasHero;
  }

  @override
  void initState() {
    super.initState();
    _initSeats();
    _loadHeroName();
    _scheduleOnboardingTour();
    _sbFocusNode.addListener(() => setState(() => _isSBFocused = _sbFocusNode.hasFocus));
    _bbFocusNode.addListener(() => setState(() => _isBBFocused = _bbFocusNode.hasFocus));
    _buyInFocusNode.addListener(() => setState(() => _isBuyInFocused = _buyInFocusNode.hasFocus));
    _startingStackFocusNode.addListener(() => setState(() => _isStartingStackFocused = _startingStackFocusNode.hasFocus));
  }

  void _initSeats() {
    for (int i = 1; i <= 9; i++) {
      _seatActive[i] = false;
      _seatNames[i] = '';
      _seatStacks[i] = 0;
    }
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGameType = prefs.getString(_kLastGameType);
    final savedSB = prefs.getDouble(_kLastSmallBlind) ?? prefs.getInt(_kLastSmallBlind)?.toDouble();
    final savedBB = prefs.getDouble(_kLastBigBlind) ?? prefs.getInt(_kLastBigBlind)?.toDouble();
    final savedBuyIn = prefs.getDouble(_kLastBuyIn);
    final savedBBante = prefs.getBool(_kLastHasBBante);

    if (!mounted) return;
    setState(() {
      if (savedGameType == 'tournament') {
        _gameType = GameType.tournament;
        _smallBlind = savedSB ?? 100.0;
        _bigBlind = savedBB ?? 200.0;
      } else {
        _gameType = GameType.cash;
        _smallBlind = savedSB ?? 1.0;
        _bigBlind = savedBB ?? 2.0;
      }
      if (savedBuyIn != null) {
        _buyInController.text = savedBuyIn.toStringAsFixed(
            savedBuyIn == savedBuyIn.roundToDouble() ? 0 : 2);
      }
      if (savedBBante != null) _hasBBante = savedBBante;
    });
    _sbController.text = formatBlindValue(_smallBlind);
    _bbController.text = formatBlindValue(_bigBlind);
  }

  Future<void> _loadHeroName() async {
    final name = await DisplayIdentityService.getDisplayIdentity();
    if (mounted) setState(() => _heroName = name);
  }

  void _scheduleOnboardingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 2) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      SessionSetupTour(
        onFinished: _showTableTourIfPending,
      ).show(context);
    });
  }

  void _showTableTourIfPending() {
    if (!OnboardingState.isOnboardingActive ||
        !OnboardingState.tableTourPending) return;

    OnboardingState.tableTourPending = false;
    OnboardingState.advanceTo(3);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || _tableSectionKey.currentContext == null) return;
      SeatSetupTour(tableKey: _tableSectionKey).show(context);
    });
  }

  Future<void> _saveDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLastGameType, _gameType == GameType.tournament ? 'tournament' : 'cash');
    await prefs.setDouble(_kLastSmallBlind, _smallBlind);
    await prefs.setDouble(_kLastBigBlind, _bigBlind);
    final buyIn = double.tryParse(_buyInController.text);
    if (buyIn != null) await prefs.setDouble(_kLastBuyIn, buyIn);
    await prefs.setBool(_kLastHasBBante, _hasBBante);
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _buyInController.dispose();
    _startingStackController.dispose();
    _sbController.dispose();
    _bbController.dispose();
    _sbFocusNode.dispose();
    _bbFocusNode.dispose();
    _buyInFocusNode.dispose();
    _startingStackFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── SESSION START ───────────────────────────────────────────────

  void _startSession() {
    if (!_isFormValid) return;

    final buyIn = double.parse(_buyInController.text);
    final startingStack = _gameType == GameType.cash
        ? buyIn
        : double.parse(_startingStackController.text);
    final l10n = AppLocalizations.of(context);
    final sessionName = _sessionNameController.text.isNotEmpty
        ? _sessionNameController.text
        : l10n.handSessionTitle;

    final sessionManager = PokerSessionManager(
      smallBlind: _smallBlind,
      bigBlind: _bigBlind,
      playerCount: 9,
      gameType: _gameType,
      sessionName: sessionName,
      initialBuyIn: buyIn,
      startingStack: startingStack,
    );

    for (int seat = 1; seat <= 9; seat++) {
      if (_seatActive[seat] == true) {
        final name = _seatNames[seat] ?? 'Player $seat';
        sessionManager.addPlayer(seat, name.isEmpty ? 'Player $seat' : name);
        final stack = _seatStacks[seat] ?? startingStack;
        sessionManager.setPlayerStack(seat, stack > 0 ? stack : startingStack);
      }
    }

    if (_heroSeat != null && _seatActive[_heroSeat!] != true) {
      final l10n = AppLocalizations.of(context);
      sessionManager.addPlayer(_heroSeat!, _heroName.isNotEmpty ? _heroName : l10n.setupHero);
      sessionManager.setPlayerStack(_heroSeat!, startingStack);
    }

    int buttonPos = _buttonPosition;
    if (_seatActive[buttonPos] != true) {
      for (int seat = 1; seat <= 9; seat++) {
        if (_seatActive[seat] == true) {
          buttonPos = seat;
          break;
        }
      }
    }

    // Set onboarding flag for the new Session Details hub tour step
    if (OnboardingState.isOnboardingActive) {
      OnboardingState.sessionDetailsHubTourPending = true;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(
          sessionName: sessionName,
          buyInAmount: buyIn,
          startingStack: startingStack,
          gameType: _gameType,
          smallBlind: _smallBlind,
          bigBlind: _bigBlind,
          hasBBante: _hasBBante,
          sessionManager: sessionManager,
          heroSeat: _heroSeat,
          initialButtonPosition: buttonPos,
          ante: _hasBBante ? _bigBlind : 0,
        ),
      ),
    );
  }

  // ─── SEAT TAP HANDLER ───────────────────────────────────────────

  void _onSeatTap(int seatNumber) {
    final isActive = _seatActive[seatNumber] ?? false;
    final buyIn = double.tryParse(_buyInController.text) ?? 0;
    final defaultStack = _gameType == GameType.cash
        ? buyIn
        : (double.tryParse(_startingStackController.text) ?? 0);

    final seatedPlayers = <String, int>{};
    for (int s = 1; s <= 9; s++) {
      if (_seatActive[s] == true && (_seatNames[s]?.isNotEmpty ?? false)) {
        seatedPlayers[_seatNames[s]!.toLowerCase()] = s;
      }
    }

    SeatConfigSheet.show(
      context: context,
      seatNumber: seatNumber,
      initialName: _seatNames[seatNumber] ?? '',
      initialStack: _seatStacks[seatNumber] ?? defaultStack,
      isHero: _heroSeat == seatNumber,
      isActive: isActive,
      defaultStack: defaultStack > 0 ? defaultStack : 100,
      heroName: _heroName,
      seatedPlayers: seatedPlayers,
      isCash: _gameType == GameType.cash,
      onSave: ({
            required String name,
            required double stack,
            required bool isHero,
            required bool isActive,
          }) {
            setState(() {
              if (isHero) {
                if (_heroSeat != null && _heroSeat != seatNumber) {
                  _seatActive[_heroSeat!] = false;
                  _seatNames[_heroSeat!] = '';
                  _seatStacks[_heroSeat!] = 0;
                }
                _heroSeat = seatNumber;
                _seatActive[seatNumber] = true;
                _seatNames[seatNumber] = _heroName.isNotEmpty ? _heroName : name;
                _seatStacks[seatNumber] = stack;
              } else if (isActive) {
                if (name.isNotEmpty) {
                  for (int s = 1; s <= 9; s++) {
                    if (s != seatNumber &&
                        _seatActive[s] == true &&
                        s != _heroSeat &&
                        _seatNames[s]?.toLowerCase() == name.toLowerCase()) {
                      _seatActive[s] = false;
                      _seatNames[s] = '';
                      _seatStacks[s] = 0;
                      break;
                    }
                  }
                }
                _seatActive[seatNumber] = true;
                _seatNames[seatNumber] = name;
                _seatStacks[seatNumber] = stack;
              } else {
                _seatActive[seatNumber] = false;
                _seatNames[seatNumber] = '';
                _seatStacks[seatNumber] = 0;
                if (_heroSeat == seatNumber) _heroSeat = null;
              }
            });
          },
    );
  }

  void _updateBlindsForGameType() {
    if (_gameType == GameType.cash) {
      _smallBlind = 1.0;
      _bigBlind = 2.0;
    } else {
      _smallBlind = 100.0;
      _bigBlind = 200.0;
    }
    _sbController.text = formatBlindValue(_smallBlind);
    _bbController.text = formatBlindValue(_bigBlind);
  }

  // ─── BUILD ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          _buildHeader(l10n),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildFormSection(l10n),
                  const SizedBox(height: 24),
                  _buildTableCard(l10n),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4),
                    child: Text(
                      l10n.setupTableOptionalHint,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildStartButton(l10n),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TopNavBar(
          title: l10n.setupSessionSetup,
          onBack: () => Navigator.pop(context),
        ),
        if (OnboardingState.isOnboardingActive) const OnboardingProgressBar(),
      ],
    );
  }

  // ─── FORM SECTION ────────────────────────────────────────────────

  Widget _buildFormSection(AppLocalizations l10n) {
    return Column(
      children: [
        // Session Name
        _buildFormRow(
          label: 'Session\nName',
          crossAxisAlignment: CrossAxisAlignment.center,
          content: _buildTextField(
            controller: _sessionNameController,
            hint: l10n.opponentsEnterName,
          ),
        ),
        _buildDivider(),

        // Game Type
        _buildFormRow(
          label: 'Choose\nGame Type',
          crossAxisAlignment: CrossAxisAlignment.center,
          content: Row(
            children: [
              _buildRadioOption(
                l10n.setupCashGame,
                _gameType == GameType.cash,
                () => setState(() {
                  _gameType = GameType.cash;
                  _updateBlindsForGameType();
                }),
              ),
              const SizedBox(width: 16),
              _buildRadioOption(
                l10n.setupTournament,
                _gameType == GameType.tournament,
                () => setState(() {
                  _gameType = GameType.tournament;
                  _updateBlindsForGameType();
                }),
              ),
            ],
          ),
        ),
        _buildDivider(),

        // Buy-in Amount
        _buildFormRow(
          label: 'Buy-in\nAmount',
          crossAxisAlignment: CrossAxisAlignment.start,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  border: Border.all(
                    color: _isBuyInFocused ? AppColors.accentPrimary : AppColors.borderDefault,
                    width: _isBuyInFocused ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    if (CurrencyService.prefixText != null) ...[
                      Text(
                        CurrencyService.prefixText!,
                        style: AppTypography.ibm(
                          color: _isBuyInFocused ? Colors.white : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 22 / 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _buyInController,
                        focusNode: _buyInFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        style: AppTypography.ibm(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 22 / 15,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.setupEnterAmount,
                          hintStyle: AppTypography.ibm(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 22 / 15,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (CurrencyService.suffixText != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        CurrencyService.suffixText!,
                        style: AppTypography.ibm(
                          color: _isBuyInFocused ? Colors.white : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 22 / 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_gameType == GameType.cash) ...[
                const SizedBox(height: 8),
                _buildInfoNote(l10n.setupStartingStackEqualsBuyIn),
              ],
            ],
          ),
        ),
        _buildDivider(),

        // Blinds
        _buildFormRow(
          label: 'Blinds',
          crossAxisAlignment: CrossAxisAlignment.center,
          content: Row(
            children: [
              Expanded(
                child: _buildBlindTextField(
                  l10n.setupSmallBlind,
                  _sbController,
                  _sbFocusNode,
                  _isSBFocused,
                  _gameType == GameType.cash,
                  (v) => setState(() => _smallBlind = v),
                  allowDecimal: _gameType == GameType.cash,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBlindTextField(
                  l10n.setupBigBlind,
                  _bbController,
                  _bbFocusNode,
                  _isBBFocused,
                  _gameType == GameType.cash,
                  (v) => setState(() => _bigBlind = v),
                  allowDecimal: _gameType == GameType.cash,
                ),
              ),
            ],
          ),
        ),

        // Tournament-only fields
        if (_gameType == GameType.tournament) ...[
          _buildDivider(),
          Builder(builder: (context) {
            final stack = double.tryParse(_startingStackController.text);
            final hasError = stack != null && stack < _bigBlind;
            return _buildFormRow(
              label: 'Starting\nStack',
              crossAxisAlignment: CrossAxisAlignment.start,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      border: Border.all(
                        color: hasError
                            ? AppColors.accentDanger
                            : _isStartingStackFocused
                                ? AppColors.accentPrimary
                                : AppColors.bgSurface,
                        width: (hasError || _isStartingStackFocused) ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _startingStackController,
                      focusNode: _startingStackFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      style: AppTypography.ibm(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 22 / 15,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.setupEnterChipStack,
                        hintStyle: AppTypography.ibm(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 22 / 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Must be at least the Big Blind ($_bigBlind)',
                      style: AppTypography.ibm(
                        fontSize: 12,
                        color: AppColors.accentDanger,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          _buildDivider(),
          _buildFormRow(
            label: 'BB Ante',
            crossAxisAlignment: CrossAxisAlignment.center,
            content: Align(
              alignment: Alignment.centerLeft,
              child: _buildSwitch(
                  _hasBBante, (v) => setState(() => _hasBBante = v)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormRow({
    required String label,
    required Widget content,
    required CrossAxisAlignment crossAxisAlignment,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.ibm(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.44,
              ),
            ),
          ),
          const SizedBox(width: 40),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.bgElevated,
    );
  }

  // ─── FORM INPUTS ─────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? prefixText,
    String? suffixText,
    bool hasError = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.done,
      style: AppTypography.ibm(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.ibm(
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        prefixText: prefixText,
        prefixStyle: AppTypography.ibm(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        suffixText: suffixText,
        suffixStyle: AppTypography.ibm(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: hasError
              ? const BorderSide(color: AppColors.accentDanger, width: 1.5)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          borderSide: BorderSide(
            color: hasError
                ? AppColors.accentDanger
                : AppColors.accentPrimary,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildRadioOption(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlindTextField(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    bool isFocused,
    bool showCurrencyPrefix,
    ValueChanged<double> onChanged, {
    bool allowDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(
              color: isFocused ? AppColors.accentPrimary : AppColors.borderDefault,
              width: isFocused ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              if (showCurrencyPrefix) ...[
                Text(
                  CurrencyService.symbol,
                  style: AppTypography.ibm(
                    color: isFocused ? Colors.white : AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 22 / 15,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: allowDecimal
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    allowDecimal
                        ? FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                        : FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 22 / 15,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTypography.ibm(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 22 / 15,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final v = double.tryParse(value);
                    if (v != null && v > 0) onChanged(v);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline,
              color: AppColors.accentPrimary, size: 16),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: AppTypography.ibm(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 16 / 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 51,
        height: 31,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value
              ? AppColors.accentPrimary
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: value
              ? null
              : Border.all(color: AppColors.borderOnInverse),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // ─── TABLE CARD ──────────────────────────────────────────────────

  Widget _buildTableCard(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
      child: Container(
        key: _tableSectionKey,
        width: double.infinity,
        color: AppColors.bgSurface,
        child: Column(
          children: [
            const SizedBox(height: 18),
            Text(
              l10n.setupTableInstructions,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 22 / 15,
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.50,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Dotted background — cover fills the full area
                  Image.asset(
                    'assets/icons/Table bg_small.png',
                    fit: BoxFit.cover,
                  ),
                  // Table + seats
                  PokerTableWidget(
                    activeSeatMap: _seatActive,
                    seatLabels: _buildSeatLabels(),
                    buttonPosition: _buttonPosition,
                    showDealerButton: true,
                    isDealerButtonDraggable: true,
                    // Table oval occupies 68% width / 72% height of the area
                    tableWidthFraction: 0.68,
                    tableHeightFraction: 0.72,
                    // Seat centers match the table outline boundary
                    seatWidthFraction: 0.68,
                    seatHeightFraction: 0.72,
                    seatAngleOffset: 7 * (2 * math.pi / 9),
                    onDealerButtonMoved: (newSeat) {
                      setState(() => _buttonPosition = newSeat);
                    },
                    seatBuilder: (seatNumber, isActive) {
                      return _buildSeatWidget(seatNumber);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── START BUTTON ────────────────────────────────────────────────

  Widget _buildStartButton(AppLocalizations l10n) {
    final isValid = _isFormValid;
    return Center(
      child: GestureDetector(
        onTap: isValid ? _startSession : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: isValid
                ? AppColors.accentPrimary
                : AppColors.accentPrimary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          ),
          child: Text(
            l10n.setupStartSession,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textInverse,
            ),
          ),
        ),
      ),
    );
  }

  // ─── TABLE SEAT WIDGET ───────────────────────────────────────────

  Widget _buildSeatWidget(int seatNumber) {
    final isActive = _seatActive[seatNumber] ?? false;
    final isHero = _heroSeat == seatNumber;
    final name = _seatNames[seatNumber] ?? '';
    final variant = PokerTableWidget.getSeatLayoutVariant(seatNumber);

    final l10n = AppLocalizations.of(context);
    final displayName = isHero
        ? (_heroName.isNotEmpty ? _heroName : l10n.setupMe)
        : (name.isNotEmpty
            ? (name.length > 6 ? '${name.substring(0, 6)}..' : name)
            : '');

    final borderColor = (isHero || isActive)
        ? AppColors.accentSecondary
        : AppColors.bgElevated;

    final chip = GestureDetector(
      onTap: () => _onSeatTap(seatNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Text(
          '$seatNumber',
          style: AppTypography.plexMonoLegacy(
            color: AppColors.accentSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    if (displayName.isEmpty) return chip;

    final badge = _buildNameBadge(displayName, variant);
    const gap = SizedBox(width: 4, height: 4);

    if (variant == 'top') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [badge, gap, chip],
      );
    } else if (variant == 'right') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [chip, gap, badge],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [badge, gap, chip],
      );
    }
  }

  Widget _buildNameBadge(String name, String variant) {
    const badgeWidth = 52.0;
    const badgeHeight = 17.0;
    const tailThickness = 3.5;

    const bgColor = Color(0xFF0097D2);
    const textColor = Colors.white;
    final truncated = name.length > 8 ? '${name.substring(0, 6)}..' : name;

    final pill = Container(
      width: badgeWidth,
      height: badgeHeight,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.5),
      ),
      child: Center(
        child: Text(
          truncated,
          style: AppTypography.ibm(
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
            color: textColor,
            height: 1.24,
          ),
          maxLines: 1,
        ),
      ),
    );

    if (variant == 'top') {
      // Badge above chip → tail points down from bottom-right
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          pill,
          CustomPaint(
            size: Size(badgeWidth, tailThickness),
            painter: _BadgeTailPainter(color: bgColor, direction: _TailDirection.bottom),
          ),
        ],
      );
    } else if (variant == 'left') {
      // Badge left of chip → tail points right
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          pill,
          CustomPaint(
            size: Size(tailThickness, badgeHeight),
            painter: _BadgeTailPainter(color: bgColor, direction: _TailDirection.right),
          ),
        ],
      );
    } else {
      // 'right' — badge right of chip → tail points left
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CustomPaint(
            size: Size(tailThickness, badgeHeight),
            painter: _BadgeTailPainter(color: bgColor, direction: _TailDirection.left),
          ),
          pill,
        ],
      );
    }
  }

  Map<int, String> _buildSeatLabels() {
    final l10n = AppLocalizations.of(context);
    final labels = <int, String>{};
    for (int i = 1; i <= 9; i++) {
      if (_heroSeat == i) {
        labels[i] = _heroName.isNotEmpty ? _heroName : l10n.setupMe;
      } else if (_seatNames[i]?.isNotEmpty == true) {
        labels[i] = _seatNames[i]!;
      }
    }
    return labels;
  }

}

enum _TailDirection { bottom, right, left }

class _BadgeTailPainter extends CustomPainter {
  final Color color;
  final _TailDirection direction;

  const _BadgeTailPainter({required this.color, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    switch (direction) {
      case _TailDirection.bottom:
        // Small triangle at bottom-right corner pointing downward
        path
          ..moveTo(size.width * 0.715, 0)
          ..lineTo(size.width * 0.865, 0)
          ..lineTo(size.width * 0.865, size.height)
          ..close();
      case _TailDirection.right:
        // Small triangle at right side pointing rightward (bottom-anchored)
        path
          ..moveTo(0, size.height * 0.715)
          ..lineTo(0, size.height * 0.865)
          ..lineTo(size.width, size.height * 0.865)
          ..close();
      case _TailDirection.left:
        // Small triangle at left side pointing leftward (bottom-anchored)
        path
          ..moveTo(size.width, size.height * 0.715)
          ..lineTo(size.width, size.height * 0.865)
          ..lineTo(0, size.height * 0.865)
          ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BadgeTailPainter old) =>
      old.color != color || old.direction != direction;
}
