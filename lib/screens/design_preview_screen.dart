import 'package:flutter/material.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/headers/section_header.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/components/sheets/app_sheet.dart';
import '../design_system/components/bodies/form_fields.dart';
import '../design_system/components/bodies/message_body.dart';
import '../design_system/components/buttons/close_circle_button.dart';
import '../design_system/components/bodies/player_selection_list.dart';
import '../design_system/components/form_drawer.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../models/game_types.dart';
import '../models/hand_state_machine.dart';
import '../models/poker_game_state.dart';
import '../widgets/hole_cards_dialog.dart';
import '../widgets/board_cards_dialog.dart';
import '../widgets/winner_selection_dialog.dart';
import '../widgets/hand_review_dialog.dart';
import '../widgets/all_in_board_cards_dialog.dart';
import '../widgets/showdown_dialog.dart';
import '../widgets/session_end_bankroll_sheet.dart';
import '../widgets/session_summary_card.dart';
import '../widgets/multi_pot_winner_dialog.dart';
import '../widgets/seat_config_sheet.dart';
import '../widgets/skip_hand_scouting_sheet.dart';
import '../design_system/components/overlays/event_success_popup.dart';
import '../design_system/components/overlays/sliding_notification.dart';
import '../design_system/components/pickers/card_keyboard.dart';
import '../design_system/components/pickers/date/calendar_picker.dart';
import '../design_system/components/pickers/date/custom_date_picker.dart';
import '../design_system/components/pickers/date/time_picker_row.dart';
import '../design_system/components/cards/glassy_card.dart';
import '../design_system/components/cards/info_card.dart';
import '../design_system/components/cards/semi_transparent_card.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../widgets/register_club_dialog.dart';
import 'logging_mode_selection_screen.dart';
import '../services/locale_service.dart';
import '../services/currency_service.dart';
import '../models/currency.dart';

