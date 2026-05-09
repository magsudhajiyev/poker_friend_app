import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/currency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../models/hand_state_machine.dart';
import '../services/display_identity_service.dart';
import '../widgets/poker_table_widget.dart';
import '../widgets/seat_config_sheet.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import 'poker_hand_screen.dart';

/// Unified session setup screen that merges session config + seat setup
/// into a single scrollable view. Replaces the old 2-screen flow
/// (IndividualSessionSetupScreen → SeatSetupScreen) for Full mode.
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

  // ─── Session settings ────────────────────────────────────────────
  GameType _gameType = GameType.cash;
  int _smallBlind = 1;
  int _bigBlind = 2;
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
    final hasBlinds = _smallBlind > 0 && _bigBlind > 0;
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
    // Intentionally NOT loading saved defaults — start fresh each time
    _scheduleOnboardingTour();
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
    final savedSB = prefs.getInt(_kLastSmallBlind);
    final savedBB = prefs.getInt(_kLastBigBlind);
    final savedBuyIn = prefs.getDouble(_kLastBuyIn);
    final savedBBante = prefs.getBool(_kLastHasBBante);

    if (!mounted) return;
    setState(() {
      if (savedGameType == 'tournament') {
        _gameType = GameType.tournament;
        _smallBlind = savedSB ?? 100;
        _bigBlind = savedBB ?? 200;
      } else {
        _gameType = GameType.cash;
        _smallBlind = savedSB ?? 1;
        _bigBlind = savedBB ?? 2;
      }
      if (savedBuyIn != null) {
        _buyInController.text = savedBuyIn.toStringAsFixed(
            savedBuyIn == savedBuyIn.roundToDouble() ? 0 : 2);
      }
      if (savedBBante != null) _hasBBante = savedBBante;
    });
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

    // Scroll down to table section, then show the tour
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Scroll to bottom to reveal the table
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
    await prefs.setInt(_kLastSmallBlind, _smallBlind);
    await prefs.setInt(_kLastBigBlind, _bigBlind);
    final buyIn = double.tryParse(_buyInController.text);
    if (buyIn != null) await prefs.setDouble(_kLastBuyIn, buyIn);
    await prefs.setBool(_kLastHasBBante, _hasBBante);
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _buyInController.dispose();
    _startingStackController.dispose();
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
    final sessionName = _sessionNameController.text.isNotEmpty
        ? _sessionNameController.text
        : 'Session';

    // Build session manager
    final sessionManager = PokerSessionManager(
      smallBlind: _smallBlind,
      bigBlind: _bigBlind,
      playerCount: 9,
      gameType: _gameType,
      sessionName: sessionName,
      initialBuyIn: buyIn,
      startingStack: startingStack,
    );

    // Register players
    for (int seat = 1; seat <= 9; seat++) {
      if (_seatActive[seat] == true) {
        final name = _seatNames[seat] ?? 'Player $seat';
        sessionManager.addPlayer(seat, name.isEmpty ? 'Player $seat' : name);
        final stack = _seatStacks[seat] ?? startingStack;
        sessionManager.setPlayerStack(seat, stack > 0 ? stack : startingStack);
      }
    }

    // Ensure hero is registered
    if (_heroSeat != null && _seatActive[_heroSeat!] != true) {
      final l10n = AppLocalizations.of(context);
      sessionManager.addPlayer(_heroSeat!, _heroName.isNotEmpty ? _heroName : l10n.setupHero);
      sessionManager.setPlayerStack(_heroSeat!, startingStack);
    }

    // Validate button is on an active seat — if not, move to first active seat
    int buttonPos = _buttonPosition;
    if (_seatActive[buttonPos] != true) {
      for (int seat = 1; seat <= 9; seat++) {
        if (_seatActive[seat] == true) {
          buttonPos = seat;
          break;
        }
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PokerHandScreen(
          smallBlind: _smallBlind,
          bigBlind: _bigBlind,
          numberOfPlayers: 9,
          gameType: _gameType,
          hasBBante: _hasBBante,
          ante: _hasBBante ? _bigBlind : 0,
          sessionName: sessionName,
          buyInAmount: buyIn,
          startingStack: startingStack,
          initialSeat: _heroSeat,
          initialButtonPosition: buttonPos,
          sessionManager: sessionManager,
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

    // Build seated players map for opponent badge display
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
                // Clear previous hero seat completely
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
                // Check if this player name is already seated elsewhere — reseat
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
                // Removing player
                _seatActive[seatNumber] = false;
                _seatNames[seatNumber] = '';
                _seatStacks[seatNumber] = 0;
                if (_heroSeat == seatNumber) _heroSeat = null;
              }
            });
          },
    );
  }

  // ─── UI HELPERS ──────────────────────────────────────────────────

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Image.asset(path, width: size, height: size, color: color);
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText, String? suffixText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.ibmPlexSans(
        color: Colors.white.withOpacity(0.4),
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.ibmPlexSans(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      suffixText: suffixText,
      suffixStyle: GoogleFonts.ibmPlexSans(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      ),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF1B262D).withOpacity(0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF1B262D).withOpacity(0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF89F1EC)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal gradient background
          Positioned(
            top: -screenWidth * 0.3,
            right: -screenWidth * 0.25,
            child: Transform.scale(
              scaleX: 1.0,
              scaleY: 0.7,
              child: Container(
                width: screenWidth * 1.5,
                height: screenWidth * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [
                      const Color(0xFF1A4A4A),
                      const Color(0xFF133538).withOpacity(0.7),
                      const Color(0xFF133538).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/close.svg',
                              16,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        l10n.setupSessionSetup,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.43,
                          height: 1.3,
                        ),
                      ),
                      // Start button (checkmark)
                      GestureDetector(
                        onTap: _isFormValid ? _startSession : null,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isFormValid
                                ? const Color(0xFF62E3BC)
                                : const Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/check.svg',
                              16,
                              _isFormValid
                                  ? Colors.black
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Onboarding progress bar
                if (OnboardingState.isOnboardingActive)
                  const OnboardingProgressBar(),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // ── SESSION FORM SECTION ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Session Name ──────────────────────────
                            _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCardTitle(l10n.setupSessionName),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _sessionNameController,
                                    textInputAction: TextInputAction.done,
                                    style: _textFieldStyle,
                                    decoration: _inputDecoration(
                                        l10n.setupSessionNameHint),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ── Game Type ─────────────────────────────
                            _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCardTitle(l10n.setupGameType),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildToggle(
                                          l10n.setupCashGame,
                                          _gameType == GameType.cash,
                                          () => setState(() {
                                            _gameType = GameType.cash;
                                            _updateBlindsForGameType();
                                          }),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildToggle(
                                          l10n.setupTournament,
                                          _gameType == GameType.tournament,
                                          () => setState(() {
                                            _gameType = GameType.tournament;
                                            _updateBlindsForGameType();
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ── Blinds Row ────────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBlindCard(l10n.setupSmallBlind,
                                      _gameType == GameType.cash
                                          ? '${CurrencyService.symbol}$_smallBlind'
                                          : '$_smallBlind', () {
                                    _showBlindDialog(l10n.setupSmallBlind, _smallBlind,
                                        (v) {
                                      setState(() => _smallBlind = v);
                                    });
                                  }),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildBlindCard(l10n.setupBigBlind,
                                      _gameType == GameType.cash
                                          ? '${CurrencyService.symbol}$_bigBlind'
                                          : '$_bigBlind', () {
                                    _showBlindDialog(l10n.setupBigBlind, _bigBlind, (v) {
                                      setState(() => _bigBlind = v);
                                    });
                                  }),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ── Buy-in ────────────────────────────────
                            _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCardTitle(l10n.setupBuyInAmount),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _buyInController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    textInputAction: TextInputAction.done,
                                    style: _textFieldStyle,
                                    decoration:
                                        _inputDecoration(l10n.setupEnterAmount, prefixText: CurrencyService.prefixText, suffixText: CurrencyService.suffixText),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  if (_gameType == GameType.cash) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _buildIcon(
                                          'icons/figma_icons/info.svg',
                                          16,
                                          const Color(0xFF89F1EC),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.setupStartingStackEqualsBuyIn,
                                            style: GoogleFonts.ibmPlexSans(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── Starting Stack (tournament only) ──────
                            if (_gameType == GameType.tournament) ...[
                              const SizedBox(height: 12),
                              Builder(builder: (context) {
                                final stack = double.tryParse(
                                    _startingStackController.text);
                                final hasError =
                                    stack != null && stack < _bigBlind;
                                return _buildCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildCardTitle(l10n.setupStartingStack),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _startingStackController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        textInputAction: TextInputAction.done,
                                        style: _textFieldStyle,
                                        decoration: InputDecoration(
                                          hintText: l10n.setupEnterChipStack,
                                          hintStyle: GoogleFonts.ibmPlexSans(
                                            color: Colors.white.withOpacity(0.4),
                                            fontSize: 17,
                                            height: 1.44,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF1C1C1E),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: hasError
                                                  ? const Color(0xFFFF4444)
                                                  : const Color(0xFF1B262D)
                                                      .withOpacity(0.6),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: hasError
                                                  ? const Color(0xFFFF4444)
                                                  : const Color(0xFF1B262D)
                                                      .withOpacity(0.6),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: hasError
                                                  ? const Color(0xFFFF4444)
                                                  : const Color(0xFF89F1EC),
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 14),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                      if (hasError) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Must be at least the Big Blind ($_bigBlind)',
                                          style: GoogleFonts.ibmPlexSans(
                                            fontSize: 12,
                                            color: const Color(0xFFFF4444),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],

                            // ── BB Ante (tournament only) ─────────────
                            if (_gameType == GameType.tournament) ...[
                              const SizedBox(height: 12),
                              _buildCard(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.setupBbAnte,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 17,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        height: 1.44,
                                      ),
                                    ),
                                    _buildSwitch(
                                      _hasBBante,
                                      (v) => setState(() => _hasBBante = v),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── SECTION: Table Setup (keyed for onboarding) ──
                        Column(
                          key: _tableSectionKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(l10n.setupTableSection),
                            const SizedBox(height: 8),
                            Text(
                              l10n.setupTableInstructions,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ── Poker Table ───────────────────────────
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.38,
                              child: PokerTableWidget(
                                activeSeatMap: _seatActive,
                                seatLabels: _buildSeatLabels(),
                                buttonPosition: _buttonPosition,
                                showDealerButton: true,
                                isDealerButtonDraggable: true,
                                onDealerButtonMoved: (newSeat) {
                                  setState(() => _buttonPosition = newSeat);
                                },
                                seatBuilder: (seatNumber, isActive) {
                                  return _buildSeatWidget(seatNumber);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Start Session Button ──────────────────
                        GestureDetector(
                          onTap: _isFormValid ? _startSession : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isFormValid
                                  ? const Color(0xFF62E3BC)
                                  : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(110),
                            ),
                            child: Center(
                              child: Text(
                                l10n.setupStartSession,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 17,
                                  color: _isFormValid
                                      ? Colors.black
                                      : Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.43,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TABLE SEAT WIDGET ───────────────────────────────────────────

  Widget _buildSeatWidget(int seatNumber) {
    final isActive = _seatActive[seatNumber] ?? false;
    final isHero = _heroSeat == seatNumber;
    final name = _seatNames[seatNumber] ?? '';
    final variant = PokerTableWidget.getSeatLayoutVariant(seatNumber);

    final circleColor = isHero
        ? const Color(0xFF62E3BC)
        : isActive
            ? const Color(0xFF89F1EC)
            : const Color(0xFF89F1EC).withOpacity(0.3);

    final circleFill = isActive ? Colors.black : const Color(0xFF2A2A2E);

    final l10n = AppLocalizations.of(context);
    final displayName = isHero
        ? (_heroName.isNotEmpty ? _heroName : l10n.setupMe)
        : (name.isNotEmpty
            ? (name.length > 7 ? '${name.substring(0, 7)}..' : name)
            : '');

    // Build circle + label
    Widget circle = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: circleFill,
        shape: BoxShape.circle,
        border: Border.all(color: circleColor, width: 2),
      ),
      child: Center(
        child: isHero
            ? const Icon(Icons.person, color: Color(0xFF62E3BC), size: 18)
            : Text(
                '$seatNumber',
                style: GoogleFonts.inter(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
      ),
    );

    Widget label = Text(
      displayName.isNotEmpty ? displayName : (isActive ? 'P$seatNumber' : ''),
      style: GoogleFonts.ibmPlexSans(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    // Layout depends on seat position
    Widget content;
    if (variant == 'top') {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [circle, const SizedBox(height: 4), label],
      );
    } else if (variant == 'right') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [circle, const SizedBox(width: 6), label],
      );
    } else {
      // left
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [label, const SizedBox(width: 6), circle],
      );
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seatNumber),
      child: content,
    );
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

  // ─── REUSABLE CARD WIDGETS ───────────────────────────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _buildCardTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 17,
        color: const Color(0xFF62E3BC),
        fontWeight: FontWeight.w600,
        letterSpacing: -0.43,
        height: 1.3,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        color: const Color(0xFF87ED81),
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }

  TextStyle get _textFieldStyle => GoogleFonts.ibmPlexSans(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.44,
      );

  Widget _buildToggle(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF89F1EC)
                : const Color(0xFF1B262D).withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: isSelected
                  ? const Color(0xFF89F1EC)
                  : Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlindCard(String title, String value, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(80),
                border: Border.all(
                  color: const Color(0xFF1B262D).withOpacity(0.6),
                ),
              ),
              child: Center(
                child: Text(
                  value,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
          color: value ? const Color(0xFF62E3BC) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: value
              ? null
              : Border.all(
                  color: const Color(0xFF1B262D).withOpacity(0.6),
                ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── DIALOGS ─────────────────────────────────────────────────────

  void _showBlindDialog(
      String title, int currentValue, ValueChanged<int> onConfirm) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          title,
          style: GoogleFonts.ibmPlexSans(
            color: const Color(0xFF62E3BC),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontSize: 17,
          ),
          decoration: _inputDecoration('Enter value'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) {
                onConfirm(v);
                Navigator.pop(ctx);
              }
            },
            child: Text(
              l10n.commonOk,
              style: GoogleFonts.ibmPlexSans(
                color: const Color(0xFF62E3BC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateBlindsForGameType() {
    if (_gameType == GameType.cash) {
      _smallBlind = 1;
      _bigBlind = 2;
    } else {
      _smallBlind = 100;
      _bigBlind = 200;
    }
  }
}
