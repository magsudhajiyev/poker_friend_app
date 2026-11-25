import 'package:flutter/material.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/dialogs/app_dialog.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/single_hand_group.dart';
import '../../services/analytics_service.dart';
import '../../services/session_hand_info_pref.dart';
import '../../services/single_hand_service.dart';
import '../../utils/user_facing_error.dart';
import 'group_name_field.dart';

/// What the player chose on the saved dialog.
enum SingleHandChoice { another, done }

/// What the hand screen returns to the flow once a hand is saved.
class SingleHandOutcome {
  final SingleHandChoice choice;
  final SingleHandGroup group;
  const SingleHandOutcome(this.choice, this.group);
}

/// Shown after a single hand is saved: "Hand saved", Log another / Done.
/// Notes, tags and the star live in the hand details. Two extras only:
/// a hand that started a NEW group asks for its name first (D16), and a hand
/// saved INTO a running session carries one info line (with "Don't show
/// again").
class SingleHandSavedDialog extends StatefulWidget {
  final SingleHandSaveResult saved;

  /// Ask for the group name when [saved] started a new group (setup v2).
  final bool nameNewGroup;

  /// Called after the typed name was stored, with the renamed group.
  final ValueChanged<SingleHandGroup>? onNamed;

  /// Test seam: skips the stored "Don't show again" lookup.
  final bool? infoHidden;

  const SingleHandSavedDialog({
    super.key,
    required this.saved,
    this.nameNewGroup = false,
    this.onNamed,
    this.infoHidden,
  });

  /// Null (system back) counts as [SingleHandChoice.done].
  static Future<SingleHandChoice?> show(
    BuildContext context, {
    required SingleHandSaveResult saved,
    bool nameNewGroup = false,
    ValueChanged<SingleHandGroup>? onNamed,
  }) {
    return AppDialog.show<SingleHandChoice>(
      context,
      title: AppLocalizations.of(context).singleHandSavedTitle,
      showCloseButton: false,
      barrierDismissible: false,
      body: SingleHandSavedDialog(
          saved: saved, nameNewGroup: nameNewGroup, onNamed: onNamed),
    );
  }

  @override
  State<SingleHandSavedDialog> createState() => _SingleHandSavedDialogState();
}

class _SingleHandSavedDialogState extends State<SingleHandSavedDialog> {
  final _nameCtl = TextEditingController();
  bool _naming = false;
  bool _infoHidden = true; // hidden until the stored choice is known
  bool _dontShowAgain = false;

  late final bool _askName = widget.nameNewGroup &&
      widget.saved.newGroup &&
      !widget.saved.inSession;

  bool get _ready => (!_askName || _nameCtl.text.trim().isNotEmpty) && !_naming;

  @override
  void initState() {
    super.initState();
    if (widget.infoHidden != null) {
      _infoHidden = widget.infoHidden!;
    } else if (widget.saved.inSession) {
      SessionHandInfoPref.hidden().then((h) {
        if (mounted) setState(() => _infoHidden = h);
      });
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  /// Stores the typed group name. False (with a message) when it failed.
  Future<bool> _saveName() async {
    if (!_askName || _nameCtl.text.trim().isEmpty) return true;
    setState(() => _naming = true);
    try {
      await SingleHandService.renameGroup(
          widget.saved.sessionId, _nameCtl.text);
      widget.onNamed
          ?.call(widget.saved.group.copyWith(name: _nameCtl.text.trim()));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(UserFacingError.message(e)),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return false;
    } finally {
      if (mounted) setState(() => _naming = false);
    }
  }

  Future<void> _finish(SingleHandChoice choice, String action) async {
    if (!await _saveName()) return;
    if (_dontShowAgain) await SessionHandInfoPref.setHidden(true);
    AnalyticsService.singleHandPostAction(action);
    if (mounted) Navigator.pop(context, choice);
  }

  Widget _info(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.singleHandSavedSessionInfo,
            key: const ValueKey('session-info'),
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    key: const ValueKey('dont-show-again'),
                    value: _dontShowAgain,
                    activeColor: AppColors.accentPrimary,
                    onChanged: (v) =>
                        setState(() => _dontShowAgain = v ?? false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(l10n.singleHandDontShowAgain,
                    style: AppTypography.bodySmall(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(SingleHandChoice.done, 'done');
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_askName) ...[
            GroupNameField(
              controller: _nameCtl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (widget.saved.inSession && !_infoHidden) _info(l10n),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.singleHandLogAnother,
                  variant: AppButtonVariant.secondaryLarge,
                  onTap: _ready
                      ? () => _finish(SingleHandChoice.another, 'log_another')
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: AppButton(
                  label: l10n.singleHandDone,
                  onTap: _ready
                      ? () => _finish(SingleHandChoice.done, 'done')
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
