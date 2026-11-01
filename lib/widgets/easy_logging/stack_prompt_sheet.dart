import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/decimal_input.dart';

/// One-field sheet that asks for a stack ("your final stack", "your stack
/// before the rebuy"). Used when flagged hands are open and the live stack
/// cannot be trusted. Returns the entered stack, or null when dismissed.
class StackPromptSheet {
  StackPromptSheet._();

  static Future<double?> show(
    BuildContext context, {
    required String title,
    required String body,
    required double liveStack,
  }) {
    return AppSheet.show<double>(
      context: context,
      title: title,
      heightFraction: 0.5,
      body: StackPromptBody(body: body, liveStack: liveStack),
    );
  }
}

/// Body of [StackPromptSheet]; public so tests can host it directly.
class StackPromptBody extends StatefulWidget {
  final String body;
  final double liveStack;

  /// Called with the parsed stack. Default: pop the sheet with the value.
  final ValueChanged<double>? onSaved;

  const StackPromptBody({
    super.key,
    required this.body,
    required this.liveStack,
    this.onSaved,
  });

  @override
  State<StackPromptBody> createState() => _StackPromptBodyState();
}

class _StackPromptBodyState extends State<StackPromptBody> {
  late final TextEditingController _c = TextEditingController(
      text: widget.liveStack == widget.liveStack.roundToDouble()
          ? widget.liveStack.toStringAsFixed(0)
          : widget.liveStack.toStringAsFixed(2));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseDecimal(_c.text);
    if (v == null || v < 0) return;
    final cb = widget.onSaved;
    if (cb != null) {
      cb(v);
    } else {
      Navigator.pop(context, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.body,
            style: AppTypography.ibm(
                fontSize: 15, color: AppColors.textSecondary, height: 22 / 15),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            style: AppTypography.ibm(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            decoration: InputDecoration(labelText: l10n.easyLogStackCheckpointHint),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: l10n.commonSave, onTap: _save),
        ],
      ),
    );
  }
}
