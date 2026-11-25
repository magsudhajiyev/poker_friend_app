import 'package:flutter/material.dart';

import '../../models/single_hand_group.dart';
import '../../models/single_hand_setup.dart';
import '../../models/tracked_session.dart';
import '../../screens/poker_hand_screen.dart';
import '../../screens/single_hand_setup_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/feature_flag_service.dart';
import '../../services/free_tier_limits.dart';
import '../../services/session_navigation.dart';
import '../../services/single_hand_service.dart';
import '../../services/tracked_session_service.dart';
import 'group_name_field.dart';
import 'single_hand_result_sheet.dart';
import 'single_hand_setup_sheet.dart';
import '../../l10n/app_localizations.dart';

/// "Log a hand" flow: setup screen (flag `single_hand_v2`, always for a
/// tracked session) or sheet -> hand table -> result sheet, looping on
/// "Log another" with the same values and target.
class SingleHandFlow {
  SingleHandFlow._();

  /// Runs the flow from [context]. True when the player finished with Done
  /// (the caller should close its own screen); false when they backed out.
  ///
  /// [session] is the tracked session the hand belongs to (from its hub). When
  /// null and a tracked session is running, that session is the default
  /// target (D23); the setup screen lets the player pick a hand group instead.
  static Future<bool> run(BuildContext context,
      {SingleHandSessionTarget? session}) async {
    var note = false;
    if (session == null) {
      final r = resolveTarget(
        tracked: await TrackedSessionService.runningTarget(),
        full: await TrackedSessionService.runningFullTarget(),
        fullTableOpen: SessionNavigation.isOpen(SessionNavigation.fullHubKey),
      );
      session = r.target;
      note = r.resumeUnavailable;
    }
    if (!context.mounted) return false;
    await _nameForgottenGroup(context);
    if (!context.mounted) return false;
    SingleHandSetup? setup;
    SingleHandGroup? group;
    var keepGroup = false;
    while (true) {
      final v2 = FeatureFlagService.singleHandV2Enabled || session != null;
      AnalyticsService.singleHandSetupOpened(variant: v2 ? 'v2' : 'v1');
      final start = v2
          ? await SingleHandSetupScreen.show(
              context,
              setup: setup,
              group: group,
              keepGroup: keepGroup,
              session: session,
              note: note ? AppLocalizations.of(context).trackedResumeUnavailable : null,
            )
          : await SingleHandSetupSheet.show(
              context,
              setup: setup,
              group: group,
              keepGroup: keepGroup,
            );
      if (start == null || !context.mounted) return false;
      note = false;
      final target = start.session;
      if (target != null && target.isFull) {
        // Resume the running full session's logging table (never mix single
        // hands into it); a table that is gone falls back to a hand group.
        if (SessionNavigation.popTo(
            Navigator.of(context), SessionNavigation.fullHubKey)) {
          return true;
        }
        session = null;
        continue;
      }
      if (target != null && !await _roomInSession(context, target)) {
        return false;
      }
      if (!context.mounted) return false;
      final outcome = await PokerHandScreen.openSingleHand(
        context,
        start.setup,
        groupId: start.group?.sessionId,
        session: target,
      );
      if (outcome == null || !context.mounted) return false;
      if (outcome.choice == SingleHandChoice.done) return true;
      setup = start.setup;
      if (target == null) {
        // The player left the session for a hand group: stay on groups.
        session = null;
        group = outcome.group;
        keepGroup = true;
      }
    }
  }

  /// Which target "Log a hand" defaults to. A running tracked session wins; a
  /// running FULL session is offered as "resume table" when its table is still
  /// on the stack, else the hand goes to a hand group with a one-line note.
  static ({SingleHandSessionTarget? target, bool resumeUnavailable})
      resolveTarget({
    SingleHandSessionTarget? tracked,
    SingleHandSessionTarget? full,
    required bool fullTableOpen,
  }) {
    if (tracked != null) return (target: tracked, resumeUnavailable: false);
    if (full != null) {
      return fullTableOpen
          ? (target: full, resumeUnavailable: false)
          : (target: null, resumeUnavailable: true);
    }
    return (target: null, resumeUnavailable: false);
  }

  /// The tier hand cap, checked BEFORE the hand is played (a hand that
  /// cannot be saved would be lost).
  static Future<bool> _roomInSession(
      BuildContext context, SingleHandSessionTarget target) async {
    final count = await TrackedSessionService.handCount(target.id);
    if (SingleHandService.canAddHand(count)) return true;
    if (context.mounted) await FreeTierLimits.showHandsLimitDialog(context);
    return false;
  }

  /// D16: the app was killed before a group got its name. Ask once now (the
  /// player may close the sheet to skip; it asks again next time).
  static Future<void> _nameForgottenGroup(BuildContext context) async {
    if (!FeatureFlagService.singleHandV2Enabled) return;
    List<SingleHandGroup> unnamed;
    try {
      unnamed = await SingleHandService.unnamedGroups();
    } catch (_) {
      return;
    }
    if (unnamed.isEmpty || !context.mounted) return;
    final name = await GroupNameSheet.show(context,
        title: AppLocalizations.of(context).groupNameAskTitle);
    if (name == null) return;
    try {
      await SingleHandService.renameGroup(unnamed.first.sessionId, name);
    } catch (_) {}
  }
}
