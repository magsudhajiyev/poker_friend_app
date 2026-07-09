import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart' show formatBlindValue;
import 'individual_session_tracking_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'seat_setup_screen.dart';
import '../models/hand_state_machine.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class IndividualSessionSetupScreen extends StatefulWidget {
  final LoggingMode? loggingMode;

  const IndividualSessionSetupScreen({super.key, this.loggingMode});

  @override
  State<IndividualSessionSetupScreen> createState() => _IndividualSessionSetupScreenState();
}

class _IndividualSessionSetupScreenState extends State<IndividualSessionSetupScreen> {
  // Form controllers
  final TextEditingController _sessionNameController = TextEditingController();
  final TextEditingController _buyInController = TextEditingController();
  final TextEditingController _startingStackController = TextEditingController();
  final TextEditingController _smallBlindController = TextEditingController();
  final TextEditingController _bigBlindController = TextEditingController();

  // Focus nodes (inline field focus highlighting)
  final FocusNode _sbFocusNode = FocusNode();
  final FocusNode _bbFocusNode = FocusNode();
  final FocusNode _buyInFocusNode = FocusNode();
  final FocusNode _startingStackFocusNode = FocusNode();
  bool _isSBFocused = false;
  bool _isBBFocused = false;
  bool _isBuyInFocused = false;
  bool _isStartingStackFocused = false;

  // Game settings
  GameType gameType = GameType.cash;
  double smallBlind = 1.0;
  double bigBlind = 2.0;
  bool hasBBante = false;

  // Form validation
  bool get isFormValid {
    bool basicValid = _sessionNameController.text.isNotEmpty &&
                     _buyInController.text.isNotEmpty &&
                     double.tryParse(_buyInController.text) != null;

    if (gameType == GameType.tournament) {
      final stack = double.tryParse(_startingStackController.text);
      return basicValid &&
             stack != null &&
             stack >= bigBlind;
    }

    return basicValid;
  }

  @override
  void initState() {
    super.initState();
    // Initialize blind controllers with default values
    _smallBlindController.text = formatBlindValue(smallBlind);
    _bigBlindController.text = formatBlindValue(bigBlind);
    _sbFocusNode.addListener(() => setState(() => _isSBFocused = _sbFocusNode.hasFocus));
    _bbFocusNode.addListener(() => setState(() => _isBBFocused = _bbFocusNode.hasFocus));
    _buyInFocusNode.addListener(() => setState(() => _isBuyInFocused = _buyInFocusNode.hasFocus));
    _startingStackFocusNode.addListener(() => setState(() => _isStartingStackFocused = _startingStackFocusNode.hasFocus));
    _scheduleOnboardingTour();
  }

