import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_system/components/buttons/primary_pill_button.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../models/currency.dart';
import '../services/app_data_cache.dart';
import '../services/bankroll_service.dart';
import '../services/currency_service.dart';
import '../utils/decimal_input.dart';

/// Full-screen bankroll edit page — Figma node 1940:18321.
///
/// Two tap-to-edit rows (Current Bankroll, Bankroll Goal) grouped in a
/// single `bgSurface` card. Each value renders as a large 28/w600
/// numeric TextField that opens the numeric keyboard on tap and shows
/// the app's currency prefix/suffix.
///
/// Pushed from the pencil icon (or long-press) on the Home screen's
/// bankroll header.
class BankrollEditScreen extends StatefulWidget {
  final double initialBankroll;
  final double initialGoal;

  const BankrollEditScreen({
    super.key,
    required this.initialBankroll,
    required this.initialGoal,
  });

  @override
  State<BankrollEditScreen> createState() => _BankrollEditScreenState();
}

class _BankrollEditScreenState extends State<BankrollEditScreen> {
  late final TextEditingController _bankrollController;
  late final TextEditingController _goalController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bankrollController = TextEditingController(
      text: widget.initialBankroll > 0
          ? widget.initialBankroll.toStringAsFixed(0)
          : '',
    );
    _goalController = TextEditingController(
      text: widget.initialGoal > 0
          ? widget.initialGoal.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _bankrollController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _openCurrencyPicker() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencyPickerSheet(
        selectedCode: CurrencyService.code,
      ),
    );
    if (picked == null || picked == CurrencyService.code) return;
    await CurrencyService.setCurrency(picked);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final newBankroll = parseDecimal(_bankrollController.text);
    final newGoal = parseDecimal(_goalController.text);
    if (newBankroll != null) {
      await BankrollService.setCurrentBankroll(newBankroll);
    }
    if (newGoal != null) {
      await BankrollService.setBankrollGoal(newGoal);
    }
    AppDataCache.markHomeDirty();
    HapticFeedback.selectionClick();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            TopNavBar(
              title: l10n.bankrollSheetEditSection,
              onBack: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius:
                      BorderRadius.circular(AppDecorations.radiusLg),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EditableRow(
                      label: l10n.bankrollSheetCurrentLabel,
                      controller: _bankrollController,
                    ),
                    const _RowDivider(),
                    _EditableRow(
                      label: l10n.bankrollSheetGoalLabel,
                      controller: _goalController,
                    ),
                    const _RowDivider(),
                    _CurrencyRow(
                      onTap: _openCurrencyPicker,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                (bottomInset > 0 ? bottomInset : 24) + 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryPillButton(
                    label: l10n.commonSave,
                    onTap: _isSaving ? null : _save,
                  ),
                  const SizedBox(height: 10),
                  _WhiteOutlinedPill(
                    label: l10n.commonCancel,
                    onTap: () => Navigator.of(context).pop(false),
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

/// One "label + editable value" row inside the edit card. The value is
/// a right-aligned 28/w600 numeric TextField with the app's currency
/// prefix — tap the row area anywhere and the keyboard opens.
class _EditableRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _EditableRow({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 20 / 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            textAlign: TextAlign.right,
            cursorColor: AppColors.accentSecondary,
            style: AppTypography.ibm(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 36 / 28,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              // Use `prefix`/`suffix` widgets (not the `prefixText`
              // props) so the currency symbol stays visible even when
              // the field is empty and unfocused.
              prefix: (CurrencyService.prefixText ?? '').isEmpty
                  ? null
                  : Text(
                      CurrencyService.prefixText!,
                      style: AppTypography.ibm(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: -0.5,
                      ),
                    ),
              suffix: (CurrencyService.suffixText ?? '').isEmpty
                  ? null
                  : Text(
                      CurrencyService.suffixText!,
                      style: AppTypography.ibm(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: -0.5,
                      ),
                    ),
              hintText: '0',
              hintStyle: AppTypography.ibm(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: -0.5,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // Explicitly opt out of the Material 3 default filled
              // treatment so the field sits transparent on the card.
              filled: false,
              fillColor: Colors.transparent,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

/// Thin hairline between rows inside the edit card, with matching
/// vertical breathing above and below so the two adjacent rows read as
/// siblings rather than glued together.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

/// "Currency" row — tap to open the picker sheet. Shows the current
/// currency's symbol + short code so the user knows what the numbers
/// above are denominated in.
class _CurrencyRow extends StatelessWidget {
  final VoidCallback onTap;

  const _CurrencyRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyService.current;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.settingsCurrency,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 20 / 17,
            ),
          ),
          const Spacer(),
          Text(
            currency.code,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 20 / 17,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          SvgPicture.asset(
            'assets/icons/CaretRight.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              AppColors.contentInactive,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet with the scrollable list of currencies. Tap a
/// row to select and immediately return the code to the caller.
class _CurrencyPickerSheet extends StatelessWidget {
  final String selectedCode;

  const _CurrencyPickerSheet({required this.selectedCode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDecorations.radiusXl),
          topRight: Radius.circular(AppDecorations.radiusXl),
        ),
        border: Border.all(color: AppColors.borderStrong),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsChooseCurrency,
              style: AppTypography.ibm(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 20 / 17,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: Currency.all.length,
                itemBuilder: (context, index) {
                  final c = Currency.all[index];
                  final isSelected = c.code == selectedCode;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(c.code),
                    child: Container(
                      margin: EdgeInsets.only(
                        bottom:
                            index < Currency.all.length - 1 ? 4 : 0,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.bgElevated
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppDecorations.radiusSm),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              c.symbol,
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${c.name} (${c.code})',
                              style: AppTypography.ibm(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (c.flagAsset != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SvgPicture.asset(
                                c.flagAsset!,
                                width: 24,
                                height: 18,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Text(
                              c.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White-outlined pill — matches Figma's cancel button (white 1px
/// border instead of the standard `borderStrong` grey). Local to this
/// screen since it's a one-off treatment.
class _WhiteOutlinedPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _WhiteOutlinedPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white, width: 1),
            borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 20 / 15,
            ),
          ),
        ),
      ),
    );
  }
}
