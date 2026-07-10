import 'package:flutter/material.dart';
import '../design_system/components/form_drawer.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../services/bankroll_service.dart';
import '../services/session_result_service.dart';
import '../services/app_data_cache.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Shows session-end bankroll sheet using FormDrawer.
/// Cash: editable pre-filled profit + total invested.
/// Tournament: position, field size, prize, total invested, calculated profit.
///
/// Returns a result map if applied, `null` if skipped.
/// Map keys: `profitLoss` (double), `finishedPlace` (int?),
/// `fieldSize` (int?), `prizeWon` (double?).
class SessionEndBankrollSheet {
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required GameType gameType,
    double? profitLoss,
    required double totalBuyIn,
    int? durationMinutes,
  }) async {
    final isCash = gameType == GameType.cash;
    final l10n = AppLocalizations.of(context);

    final amountController = TextEditingController(
      text: isCash && profitLoss != null
          ? profitLoss.toStringAsFixed(0)
          : '',
    );
    final positionController = TextEditingController();
    final fieldSizeController = TextEditingController();
    final prizeController = TextEditingController();

    Map<String, dynamic>? result;

    await FormDrawer.show(
      context: context,
      title: isCash
          ? l10n.sessionEndResultTitle
          : l10n.sessionEndTournamentTitle,
      heightFraction: isCash ? 0.45 : 0.55,
      onSave: () async {
        double profit;
        if (isCash) {
          profit = double.tryParse(amountController.text) ?? 0.0;
        } else {
          final prize = double.tryParse(prizeController.text) ?? 0.0;
          profit = prize - totalBuyIn;
        }

        await BankrollService.addToBankroll(profit);
        await SessionResultService.addSessionResult(
          amount: profit,
          gameType: isCash ? 'cash' : 'tournament',
          buyInAmount: totalBuyIn,
          prizeWon: isCash ? null : (double.tryParse(prizeController.text) ?? 0.0),
          finishedPlace: isCash ? null : int.tryParse(positionController.text),
          fieldSize: isCash ? null : int.tryParse(fieldSizeController.text),
          durationMinutes: durationMinutes,
        );
        AppDataCache.markHomeDirty();
        AppDataCache.markStatsDirty();

        result = {
          'profitLoss': profit,
          'finishedPlace': isCash ? null : int.tryParse(positionController.text),
          'fieldSize': isCash ? null : int.tryParse(fieldSizeController.text),
          'prizeWon': isCash ? null : (double.tryParse(prizeController.text) ?? 0.0),
        };

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      onClose: () {
        Navigator.pop(context);
      },
      body: isCash
          ? _CashBody(
              amountController: amountController,
              totalBuyIn: totalBuyIn,
            )
          : _TournamentBody(
              positionController: positionController,
              fieldSizeController: fieldSizeController,
              prizeController: prizeController,
              totalBuyIn: totalBuyIn,
            ),
    );

    // Delay disposal to let closing animation finish
    Future.delayed(const Duration(milliseconds: 500), () {
      amountController.dispose();
      positionController.dispose();
      fieldSizeController.dispose();
      prizeController.dispose();
    });

    return result;
  }
}

class _CashBody extends StatefulWidget {
  final TextEditingController amountController;
  final double totalBuyIn;

  const _CashBody({
    required this.amountController,
    required this.totalBuyIn,
  });

  @override
  State<_CashBody> createState() => _CashBodyState();
}

class _CashBodyState extends State<_CashBody> {
  @override
  void initState() {
    super.initState();
    widget.amountController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profit = double.tryParse(widget.amountController.text) ?? 0.0;
    final isPositive = profit >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            // Profit/Loss label + Total Invested label
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPositive ? l10n.sessionEndProfit : l10n.sessionEndLoss,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    l10n.sessionEndTotalInvested,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Amount input + Total invested value
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: widget.amountController,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            style: AppTypography.mono(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: isPositive
                                  ? AppColors.accentPrimary
                                  : AppColors.errorRed,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixText: CurrencyService.prefixText,
                              prefixStyle: AppTypography.mono(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? AppColors.accentPrimary
                                    : AppColors.errorRed,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              filled: false,
                            ),
                          ),
                        ),
                        if (CurrencyService.suffixText != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              CurrencyService.suffixText!,
                              style: AppTypography.mono(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isPositive
                                    ? AppColors.accentPrimary.withValues(alpha: 0.6)
                                    : AppColors.errorRed.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyService.formatCash(widget.totalBuyIn),
                    style: AppTypography.mono(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentBody extends StatefulWidget {
  final TextEditingController positionController;
  final TextEditingController fieldSizeController;
  final TextEditingController prizeController;
  final double totalBuyIn;

  const _TournamentBody({
    required this.positionController,
    required this.fieldSizeController,
    required this.prizeController,
    required this.totalBuyIn,
  });

  @override
  State<_TournamentBody> createState() => _TournamentBodyState();
}

class _TournamentBodyState extends State<_TournamentBody> {
  double? _calculatedProfit;

  @override
  void initState() {
    super.initState();
    widget.prizeController.addListener(_recalculate);
  }

  @override
  void dispose() {
    widget.prizeController.removeListener(_recalculate);
    super.dispose();
  }

  void _recalculate() {
    final prize = double.tryParse(widget.prizeController.text) ?? 0.0;
    setState(() {
      _calculatedProfit = prize - widget.totalBuyIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusXl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            _buildField(
              label: l10n.sessionEndFinishingPosition,
              controller: widget.positionController,
              prefix: '#',
            ),
            _buildDivider(),
            _buildField(
              label: l10n.sessionEndFieldSize,
              controller: widget.fieldSizeController,
            ),
            _buildDivider(),
            _buildField(
              label: l10n.sessionEndPrizeWon,
              controller: widget.prizeController,
              prefix: CurrencyService.prefixText,
              suffix: CurrencyService.suffixText,
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
                    style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    CurrencyService.formatCash(widget.totalBuyIn),
                    style: AppTypography.mono(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
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
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyService.formatCash(_calculatedProfit!),
                      style: AppTypography.mono(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _calculatedProfit! >= 0
                            ? AppColors.accentPrimary
                            : AppColors.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.right,
              style: AppTypography.ibm(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: prefix,
                prefixStyle: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                suffixText: suffix,
                suffixStyle: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
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
      child: Divider(height: 1, color: AppColors.bgOverlay),
    );
  }
}
