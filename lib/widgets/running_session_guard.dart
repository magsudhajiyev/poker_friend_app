import 'package:flutter/material.dart';

import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../services/live_session_logic.dart';
import '../services/live_session_notification_service.dart';
import '../services/session_navigation.dart';
import '../services/session_start_gate.dart';
import '../utils/running_session_label.dart';

/// One running session at a time: starting a tracked or a full session while
/// another one runs is BLOCKED. An info dialog names the running session and
/// offers "Go to session" (its hub, opened through the single-flight
/// navigation) or Cancel. There is no "end and continue".
class RunningSessionGuard {
  RunningSessionGuard._();

  /// The running session of any kind; a seam for tests.
  static Future<LiveSessionRecord?> Function() current =
      SessionStartGate.findRunning;

  /// Opens the running session; a seam for tests.
  static Future<void> Function(NavigatorState nav, LiveSessionRecord record)
      goTo = (nav, r) async {
    // A full session whose table is still on the stack: pop back to it.
    if (r.kind == LiveSessionRecord.kindFull &&
        SessionNavigation.popTo(nav, SessionNavigation.fullHubKey)) {
      return;
    }
    await LiveSessionNotificationService.openRecord(nav, r,
        promptIfUnhandled: true);
  };

  /// True when the caller may start a new session (nothing runs). When one
  /// runs, shows the info dialog and returns false.
  static Future<bool> ensureFree(BuildContext context) async {
    final running = await current();
    if (running == null || !context.mounted) return true;
    await showBlocked(context, running);
    return false;
  }

  /// The blocking dialog for [running]; "Go to session" opens it.
  static Future<void> showBlocked(
      BuildContext context, LiveSessionRecord running) async {
    final l10n = AppLocalizations.of(context);
    final name = runningSessionLabel(l10n, running);
    final nav = Navigator.of(context);
    final open = await ConfirmDialog.confirm(
      context,
      title: l10n.trackedRunningTitle,
      message: l10n.trackedRunningBlockMessage(name),
      confirmLabel: l10n.trackedRunningGoTo,
      confirmColor: AppColors.accentPrimary,
      confirmTextColor: AppColors.bgPrimary,
    );
    if (open) await goTo(nav, running);
  }
}