  void _scheduleOnboardingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 2) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SessionSetupTour().show(context);
    });
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _buyInController.dispose();
    _startingStackController.dispose();
    _smallBlindController.dispose();
    _bigBlindController.dispose();
    _sbFocusNode.dispose();
    _bbFocusNode.dispose();
    _buyInFocusNode.dispose();
    _startingStackFocusNode.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildFormSection(l10n),
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
    return Container(
      color: AppColors.bgSurface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(Icons.chevron_left,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.individualSetupSessionSetup,
                        textAlign: TextAlign.center,
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 22 / 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (OnboardingState.isOnboardingActive) const OnboardingProgressBar(),
          ],
        ),
      ),
    );
  }

  // ─── FORM SECTION ────────────────────────────────────────────────

  Widget _buildFormSection(AppLocalizations l10n) {
    return Column(
      children: [
        // Session Name
        _buildFormRow(
          label: l10n.individualSetupSessionNameLabel,
          crossAxisAlignment: CrossAxisAlignment.center,
          content: _buildTextField(
            controller: _sessionNameController,
            hint: l10n.individualSetupSessionNameHint,
          ),
        ),
        _buildDivider(),

        // Game Type
        _buildFormRow(
          label: l10n.individualSetupGameTypeLabel,
          crossAxisAlignment: CrossAxisAlignment.center,
          content: Row(
            children: [
              _buildRadioOption(
                l10n.individualSetupCashGame,
                gameType == GameType.cash,
                () => setState(() {
                  gameType = GameType.cash;
                  _updateStackForGameType();
                }),
              ),
              const SizedBox(width: 16),
              _buildRadioOption(
                l10n.individualSetupTournament,
                gameType == GameType.tournament,
                () => setState(() {
                  gameType = GameType.tournament;
                  _updateStackForGameType();
                }),
              ),
            ],
          ),
        ),
        _buildDivider(),

        // Buy-in Amount
        _buildFormRow(
          label: l10n.individualSetupBuyInAmountLabel,
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
                          hintText: l10n.individualSetupEnterAmount,
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
                        onChanged: (_) {
                          setState(() {});
                          _updateStackForGameType();
                        },
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
              if (gameType == GameType.cash) ...[
                const SizedBox(height: 8),
                _buildInfoNote(l10n.individualSetupCashGameNote),
              ],
            ],
          ),
        ),
        _buildDivider(),

        // Blinds
        _buildFormRow(
          label: l10n.individualSetupBlindsLabel,
          crossAxisAlignment: CrossAxisAlignment.center,
          content: Row(
            children: [
              Expanded(
                child: _buildBlindTextField(
                  l10n.individualSetupSmallBlind,
                  _smallBlindController,
                  _sbFocusNode,
                  _isSBFocused,
                  gameType == GameType.cash,
                  (v) => setState(() => smallBlind = v),
                  allowDecimal: gameType == GameType.cash,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBlindTextField(
                  l10n.individualSetupBigBlind,
                  _bigBlindController,
                  _bbFocusNode,
                  _isBBFocused,
                  gameType == GameType.cash,
                  (v) => setState(() => bigBlind = v),
                  allowDecimal: gameType == GameType.cash,
                ),
              ),
            ],
          ),
        ),

        // Tournament-only fields
        if (gameType == GameType.tournament) ...[
          _buildDivider(),
          Builder(builder: (context) {
            final stack = double.tryParse(_startingStackController.text);
            final hasError = stack != null && stack < bigBlind;
            return _buildFormRow(
              label: l10n.individualSetupStartingStackLabel,
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
                                : AppColors.borderDefault,
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
                        hintText: l10n.individualSetupEnterChipStack,
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
                      l10n.individualSetupStackValidation(bigBlind.toInt()),
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
            label: l10n.setupBbAnte,
            crossAxisAlignment: CrossAxisAlignment.center,
            content: Align(
              alignment: Alignment.centerLeft,
              child: _buildSwitch(
                  hasBBante, (v) => setState(() => hasBBante = v)),
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

  // ─── START BUTTON ────────────────────────────────────────────────

  Widget _buildStartButton(AppLocalizations l10n) {
    final isValid = isFormValid;
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
            l10n.individualSetupStartSessionBtn,
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

  // ─── SESSION LOGIC ───────────────────────────────────────────────

  void _updateStackForGameType() {
    if (gameType == GameType.cash) {
      // For cash games, starting stack equals buy-in amount
      final buyInText = _buyInController.text;
      if (buyInText.isNotEmpty && double.tryParse(buyInText) != null) {
        _startingStackController.text = buyInText;
      }
      // Set default cash game blinds
      smallBlind = 1.0;
      bigBlind = 2.0;
      _smallBlindController.text = formatBlindValue(smallBlind);
      _bigBlindController.text = formatBlindValue(bigBlind);
    } else {
      // For MTT, set default tournament blinds
      smallBlind = 100.0;
      bigBlind = 200.0;
      _smallBlindController.text = formatBlindValue(smallBlind);
      _bigBlindController.text = formatBlindValue(bigBlind);
    }
  }

  void _startSession() {
    final sessionName = _sessionNameController.text;
    final buyIn = double.parse(_buyInController.text);
    final startingStack = gameType == GameType.cash
        ? buyIn  // For cash games, starting stack = buy-in
        : double.parse(_startingStackController.text);  // For MTT, use entered value


    if (widget.loggingMode == LoggingMode.full) {
      // For Full mode, go directly to Seat Setup screen
      // Create session manager
      final sessionManager = PokerSessionManager(
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        playerCount: 9, // Support all 9 seats
        gameType: gameType,
        sessionName: sessionName,
        initialBuyIn: buyIn,
        startingStack: startingStack, // Pass starting stack for P/L calculations
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeatSetupScreen(
            playerCount: 9, // Support all 9 seats
            buttonPosition: 1,
            sessionManager: sessionManager,
            isInitialSetup: true,
            isCashGame: gameType == GameType.cash,
            sessionName: sessionName,
            buyInAmount: buyIn,
            startingStack: startingStack,
            gameType: gameType,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            hasBBante: hasBBante,
          ),
        ),
      );
    } else {
      // For Individual mode, go to Individual Session Tracking
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IndividualSessionTrackingScreen(
            sessionName: sessionName,
            buyInAmount: buyIn,
            startingStack: startingStack,
            gameType: gameType,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            hasBBante: hasBBante,
          ),
        ),
      );
    }
  }
}
