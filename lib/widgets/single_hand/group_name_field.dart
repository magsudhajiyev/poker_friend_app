import 'package:flutter/material.dart';

import '../../design_system/components/app_text_field.dart';
import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../services/logger_service.dart';
import '../../services/single_hand_service.dart';

/// Required "Name this group" field with one-tap chips of the player's earlier
/// group names (decision D16). The parent owns [controller] and reads it.
class GroupNameField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Test seam: skips the lookup of earlier names.
  final List<String>? chips;

  const GroupNameField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
    this.chips,
  });

  @override
  State<GroupNameField> createState() => _GroupNameFieldState();
}

class _GroupNameFieldState extends State<GroupNameField> {
  List<String> _names = const [];

  @override
  void initState() {
    super.initState();
    if (widget.chips != null) {
      _names = widget.chips!;
    } else {
      _loadNames();
    }
  }

  Future<void> _loadNames() async {
    try {
      final names = await SingleHandService.recentGroupNames();
      if (mounted) setState(() => _names = names);
    } catch (e) {
      LoggerService.log('Group names failed: $e', level: LogLevel.WARNING);
    }
  }

  void _pick(String name) {
    widget.controller.text = name;
    widget.controller.selection =
        TextSelection.collapsed(offset: name.length);
    widget.onChanged?.call(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: l10n.groupNameLabel,
          hint: l10n.groupNameHint,
          controller: widget.controller,
          autofocus: widget.autofocus,
          showClearButton: false,
          textInputAction: TextInputAction.done,
          onChanged: widget.onChanged,
        ),
        if (_names.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.groupNameEarlier,
              style: AppTypography.caption(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final n in _names)
                GestureDetector(
                  key: ValueKey('group-name-chip-$n'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pick(n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderStrong),
                      borderRadius:
                          BorderRadius.circular(AppDecorations.radiusFull),
                    ),
                    child: Text(n,
                        style: AppTypography.labelChip()),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Sheet with the naming field and a Done button that stays disabled until a
/// name is typed. Used to rename a group, to name a group after the app was
/// killed before naming, and to name a NEW group made by "move to another
/// group". Resolves to the trimmed name, or null when closed.
class GroupNameSheet extends StatefulWidget {
  final String initial;
  const GroupNameSheet({super.key, this.initial = ''});

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    return AppSheet.show<String>(
      context: context,
      title: title,
      heightFraction: null,
      body: GroupNameSheet(initial: initial),
    );
  }

  @override
  State<GroupNameSheet> createState() => _GroupNameSheetState();
}

class _GroupNameSheetState extends State<GroupNameSheet> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool get _ready => _ctl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupNameField(
          controller: _ctl,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.singleHandDone,
          fullWidth: true,
          onTap: _ready ? () => Navigator.pop(context, _ctl.text.trim()) : null,
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.md),
      ],
    );
  }
}
