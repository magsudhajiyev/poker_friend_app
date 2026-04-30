import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../services/bankroll_service.dart';
import '../services/session_result_service.dart';
import '../services/app_data_cache.dart';

/// Adaptive session-end sheet that prompts user to update bankroll.
/// Cash: shows editable pre-filled profit.
/// Tournament: shows position, field size, prize won fields.
class SessionEndBankrollSheet extends StatefulWidget {
  final GameType gameType;
  final double? profitLoss; // Pre-calculated for cash
  final double totalBuyIn;

  const SessionEndBankrollSheet({
    super.key,
    required this.gameType,
    this.profitLoss,
    required this.totalBuyIn,
  });

  @override
  State<SessionEndBankrollSheet> createState() => _SessionEndBankrollSheetState();
}

class _SessionEndBankrollSheetState extends State<SessionEndBankrollSheet> {
  late final TextEditingController _amountController;
  final _positionController = TextEditingController();
  final _fieldSizeController = TextEditingController();
  final _prizeController = TextEditingController();

  double? _calculatedProfit;

  bool get _isCash => widget.gameType == GameType.cash;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _isCash && widget.profitLoss != null
          ? widget.profitLoss!.toStringAsFixed(0)
          : '',
    );
    _prizeController.addListener(_recalculateTournamentProfit);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _positionController.dispose();
    _fieldSizeController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  void _recalculateTournamentProfit() {
    final prize = double.tryParse(_prizeController.text) ?? 0.0;
    setState(() {
      _calculatedProfit = prize - widget.totalBuyIn;
    });
  }

  Future<void> _apply() async {
    double profit;
    if (_isCash) {
      profit = double.tryParse(_amountController.text) ?? 0.0;
    } else {
      final prize = double.tryParse(_prizeController.text) ?? 0.0;
      profit = prize - widget.totalBuyIn;
    }

    await BankrollService.addToBankroll(profit);
    await SessionResultService.addSessionResult(
      amount: profit,
      gameType: _isCash ? 'cash' : 'tournament',
    );
    AppDataCache.markHomeDirty();

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF262626)),
          left: BorderSide(color: Color(0xFF262626)),
          right: BorderSide(color: Color(0xFF262626)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2E5A59),
            blurRadius: 64,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Center(
                  child: Text(
                    _isCash
                        ? l10n.sessionEndResultTitle
                        : l10n.sessionEndTournamentTitle,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.43,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_isCash) _buildCashLayout(l10n) else _buildTournamentLayout(l10n),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Skip button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(110),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Center(
                            child: Text(
                              l10n.sessionEndSkip,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    // Apply button
                    Expanded(
                      child: GestureDetector(
                        onTap: _apply,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF89F1EC),
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Center(
                            child: Text(
                              l10n.sessionEndApply,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashLayout(AppLocalizations l10n) {
    final profit = double.tryParse(_amountController.text) ?? 0.0;
    final isPositive = profit >= 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Profit/Loss label
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPositive ? l10n.sessionEndProfit : l10n.sessionEndLoss,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8C8C8C),
                  ),
                ),
                Text(
                  l10n.sessionEndTotalInvested,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8C8C8C),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Editable amount
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    style: GoogleFonts.robotoMono(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? const Color(0xFF62E3BC)
                          : const Color(0xFFD55A41),
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixText: '\$',
                      prefixStyle: GoogleFonts.robotoMono(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? const Color(0xFF62E3BC)
                            : const Color(0xFFD55A41),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                // Total invested (read-only)
                Text(
                  '\$${widget.totalBuyIn.toStringAsFixed(0)}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentLayout(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          _buildTournamentField(
            label: l10n.sessionEndFinishingPosition,
            controller: _positionController,
            prefix: '#',
          ),
          _buildDivider(),
          _buildTournamentField(
            label: l10n.sessionEndFieldSize,
            controller: _fieldSizeController,
          ),
          _buildDivider(),
          _buildTournamentField(
            label: l10n.sessionEndPrizeWon,
            controller: _prizeController,
            prefix: '\$',
          ),
          _buildDivider(),
          // Total invested (read-only)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.sessionEndTotalInvested,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFB9B9B9),
                  ),
                ),
                Text(
                  '\$${widget.totalBuyIn.toStringAsFixed(0)}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Calculated profit
          if (_calculatedProfit != null) ...[
            _buildDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _calculatedProfit! >= 0
                        ? l10n.sessionEndProfit
                        : l10n.sessionEndLoss,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB9B9B9),
                    ),
                  ),
                  Text(
                    '\$${_calculatedProfit!.toStringAsFixed(0)}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _calculatedProfit! >= 0
                          ? const Color(0xFF62E3BC)
                          : const Color(0xFFD55A41),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentField({
    required String label,
    required TextEditingController controller,
    String? prefix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFB9B9B9),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                prefixText: prefix,
                prefixStyle: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8C8C8C),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Divider(height: 1, color: const Color(0xFF3A3A3C)),
    );
  }
}