/// Debug-only screen for previewing all dialogs, modals, drawers, and popups
/// with mock data. Accessible from Settings → Admin → Design Preview.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          TopNavBar(
            title: 'Design Preview',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // ── Section 1: Dialogs ──────────────────────────
                const SectionHeader(title: 'Dialogs'),
                const SizedBox(height: 8),
                _devButton('AppDialog (base scaffold)', const Color(0xFFFF6B6B),
                    () {
                  AppDialog.show<void>(
                    context,
                    title: 'AppDialog Preview',
                    subtitle: 'Canonical dark surface, radius 24, blur backdrop',
                    body: Text(
                      'This is what every migrated dialog now uses under the hood. Pass a title, a body widget, and an optional actions widget (typically a DialogActionBar).',
                      style: AppTypography.ibm(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 22 / 15,
                      ),
                    ),
                    actions: const DialogActionBar(
                      confirmLabel: 'Got it',
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('ConfirmDialog', const Color(0xFFFF6B6B), () {
                  ConfirmDialog.show(
                    context,
                    title: 'Delete Session?',
                    message: 'This will permanently remove the session and all logged hands. This action cannot be undone.',
                    confirmLabel: 'Delete',
                    onConfirm: () {},
                  );
                }),
                const SizedBox(height: 8),
                _devButton('HoleCardsDialog', const Color(0xFFFF6B6B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const HoleCardsDialog(usedCards: {}),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('BoardCardsDialog (Flop)', const Color(0xFFFF6B6B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const BoardCardsDialog(
                      currentRound: BettingRound.flop,
                      excludedCards: [],
                      usedCards: {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('WinnerSelectionDialog', const Color(0xFFFF6B6B), () {
                  WinnerSelectionDialog.show(
                    context: context,
                    activePlayers: const [1, 2, 3],
                    playerNames: const ['Hero', 'Villain 1', 'Villain 2'],
                    potAmount: 1500,
                    buttonPosition: 1,
                    playerCount: 3,
                    gameType: GameType.cash,
                    heroSeat: 1,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('HandReviewDialog', const Color(0xFFFF6B6B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const HandReviewDialog(usedCards: {}),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('AllInBoardCardsDialog', const Color(0xFFFF6B6B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const AllInBoardCardsDialog(excludedCards: []),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('ShowdownDialog', const Color(0xFFFF6B6B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const ShowdownDialog(
                      playerCount: 3,
                      activePlayers: [1, 2, 3],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('EventSuccessPopup', const Color(0xFFFF6B6B), () {
                  EventSuccessPopup.show(context);
                }),
                const SizedBox(height: 8),
                _devButton('Intro Blind Input', const Color(0xFFFF6B6B), () {
                  final controller = TextEditingController(text: '20');
                  AppDialog.show<void>(
                    context,
                    title: 'Enter Big Blind',
                    body: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: AppTypography.ibm(
                          fontSize: 16, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        hintStyle:
                            AppTypography.ibm(color: AppColors.textSecondary),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: AppColors.borderStrong),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.accentPrimary, width: 2),
                        ),
                      ),
                    ),
                    actions: DialogActionBar(
                      confirmLabel: 'OK',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Onboarding Complete', const Color(0xFFFF6B6B), () {
                  AppDialog.show<void>(
                    context,
                    showCloseButton: false,
                    barrierDismissible: false,
                    body: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.accentPrimary,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You\'re all set!',
                          style: AppTypography.ibm(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You now know how to log a hand from start to finish. Time to fire up your first session.',
                          style: AppTypography.ibm(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.44,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: const DialogActionBar.single(cancelLabel: 'Done'),
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 2: Bottom Sheets / Drawers ──────────
                const SectionHeader(title: 'Bottom Sheets / Drawers'),
                const SizedBox(height: 8),
                _devButton('FormDrawer (empty demo)', const Color(0xFF6B9FFF), () {
                  FormDrawer.show(
                    context: context,
                    title: 'Sample Form',
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('This is a sample form drawer body.',
                              style: AppTypography.ibm(fontSize: 15, color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Text field placeholder',
                                style: AppTypography.ibm(fontSize: 15, color: AppColors.contentInactive)),
                          ),
                        ],
                      ),
                    ),
                    onSave: () => Navigator.pop(context),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SessionEndBankrollSheet (Cash)', const Color(0xFF6B9FFF), () {
                  SessionEndBankrollSheet.show(
                    context: context,
                    gameType: GameType.cash,
                    totalBuyIn: 500,
                    profitLoss: 150,
                    durationMinutes: 180,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SessionEndBankrollSheet (Tournament)', const Color(0xFF6B9FFF), () {
                  SessionEndBankrollSheet.show(
                    context: context,
                    gameType: GameType.tournament,
                    totalBuyIn: 200,
                    durationMinutes: 300,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('MultiPotWinnerDialog', const Color(0xFF6B9FFF), () {
                  MultiPotWinnerDialog.show(
                    context: context,
                    sidePots: [
                      SidePot(amount: 900, eligiblePlayers: [1, 2, 3, 4], maxContribution: 300),
                      SidePot(amount: 600, eligiblePlayers: [1, 2, 3], maxContribution: 200),
                    ],
                    playerNames: ['Hero', 'Villain 1', 'Villain 2', 'Villain 3'],
                    playerIdToName: {1: 'Hero (BTN)', 2: 'Villain 1 (SB)', 3: 'Villain 2 (BB)', 4: 'Villain 3 (UTG)'},
                    buttonPosition: 1,
                    playerCount: 4,
                    gameType: GameType.cash,
                    heroSeat: 1,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SeatConfigSheet', const Color(0xFF6B9FFF), () {
                  SeatConfigSheet.show(
                    context: context,
                    seatNumber: 3,
                    initialName: 'Player 3',
                    initialStack: 1000,
                    isHero: false,
                    isActive: true,
                    defaultStack: 1000,
                    onSave: ({required name, required stack, required isHero, required isActive}) {},
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SkipHandScoutingSheet', const Color(0xFF6B9FFF), () {
                  SkipHandScoutingSheet.show(
                    context: context,
                    playerNames: {1: 'Hero', 2: 'Villain 1', 3: 'Villain 2', 4: 'Villain 3', 5: 'Villain 4'},
                    activeSeats: {1, 2, 3, 4, 5},
                    heroSeat: 1,
                    buttonPosition: 3,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('RegisterClubDialog', const Color(0xFF6B9FFF), () {
                  showRegisterClubDialog(context);
                }),

                const SizedBox(height: 24),

                // ── Section 3: Cards / Overlays ─────────────────
                const SectionHeader(title: 'Cards / Overlays'),
                const SizedBox(height: 8),
                _devButton('SessionSummaryCard (Cash, +\$350)', const Color(0xFF54E98A), () {
                  SessionSummaryCard.show(
                    context: context,
                    data: const SessionSummaryData(
                      sessionName: 'Friday Night Cash',
                      gameType: GameType.cash,
                      profitLoss: 350,
                      totalBuyIn: 500,
                      handsPlayed: 47,
                      biggestPot: 820,
                      durationMinutes: 195,
                      biggestPotWonCards: 'A\u2660 K\u2665',
                      biggestPotLostCards: 'Q\u2666 J\u2663',
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SessionSummaryCard (Tournament, -\$200)', const Color(0xFF54E98A), () {
                  SessionSummaryCard.show(
                    context: context,
                    data: const SessionSummaryData(
                      sessionName: 'Sunday MTT',
                      gameType: GameType.tournament,
                      profitLoss: -200,
                      totalBuyIn: 200,
                      handsPlayed: 83,
                      biggestPot: 24000,
                      biggestPotBB: 400,
                      durationMinutes: 300,
                      finishedPlace: 11,
                      fieldSize: 28,
                      prizeWon: 0,
                      biggestPotWonCards: '9\u2660 9\u2665',
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('GlassyCard', const Color(0xFF54E98A), () {
                  showDialog(
                    context: context,
                    builder: (_) => Center(
                      child: SizedBox(
                        width: 320,
                        child: GlassyCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GlassyCard',
                                  style: AppTypography.ibm(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('Blurred glassy surface used on Home, Sessions, and Events.',
                                  style: AppTypography.ibm(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('InfoCard', const Color(0xFF54E98A), () {
                  showDialog(
                    context: context,
                    builder: (_) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: InfoCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('InfoCard',
                                    style: AppTypography.ibm(
                                        color: AppColors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text('Dark surface card with an empty-state mode.',
                                    style: AppTypography.ibm(
                                        color: AppColors.textSecondary,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SemiTransparentCard', const Color(0xFF54E98A), () {
                  showDialog(
                    context: context,
                    builder: (_) => Center(
                      child: SizedBox(
                        width: 320,
                        child: SemiTransparentCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SemiTransparentCard',
                                  style: AppTypography.ibm(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('Same as glassy, no blur. Cheaper to render.',
                                  style: AppTypography.ibm(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('ErrorStateCard', const Color(0xFF54E98A), () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => Scaffold(
                      backgroundColor: AppColors.bgPrimary,
                      body: ErrorStateCard(
                        title: 'Something went wrong',
                        message: 'We couldn\u2019t load your data.\nPlease check your connection and try again.',
                        onRetry: () => Navigator.pop(dialogCtx),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SlidingNotification', const Color(0xFF54E98A), () {
                  SlidingNotificationOverlay.show(
                    context: context,
                    title: 'Seat available',
                    subtitle: 'Table 2 \u00b7 Seat 4',
                    detail: '\$1/\$2 NLHE',
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 4: Pickers ──────────────────────────
                const SectionHeader(title: 'Pickers'),
                const SizedBox(height: 8),
                _devButton('Language Picker', const Color(0xFFE8B55A), () {
                  _showLanguagePicker(context);
                }),
                const SizedBox(height: 8),
                _devButton('Currency Picker', const Color(0xFFE8B55A), () {
                  _showCurrencyPicker(context);
                }),
                const SizedBox(height: 8),
                _devButton('CardKeyboard', const Color(0xFFE8B55A), () {
                  final slots = ['', ''];
                  final selected = <String>{};
                  AppDialog.show<void>(
                    context,
                    title: 'CardKeyboard preview',
                    body: StatefulBuilder(builder: (ctx, setState) {
                      return CardKeyboard(
                        slotCount: 2,
                        slots: slots,
                        excludedCards: selected,
                        onCardCommitted: (i, card) => setState(() {
                          slots[i] = card;
                          selected.add(card);
                        }),
                        onCardCleared: (i) => setState(() {
                          if (slots[i].length > 1) selected.remove(slots[i]);
                          slots[i] = '';
                        }),
                      );
                    }),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('CalendarPicker', const Color(0xFFE8B55A), () {
                  final now = DateTime.now();
                  showDialog(
                    context: context,
                    builder: (_) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: CalendarPicker(
                          selectedDate: now,
                          displayedMonth: DateTime(now.year, now.month),
                          selectedTime: TimeOfDay.now(),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('CustomDatePicker', const Color(0xFFE8B55A), () async {
                  await showCustomDatePicker(
                    context,
                    initialDate: DateTime.now(),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('TimePickerRow', const Color(0xFFE8B55A), () {
                  showDialog(
                    context: context,
                    builder: (_) => Center(
                      child: SizedBox(
                        width: 320,
                        child: Material(
                          color: AppColors.bgSurface,
                          borderRadius:
                              BorderRadius.circular(AppDecorations.radiusLg),
                          child: TimePickerRow(time: TimeOfDay.now()),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 5: Session-details dialogs ─────────
                const SectionHeader(title: 'Session Details'),
                const SizedBox(height: 8),
                _devButton('Update Blinds (session_details)', const Color(0xFFFF6B6B), () {
                  final sb = TextEditingController(text: '25');
                  final bb = TextEditingController(text: '50');
                  AppDialog.show<void>(
                    context,
                    title: 'Update blinds',
                    body: FormFields(children: [
                      AppFormField(controller: sb, label: 'Small blind', keyboardType: TextInputType.number),
                      AppFormField(controller: bb, label: 'Big blind', keyboardType: TextInputType.number),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Update',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Confirm Rebuy (session_details)', const Color(0xFFFF6B6B), () {
                  ConfirmDialog.show(
                    context,
                    title: 'Confirm rebuy',
                    message: 'Current stack: \$4,500\n\nYou\'re about to rebuy for \$500. This will replace your existing stack.',
                    confirmLabel: 'Rebuy',
                    onConfirm: () {},
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Add-On (session_details)', const Color(0xFFFF6B6B), () {
                  final price = TextEditingController();
                  final chips = TextEditingController();
                  AppDialog.show<void>(
                    context,
                    title: 'Add-on',
                    body: FormFields(children: [
                      AppFormField(controller: price, label: 'Price', prefixText: '\$ ', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      AppFormField(controller: chips, label: 'Chips added', keyboardType: TextInputType.number),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Confirm',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Rebuy (session_details)', const Color(0xFFFF6B6B), () {
                  final amt = TextEditingController();
                  final stack = TextEditingController();
                  AppDialog.show<void>(
                    context,
                    title: 'Rebuy',
                    body: FormFields(children: [
                      AppFormField(controller: amt, label: 'Rebuy amount', prefixText: '\$ ', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      AppFormField(controller: stack, label: 'New stack size', keyboardType: TextInputType.number),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Rebuy',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Delete Session (session_analytics)', const Color(0xFFFF6B6B), () {
                  ConfirmDialog.show(
                    context,
                    title: 'Delete this session?',
                    message: 'This will permanently remove the session and all logged hands. This action cannot be undone.',
                    confirmLabel: 'Delete',
                    onConfirm: () {},
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Export Limit (session_analytics)', const Color(0xFFFF6B6B), () {
                  AppDialog.show<void>(
                    context,
                    title: 'Monthly export limit reached',
                    body: const MessageBody(
                      'You\'ve used all 30 of your Pro tier session exports this month. Upgrade to Elite for unlimited exports.',
                    ),
                    actions: DialogActionBar(
                      cancelLabel: 'OK',
                      confirmLabel: 'Upgrade to Elite',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Export Session (session_analytics)', const Color(0xFFFF6B6B), () {
                  ConfirmDialog.show(
                    context,
                    title: 'Export this session?',
                    message: 'Send 87 hands to turaljumshud@gmail.com?',
                    confirmLabel: 'Export',
                    confirmColor: AppColors.accentPrimary,
                    confirmTextColor: AppColors.textInverse,
                    onConfirm: () {},
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 6: Notifications / Dealer / Misc ─────
                const SectionHeader(title: 'Notifications & Dealer'),
                const SizedBox(height: 8),
                _devButton('Support Response (notifications)', const Color(0xFFFF6B6B), () {
                  AppDialog.show<void>(
                    context,
                    title: 'Request resolved',
                    body: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.check_circle, color: AppColors.accentPrimary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Cash-out issue on tournament results',
                            style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500))),
                        ]),
                        const SizedBox(height: 4),
                        Text('Session tracking', style: AppTypography.ibm(color: AppColors.textDisabled, fontSize: 13)),
                        const SizedBox(height: 16),
                        Text('RESPONSE', style: AppTypography.ibm(color: AppColors.textDisabled, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDecorations.radius10),
                          ),
                          child: Text(
                            'Thanks for the report — we\'ve pushed a fix in the 1.0.4 update. Please pull the latest and reach out if the issue persists.',
                            style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                    actions: const DialogActionBar.single(cancelLabel: 'OK'),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Invitation Response (notifications)', const Color(0xFFFF6B6B), () {
                  AppDialog.show<void>(
                    context,
                    title: 'Club invitation',
                    body: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mail, color: AppColors.accentPurple, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text('You\'ve been invited to join', textAlign: TextAlign.center,
                          style: AppTypography.ibm(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('Blue Chip Poker', textAlign: TextAlign.center,
                          style: AppTypography.ibm(color: AppColors.accentPurple, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Michael sent you an invitation. Tap Accept to join their club.', textAlign: TextAlign.center,
                          style: AppTypography.ibm(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    actions: DialogActionBar(
                      cancelLabel: 'Decline',
                      confirmLabel: 'Accept',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Session Settings (Dealer)', const Color(0xFFFF6B6B), () {
                  final sb = TextEditingController(text: '1');
                  final bb = TextEditingController(text: '2');
                  AppDialog.show<void>(
                    context,
                    title: 'Session settings',
                    body: FormFields(children: [
                      AppFormField(controller: sb, label: 'Small blind', keyboardType: TextInputType.number),
                      AppFormField(controller: bb, label: 'Big blind', keyboardType: TextInputType.number),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Start session',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('QR Codes (Dealer)', const Color(0xFFFF6B6B), () {
                  AppDialog.show<void>(
                    context,
                    title: 'Blue Chip Poker · Seat 3',
                    body: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 200, height: 200,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: const Center(child: Icon(Icons.qr_code_2, size: 180, color: Colors.black)),
                      ),
                      const SizedBox(height: 16),
                      Text('Scan to join Seat 3', style: AppTypography.ibm(color: AppColors.accentPrimary, fontSize: 13)),
                    ]),
                    actions: const DialogActionBar.single(cancelLabel: 'Close'),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('User Search (Dealer)', const Color(0xFFFF6B6B), () {
                  final search = TextEditingController();
                  final stack = TextEditingController(text: '5000');
                  AppDialog.show<void>(
                    context,
                    title: 'Add player to Seat 3',
                    body: FormFields(children: [
                      AppFormField(controller: search, label: 'Search by name', autofocus: true),
                      AppFormField(controller: stack, label: 'Starting chip stack', keyboardType: TextInputType.number),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Add player',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Invite Member', const Color(0xFFFF6B6B), () {
                  final email = TextEditingController();
                  AppDialog.show<void>(
                    context,
                    title: 'Invite a member',
                    body: FormFields(children: [
                      AppFormField(controller: email, label: 'Email address', keyboardType: TextInputType.emailAddress, autofocus: true),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Send invite',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Seat Management', const Color(0xFFFF6B6B), () {
                  bool aSel = true;
                  AppDialog.show<void>(
                    context,
                    title: 'Manage seats',
                    body: StatefulBuilder(builder: (ctx, setSt) {
                      return PlayerSelectionList(children: [
                        PlayerSelectionRow(label: 'Seat 1 · Hero', selected: aSel, onTap: () => setSt(() => aSel = true)),
                        PlayerSelectionRow(label: 'Seat 3 · Villain', selected: !aSel, onTap: () => setSt(() => aSel = false)),
                      ]);
                    }),
                    actions: DialogActionBar(
                      confirmLabel: 'Confirm',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('Table Selection', const Color(0xFFFF6B6B), () {
                  bool one = true;
                  AppDialog.show<void>(
                    context,
                    title: 'Pick a table',
                    body: StatefulBuilder(builder: (ctx, setSt) {
                      return PlayerSelectionList(children: [
                        PlayerSelectionRow(label: 'Table 1 · \$1/\$2', selected: one, onTap: () => setSt(() => one = true)),
                        PlayerSelectionRow(label: 'Table 2 · \$2/\$5', selected: !one, onTap: () => setSt(() => one = false)),
                      ]);
                    }),
                    actions: DialogActionBar(
                      confirmLabel: 'Choose',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 7: Club sheets & Training ─────
                const SectionHeader(title: 'Club Sheets & Training'),
                const SizedBox(height: 8),
                _devButton('_MemberSearchSheet', const Color(0xFF6B9FFF), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Select member',
                    heightFraction: 0.75,
                    body: PlayerSelectionList(children: [
                      PlayerSelectionRow(label: 'Michael', selected: true, onTap: () {}),
                      PlayerSelectionRow(label: 'Sarah', selected: false, onTap: () {}),
                      PlayerSelectionRow(label: 'James', selected: false, onTap: () {}),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('_AdminWaitlistSheet', const Color(0xFF6B9FFF), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Waitlist (\$1/\$2)',
                    heightFraction: 0.75,
                    body: PlayerSelectionList(children: [
                      PlayerSelectionRow(label: '#1 · Michael', selected: false, trailing: const Icon(Icons.notifications, color: AppColors.accentPrimary, size: 20), onTap: () {}),
                      PlayerSelectionRow(label: '#2 · Sarah', selected: false, trailing: const Icon(Icons.notifications, color: AppColors.accentPrimary, size: 20), onTap: () {}),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('_AddTableSheet', const Color(0xFF6B9FFF), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Add table to event',
                    heightFraction: 0.75,
                    body: PlayerSelectionList(children: [
                      PlayerSelectionRow(label: 'Sunday Grind', selected: true, onTap: () {}),
                      PlayerSelectionRow(label: 'Midweek Freeroll', selected: false, onTap: () {}),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('_OpponentPickerSheet', const Color(0xFF6B9FFF), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Pick an opponent',
                    heightFraction: 0.65,
                    body: PlayerSelectionList(children: [
                      PlayerSelectionRow(label: 'Loose Larry', selected: false, onTap: () {}),
                      PlayerSelectionRow(label: 'Tight Tim', selected: false, onTap: () {}),
                      PlayerSelectionRow(label: 'Balanced Bob', selected: true, onTap: () {}),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('_DrillSummarySheet', const Color(0xFF6B9FFF), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Drill summary',
                    heightFraction: 0.75,
                    body: const MessageBody('Accuracy 78% · 12 decisions · 9 correct · 2 close · 1 mistake'),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('TableManagementSheet', const Color(0xFF6B9FFF), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Table state',
                    heightFraction: 0.85,
                    body: PlayerSelectionList(children: [
                      PlayerSelectionRow(label: 'Seat 1 · Hero (BTN)', selected: true, onTap: () {}),
                      PlayerSelectionRow(label: 'Seat 3 · Villain 1', selected: false, onTap: () {}),
                      PlayerSelectionRow(label: 'Seat 5 · Villain 2', selected: false, onTap: () {}),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('CreateEventDrawer', const Color(0xFF6B9FFF), () {
                  final name = TextEditingController();
                  final buyIn = TextEditingController();
                  AppSheet.show<void>(
                    context: context,
                    title: 'Create event',
                    heightFraction: 0.9,
                    body: FormFields(children: [
                      AppFormField(controller: name, label: 'Event name', autofocus: true),
                      AppFormField(controller: buyIn, label: 'Buy-in', prefixText: '\$ ', keyboardType: TextInputType.number),
                    ]),
                    trailing: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38, height: 38,
                        decoration: const BoxDecoration(color: AppColors.accentPrimary, shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: AppColors.textInverse),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 8: Overlays & novel shapes ─────
                const SectionHeader(title: 'Overlays & Novel Shapes'),
                const SizedBox(height: 8),
                _devButton('AmountInputDialog', const Color(0xFFFFA500), () {
                  int amount = 4500;
                  AppDialog.show<void>(
                    context,
                    title: 'Adjust stack',
                    body: StatefulBuilder(builder: (ctx, setSt) {
                      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _amountStepper('−', () => setSt(() => amount = (amount - 500).clamp(0, 100000))),
                        const SizedBox(width: 16),
                        Text(amount.toString(),
                          style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        _amountStepper('+', () => setSt(() => amount += 500)),
                      ]);
                    }),
                    actions: DialogActionBar(
                      confirmLabel: 'Confirm',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('YearPicker', const Color(0xFFFFA500), () {
                  int selectedYear = 2026;
                  AppDialog.show<void>(
                    context,
                    title: 'Pick year',
                    body: StatefulBuilder(builder: (ctx, setSt) {
                      return Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final row in [[2022, 2023, 2024], [2025, 2026, 2027]])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              for (final y in row) ...[
                                Expanded(child: _yearCell(y, selectedYear == y, () => setSt(() => selectedYear = y))),
                                if (y != row.last) const SizedBox(width: 10),
                              ],
                            ]),
                          ),
                      ]);
                    }),
                    actions: DialogActionBar(
                      confirmLabel: 'Choose',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('PopupMenuDialog', const Color(0xFFFFA500), () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black45,
                    builder: (_) => Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80, right: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 220,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderStrong),
                            ),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              for (final item in const [
                                ['Edit', Icons.edit, false],
                                ['Duplicate', Icons.copy, false],
                                ['Share', Icons.share, false],
                                ['Star', Icons.star, false],
                                ['Delete', Icons.delete, true],
                              ])
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(children: [
                                      Icon(item[1] as IconData, size: 18,
                                        color: item[2] as bool ? AppColors.accentDanger : AppColors.textPrimary),
                                      const SizedBox(width: 10),
                                      Text(item[0] as String,
                                        style: AppTypography.ibm(
                                          color: item[2] as bool ? AppColors.accentDanger : AppColors.textPrimary,
                                          fontSize: 14)),
                                    ]),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('HandsLimitDialog (paywall)', const Color(0xFFFFA500), () {
                  AppDialog.show<void>(
                    context,
                    title: 'You\'ve hit your Free limit',
                    body: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('\$9.99', textAlign: TextAlign.center,
                        style: AppTypography.ibm(color: AppColors.accentPrimary, fontSize: 48, fontWeight: FontWeight.bold)),
                      Text('PRO · billed monthly', textAlign: TextAlign.center,
                        style: AppTypography.ibm(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      ...[
                        '✓  50 hands/session',
                        '✓  15 opponents',
                        '✓  90-day history',
                        '✓  Advanced stats',
                      ].map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(width: double.infinity, child: Text(line, style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 14))),
                      )),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Upgrade',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('AppNavigationDrawer (preview)', const Color(0xFFFFA500), () {
                  AppSheet.show<void>(
                    context: context,
                    title: 'Navigation drawer',
                    subtitle: 'Preview only — normally opens from Home',
                    heightFraction: 0.85,
                    body: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const CircleAvatar(radius: 22, backgroundColor: AppColors.accentPrimary),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Tural', style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                            Text('Pro · \$9.99/mo', style: AppTypography.ibm(color: AppColors.accentPrimary, fontSize: 13)),
                          ]),
                        ]),
                        const SizedBox(height: 20),
                        for (final item in const [
                          [Icons.home, 'Home'],
                          [Icons.bar_chart, 'Statistics'],
                          [Icons.calendar_today, 'Calendar'],
                          [Icons.emoji_events, 'Clubs'],
                          [Icons.settings, 'Settings'],
                          [Icons.menu_book, 'Knowledge base'],
                          [Icons.help_outline, 'Help & support'],
                          [Icons.logout, 'Log out'],
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Icon(item[0] as IconData, color: AppColors.textPrimary, size: 20),
                              const SizedBox(width: 14),
                              Text(item[1] as String, style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 15)),
                            ]),
                          ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('RaiseSnapOverlay (concept)', const Color(0xFFFFA500), () {
                  AppDialog.show<void>(
                    context,
                    title: 'Raise amount',
                    body: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('\$1,500', textAlign: TextAlign.center,
                        style: AppTypography.ibm(color: AppColors.accentPrimary, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(999)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.67,
                          child: Container(
                            decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('MIN 100', style: AppTypography.ibm(color: AppColors.textSecondary, fontSize: 12)),
                        Text('MAX 2,200 (all-in)', style: AppTypography.ibm(color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Confirm',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('OnboardingTour tooltip (concept)', const Color(0xFFFFA500), () {
                  AppDialog.show<void>(
                    context,
                    showCloseButton: false,
                    body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('This is your Bankroll',
                        style: AppTypography.ibm(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text('Tap the goal to set a target. Progress updates automatically after every session.',
                        style: AppTypography.ibm(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Next  →',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('_BustedPlayerDialog', const Color(0xFFFFA500), () {
                  final rank = TextEditingController(text: '11');
                  final cash = TextEditingController(text: '0');
                  AppDialog.show<void>(
                    context,
                    title: 'Villain 2 busted',
                    body: FormFields(children: [
                      AppFormField(controller: rank, label: 'Finish rank', keyboardType: TextInputType.number),
                      AppFormField(controller: cash, label: 'Prize won', prefixText: '\$ ', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ]),
                    actions: DialogActionBar(
                      confirmLabel: 'Record',
                      confirmColor: AppColors.accentPrimary,
                      confirmTextColor: AppColors.textInverse,
                      onConfirm: () {},
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // ── Section 9: Log Hand Flow ────────────────────
                // All modals surfaced during a single log-hand session,
                // in the order the user typically hits them.
                const SectionHeader(title: 'Log Hand Flow'),
                const SizedBox(height: 8),

                // 1. Entry
                _devButton('LoggingModeSelectionScreen', const Color(0xFFF6B26B), () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoggingModeSelectionScreen(),
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // 2. Seat / table config
                _devButton('SeatConfigSheet', const Color(0xFFF6B26B), () {
                  SeatConfigSheet.show(
                    context: context,
                    seatNumber: 3,
                    initialName: 'Player 3',
                    initialStack: 1000,
                    isHero: false,
                    isActive: true,
                    defaultStack: 1000,
                    onSave: ({required name, required stack, required isHero, required isActive}) {},
                  );
                }),
                const SizedBox(height: 8),
                _devButton('TableManagementSheet (needs live session)', const Color(0xFFF6B26B), () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('TableManagementSheet requires a live PokerSessionManager — preview from an active session.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // 3. Cards
                _devButton('HoleCardsDialog', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const HoleCardsDialog(usedCards: {}),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('BoardCardsDialog (Flop)', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const BoardCardsDialog(
                      currentRound: BettingRound.flop,
                      excludedCards: [],
                      usedCards: {},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('BoardCardsDialog (Turn)', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => BoardCardsDialog(
                      currentRound: BettingRound.turn,
                      existingCards: BoardCards(flop: const ['A♠', 'K♥', '2♣']),
                      excludedCards: const [],
                      usedCards: const {'A♠', 'K♥', '2♣'},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('BoardCardsDialog (River)', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => BoardCardsDialog(
                      currentRound: BettingRound.river,
                      existingCards: BoardCards(flop: const ['A♠', 'K♥', '2♣'], turn: '9♦'),
                      excludedCards: const [],
                      usedCards: const {'A♠', 'K♥', '2♣', '9♦'},
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _devButton('AllInBoardCardsDialog', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const AllInBoardCardsDialog(excludedCards: []),
                  );
                }),
                const SizedBox(height: 8),

                // 4. Winner + showdown
                _devButton('WinnerSelectionDialog', const Color(0xFFF6B26B), () {
                  WinnerSelectionDialog.show(
                    context: context,
                    activePlayers: const [1, 2, 3],
                    playerNames: const ['Hero', 'Villain 1', 'Villain 2'],
                    potAmount: 1500,
                    buttonPosition: 1,
                    playerCount: 3,
                    gameType: GameType.cash,
                    heroSeat: 1,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('MultiPotWinnerDialog', const Color(0xFFF6B26B), () {
                  MultiPotWinnerDialog.show(
                    context: context,
                    sidePots: [
                      SidePot(amount: 900, eligiblePlayers: [1, 2, 3, 4], maxContribution: 300),
                      SidePot(amount: 600, eligiblePlayers: [1, 2, 3], maxContribution: 200),
                    ],
                    playerNames: ['Hero', 'Villain 1', 'Villain 2', 'Villain 3'],
                    playerIdToName: {1: 'Hero (BTN)', 2: 'Villain 1 (SB)', 3: 'Villain 2 (BB)', 4: 'Villain 3 (UTG)'},
                    buttonPosition: 1,
                    playerCount: 4,
                    gameType: GameType.cash,
                    heroSeat: 1,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('ShowdownDialog', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const ShowdownDialog(
                      playerCount: 3,
                      activePlayers: [1, 2, 3],
                    ),
                  );
                }),
                const SizedBox(height: 8),

                // 5. Skip / review
                _devButton('SkipHandScoutingSheet', const Color(0xFFF6B26B), () {
                  SkipHandScoutingSheet.show(
                    context: context,
                    playerNames: {1: 'Hero', 2: 'Villain 1', 3: 'Villain 2', 4: 'Villain 3', 5: 'Villain 4'},
                    activeSeats: {1, 2, 3, 4, 5},
                    heroSeat: 1,
                    buttonPosition: 3,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('HandReviewDialog', const Color(0xFFF6B26B), () {
                  showDialog(
                    context: context,
                    builder: (_) => const HandReviewDialog(usedCards: {}),
                  );
                }),
                const SizedBox(height: 8),

                // 6. Confirmations
                _devButton('ConfirmDialog (Exit active session)', const Color(0xFFF6B26B), () {
                  ConfirmDialog.show(
                    context,
                    title: 'Exit session?',
                    message: 'Your current hand and session progress will be saved. You can resume from Sessions.',
                    confirmLabel: 'Exit',
                    onConfirm: () {},
                  );
                }),
                const SizedBox(height: 8),

                // 7. End of session
                _devButton('SessionEndBankrollSheet (Cash)', const Color(0xFFF6B26B), () {
                  SessionEndBankrollSheet.show(
                    context: context,
                    gameType: GameType.cash,
                    totalBuyIn: 500,
                    profitLoss: 150,
                    durationMinutes: 180,
                  );
                }),
                const SizedBox(height: 8),
                _devButton('SessionEndBankrollSheet (Tournament)', const Color(0xFFF6B26B), () {
                  SessionEndBankrollSheet.show(
                    context: context,
                    gameType: GameType.tournament,
                    totalBuyIn: 200,
                    durationMinutes: 300,
                  );
                }),

                const SizedBox(height: 120), // bottom nav clearance
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers used by the Section 5–8 modal previews ─────────────────

  static Widget _amountStepper(String symbol, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Center(
          child: Text(
            symbol,
            style: AppTypography.ibm(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _yearCell(int year, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPrimary : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            '$year',
            style: AppTypography.ibm(
              color: selected ? AppColors.textInverse : AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ── Dev button (same pattern as profile_screen) ─────────────────────────

  static Widget _devButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Center(
          child: Text(label, style: AppTypography.ibm(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }

  // ── Language Picker (adapted from settings_screen) ──────────────────────

  static const _languageOptions = [
    {'code': 'system', 'label': 'System Default', 'flag': '🌐'},
    {'code': 'en', 'label': 'English', 'flag': '🇺🇸'},
    {'code': 'de', 'label': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'es', 'label': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'label': 'Français', 'flag': '🇫🇷'},
    {'code': 'pt', 'label': 'Português', 'flag': '🇧🇷'},
    {'code': 'ru', 'label': 'Русский', 'flag': '🇷🇺'},
    {'code': 'pl', 'label': 'Polski', 'flag': '🇵🇱'},
  ];

  void _showLanguagePicker(BuildContext context) {
    String? selectedCode = LocaleService.currentLocaleCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final maxHeight = MediaQuery.of(context).size.height * 0.85;
            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Choose Language',
                              style: AppTypography.ibm(
                                  fontSize: 15, fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary, height: 20 / 15)),
                          CloseCircleButton(onTap: () => Navigator.pop(context)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ..._languageOptions.map((opt) {
                        final isSelected = opt['code'] == selectedCode;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setSheetState(() => selectedCode = opt['code']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                            ),
                            child: Row(
                              children: [
                                Text(opt['flag']!, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Text(opt['label']!,
                                    style: AppTypography.ibm(
                                        fontSize: 15, color: AppColors.textPrimary)),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(Icons.check, size: 18, color: AppColors.accentPrimary),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Currency Picker (adapted from settings_screen) ─────────────────────

  void _showCurrencyPicker(BuildContext context) {
    String selectedCode = CurrencyService.code;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final maxHeight = MediaQuery.of(context).size.height * 0.78;
            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Choose Currency',
                            style: AppTypography.ibm(
                                fontSize: 15, fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary, height: 20 / 15)),
                        CloseCircleButton(onTap: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: Currency.all.length,
                        itemBuilder: (context, index) {
                          final currency = Currency.all[index];
                          final isSelected = currency.code == selectedCode;
                          return Padding(
                            padding: EdgeInsets.only(bottom: index < Currency.all.length - 1 ? 4 : 0),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setSheetState(() => selectedCode = currency.code),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      child: Text(currency.symbol,
                                          style: AppTypography.ibm(
                                              fontSize: 16, fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${currency.name} (${currency.code})',
                                        style: AppTypography.ibm(
                                            fontSize: 15, color: AppColors.textPrimary)),
                                    const Spacer(),
                                    if (isSelected)
                                      const Icon(Icons.check, size: 18, color: AppColors.accentPrimary),
                                  ],
                                ),
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
          },
        );
      },
    );
  }
}
