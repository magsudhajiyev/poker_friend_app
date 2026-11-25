import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design_system/components/buttons/app_button.dart';
import '../../../design_system/components/sheets/app_sheet.dart';
import '../../../design_system/constants/colors.dart';
import '../../../design_system/constants/spacing.dart';
import '../../../design_system/constants/typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/single_hand_setup.dart';
import '../../../services/currency_service.dart';
import 'stack_drag_control.dart';

/// Villain stack picker for single-hand logging (setup v2, D7 / D8).
///
/// Same one-drag control as the hero stack, on the RELATIVE scale
/// (multiples of the hero stack, starting at "same as you"). Shown as a
/// bottom sheet with drag-to-dismiss off, so the vertical drag only moves the
/// control. [show] returns the chosen multiple, or null when the player
/// dismissed it or (soft prompt only) kept the stack equal to the hero's.
class VillainStackSheet extends StatefulWidget {
  /// Seat label shown in the title, e.g. `BTN`.
  final String position;

  /// Hero stack in chips / money. The control multiplies it.
  final double heroStack;
  final double bigBlind;
  final bool cash;

  /// All-in rule (D8): different copy, and no "keep equal" escape.
  final bool allIn;

  const VillainStackSheet({
    super.key,
    required this.position,
    required this.heroStack,
    required this.bigBlind,
    required this.cash,
    this.allIn = false,
  });

  static const String hintPrefsKey = 'single_hand_villain_stack_hint_shown';

  static Future<double?> show(
    BuildContext context, {
    required String position,
    required double heroStack,
    required double bigBlind,
    required bool cash,
    bool allIn = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return AppSheet.show<double>(
      context: context,
      title: allIn
          ? l10n.singleHandV2VillainAllInTitle(position)
          : l10n.singleHandV2VillainTitle(position),
      subtitle: allIn
          ? l10n.singleHandV2VillainAllInSubtitle
          : l10n.singleHandV2VillainSubtitle,
      heightFraction: null,
      scrollable: false,
      enableDrag: false,
      body: VillainStackSheet(
        position: position,
        heroStack: heroStack,
        bigBlind: bigBlind,
        cash: cash,
        allIn: allIn,
      ),
    );
  }

  @override
  State<VillainStackSheet> createState() => _VillainStackSheetState();
}

class _VillainStackSheetState extends State<VillainStackSheet> {
  static final _fractions = {
    0.25: '¼',
    0.5: '½',
    0.75: '¾',
    1.5: '1½',
    2.0: '2',
    3.0: '3',
  };

  double _multiple = 1.0;

  String _num(double v) =>
      NumberFormat('#,##0.##', Localizations.localeOf(context).toString())
          .format(v);

  String _main(AppLocalizations l10n, double m) => m == 1.0
      ? l10n.singleHandV2VillainEqual
      : l10n.singleHandV2VillainMultiple(_fractions[m] ?? _num(m));

  String _sub(AppLocalizations l10n, double m) {
    final stack = widget.heroStack * m;
    final bb = widget.bigBlind > 0 ? stack / widget.bigBlind : 0.0;
    if (widget.cash) {
      final money = stack == stack.roundToDouble()
          ? CurrencyService.formatCashRounded(stack)
          : CurrencyService.formatCash(stack);
      return l10n.singleHandV2VillainSubCash(_num(bb), money);
    }
    return l10n.singleHandV2VillainSubChips(_num(bb), _num(stack));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StackDragControl(
          steps: SingleHandSetup.relativeStackSteps,
          value: _multiple,
          mainLabel: (v) => _main(l10n, v),
          subLabel: (v) => _sub(l10n, v),
          onChanged: (v) => setState(() => _multiple = v),
          hintPrefsKey: VillainStackSheet.hintPrefsKey,
          semanticsLabel: l10n.singleHandV2VillainStackLabel,
          increaseLabel: l10n.singleHandV2StackUp,
          decreaseLabel: l10n.singleHandV2StackDown,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(l10n.singleHandV2VillainHint,
            textAlign: TextAlign.center,
            style: AppTypography.caption(color: AppColors.textDisabled)),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: widget.allIn
              ? l10n.singleHandV2VillainAllInConfirm
              : l10n.singleHandV2VillainSet,
          fullWidth: true,
          onTap: () => Navigator.pop(context, _multiple),
        ),
        if (!widget.allIn) ...[
          const SizedBox(height: AppSpacing.xxs),
          AppButton(
            label: l10n.singleHandV2VillainKeepEqual,
            variant: AppButtonVariant.secondaryLarge,
            fullWidth: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
