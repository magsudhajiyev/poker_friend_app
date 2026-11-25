import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/components/buttons/app_button.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../services/live_session_logic.dart';
import '../services/live_session_notification_service.dart';
import '../design_system/components/scale_tap_feedback.dart';
import '../services/session_navigation.dart';
import '../utils/running_session_label.dart';
import '../services/session_start_gate.dart';
import 'running_session_end.dart';

/// Home "running session" bar (D26): `<name> · <elapsed> · Resume`. Hidden
/// when no session runs and during the in-app tour. Also asks the D27 rule 1
/// question once per app open when the session has run for more than 24 h.
class LiveSessionBar extends StatefulWidget {
  const LiveSessionBar({super.key});

  @override
  State<LiveSessionBar> createState() => _LiveSessionBarState();
}

class _LiveSessionBarState extends State<LiveSessionBar>
    with WidgetsBindingObserver {
  Timer? _tick;
  bool _askedThisOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LiveSessionNotificationService.running.addListener(_onRunningChanged);
    // Hide the moment the in-app tour starts (a replay with a running session).
    OnboardingState.notifier.addListener(_onChanged);
    // An orphaned running session (record lost) gets its record back, so it
    // shows here and can be ended.
    unawaited(SessionStartGate.reconcile());
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _onChanged());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  @override
  void dispose() {
    _tick?.cancel();
    OnboardingState.notifier.removeListener(_onChanged);
    LiveSessionNotificationService.running
        .removeListener(_onRunningChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _askedThisOpen = false; // a new "open"
      _onChanged();
      _maybeAsk();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onRunningChanged() {
    _onChanged();
    if (!mounted) return;
    // The running session ended or was discarded: the NEXT one that still
    // runs (legacy data can hold several) takes its place, so all can be ended.
    if (LiveSessionNotificationService.running.value == null) {
      unawaited(SessionStartGate.reconcile());
    }
  }

  Future<void> _maybeAsk() async {
    if (_askedThisOpen || !mounted || OnboardingState.isOnboardingActive) {
      return;
    }
    final r = LiveSessionNotificationService.running.value ??
        await LiveSessionNotificationService.current();
    if (r == null || !mounted) return;
    if (!LiveSessionLogic.isOverdue(r.startTime, DateTime.now())) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _askedThisOpen = true;
    await showLiveSessionPrompt(context, r);
  }

  Future<void> _resume(LiveSessionRecord r) async {
    final nav = Navigator.of(context);
    // Single-flight: repeated taps while the open is running do nothing.
    await SessionNavigation.runOnce(
        'resume:${r.sessionId}',
        () => LiveSessionNotificationService.openRecord(nav, r,
            promptIfUnhandled: true));
  }

  @override
  Widget build(BuildContext context) {
    final r = LiveSessionNotificationService.running.value;
    if (r == null || OnboardingState.isOnboardingActive) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final elapsed = LiveSessionLogic.elapsedLabel(r.startTime, DateTime.now());
    final name = runningSessionLabel(l10n, r);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xxs, AppSpacing.md, AppSpacing.xxs),
      child: Semantics(
        button: true,
        child: ScaleTapFeedback(
          onTap: () => _resume(r),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              children: [
                Container(
                  width: AppSpacing.xxs,
                  height: AppSpacing.xxs,
                  decoration: const BoxDecoration(
                    color: AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$name · $elapsed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.liveSessionBarResume,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Still playing?" — End now / Set the real end time / Still playing.
Future<void> showLiveSessionPrompt(
    BuildContext context, LiveSessionRecord record) async {
  final l10n = AppLocalizations.of(context);
  final name =
      runningSessionLabel(l10n, record);
  final elapsed =
      LiveSessionLogic.elapsedLabel(record.startTime, DateTime.now());
  final choice = await AppDialog.show<_Choice>(
    context,
    title: l10n.liveSessionStillPlayingTitle,
    body: Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.liveSessionStillPlayingBody(name, elapsed),
            style: AppTypography.ibm(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 22 / 15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.liveSessionEndNow,
            variant: AppButtonVariant.destructive,
            fullWidth: true,
            onTap: () => Navigator.pop(ctx, _Choice.endNow),
          ),
          const SizedBox(height: AppSpacing.xxs),
          AppButton(
            label: l10n.liveSessionSetEndTime,
            variant: AppButtonVariant.secondaryLarge,
            fullWidth: true,
            onTap: () => Navigator.pop(ctx, _Choice.setTime),
          ),
          const SizedBox(height: AppSpacing.xxs),
          AppButton(
            label: l10n.liveSessionStillPlaying,
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onTap: () => Navigator.pop(ctx, _Choice.keep),
          ),
        ],
      ),
    ),
    showCloseButton: false,
    barrierDismissible: false,
  );
  if (choice == _Choice.endNow) {
    await RunningSessionEnd.end(context, record, DateTime.now());
  } else if (choice == _Choice.setTime && context.mounted) {
    final end = await _pickEndTime(context, record);
    if (end != null && context.mounted) {
      await RunningSessionEnd.end(context, record, end);
    }
  }
}

enum _Choice { endNow, setTime, keep }

/// Date then time; loops until the pick is valid or the user backs out.
Future<DateTime?> _pickEndTime(
    BuildContext context, LiveSessionRecord record) async {
  final l10n = AppLocalizations.of(context);
  while (context.mounted) {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      helpText: l10n.liveSessionPickEndTimeHelp,
      initialDate: now,
      firstDate: DateTime(record.startTime.year, record.startTime.month,
          record.startTime.day),
      lastDate: now,
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      helpText: l10n.liveSessionPickEndTimeHelp,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !context.mounted) return null;
    final end =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final check =
        LiveSessionLogic.validateEndTime(record.startTime, end, DateTime.now());
    if (check == EndTimeCheck.ok) return end;
    if (!context.mounted) return null;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(check == EndTimeCheck.beforeStart
          ? l10n.liveSessionEndTimeBeforeStart
          : l10n.liveSessionEndTimeInFuture),
    ));
  }
  return null;
}
