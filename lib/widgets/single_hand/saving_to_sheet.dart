import 'package:flutter/material.dart';

import '../../design_system/components/dividers/list_separator.dart';
import '../../design_system/components/sheets/app_sheet.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../models/single_hand_group.dart';
import '../../models/tracked_session.dart';
import '../../services/logger_service.dart';
import '../../services/single_hand_service.dart';

/// What the player picked on [SavingToSheet]: the running session, a hand
/// group, or (group null, session false) a new hand group.
class SavingToChoice {
  final bool session;
  final SingleHandGroup? group;
  const SavingToChoice.session()
      : session = true,
        group = null;
  const SavingToChoice.group(this.group) : session = false;
}

/// "Saving to <session>" picker of the setup screen (D23): keep the running
/// tracked session, or save this hand into a hand group instead.
class SavingToSheet extends StatefulWidget {
  final SingleHandSessionTarget session;
  final bool sessionSelected;
  final List<SingleHandGroup>? groups;

  const SavingToSheet({
    super.key,
    required this.session,
    required this.sessionSelected,
    this.groups,
  });

  static Future<SavingToChoice?> show(
    BuildContext context, {
    required SingleHandSessionTarget session,
    required bool sessionSelected,
    List<SingleHandGroup>? groups,
  }) {
    return AppSheet.show<SavingToChoice>(
      context: context,
      title: AppLocalizations.of(context).trackedSavingToTitle,
      heightFraction: null,
      body: SavingToSheet(
        session: session,
        sessionSelected: sessionSelected,
        groups: groups,
      ),
    );
  }

  @override
  State<SavingToSheet> createState() => _SavingToSheetState();
}

class _SavingToSheetState extends State<SavingToSheet> {
  List<SingleHandGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    if (widget.groups != null) {
      _groups = widget.groups!;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final g = await SingleHandService.recentGroups();
      if (mounted) setState(() => _groups = g);
    } catch (e) {
      LoggerService.log('Saving-to groups failed: $e', level: LogLevel.WARNING);
    }
  }

  Widget _row(String title, String? sub, SavingToChoice choice,
      {bool selected = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context, choice),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.listRowLabel()),
                  if (sub != null)
                    Text(sub,
                        style: AppTypography.bodySmall(
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 20, color: AppColors.accentPrimary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _row(widget.session.name, widget.session.isFull
            ? l10n.trackedSavingToResumeSub
            : l10n.trackedSavingToSessionSub,
            const SavingToChoice.session(),
            selected: widget.sessionSelected),
        const ListSeparator(),
        _row(l10n.trackedNewHandGroup, null, const SavingToChoice.group(null)),
        for (final g in _groups) ...[
          const ListSeparator(),
          _row(g.needsName ? l10n.groupUnnamed : g.name,
              l10n.singleHandGroupHands(g.handCount),
              SavingToChoice.group(g)),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.md),
      ],
    );
  }
}
