import 'package:flutter/material.dart';

import '../../models/single_hand_group.dart';
import '../../models/single_hand_setup.dart';
import '../../screens/poker_hand_screen.dart';
import 'single_hand_result_sheet.dart';
import 'single_hand_setup_sheet.dart';

/// "Log a hand" flow: setup sheet -> hand table -> result sheet, looping on
/// "Log another" with the same values and group.
class SingleHandFlow {
  SingleHandFlow._();

  /// Runs the flow from [context]. True when the player finished with Done
  /// (the caller should close its own screen); false when they backed out.
  static Future<bool> run(BuildContext context) async {
    SingleHandSetup? setup;
    SingleHandGroup? group;
    var keepGroup = false;
    while (true) {
      final start = await SingleHandSetupSheet.show(
        context,
        setup: setup,
        group: group,
        keepGroup: keepGroup,
      );
      if (start == null || !context.mounted) return false;
      final outcome = await PokerHandScreen.openSingleHand(
        context,
        start.setup,
        groupId: start.group?.sessionId,
      );
      if (outcome == null || !context.mounted) return false;
      if (outcome.choice == SingleHandChoice.done) return true;
      setup = start.setup;
      group = outcome.group;
      keepGroup = true;
    }
  }
}
