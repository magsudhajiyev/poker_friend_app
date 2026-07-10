import 'package:flutter/material.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/headers/section_header.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/components/form_drawer.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../models/game_types.dart';
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
import '../widgets/event_success_popup.dart';
import '../widgets/register_club_dialog.dart';
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
                  showDialog(
                    context: context,
                    builder: (_) => WinnerSelectionDialog(
                      activePlayers: const [1, 2, 3],
                      playerNames: const ['Hero', 'Villain 1', 'Villain 2'],
                      potAmount: 1500,
                      buttonPosition: 1,
                      playerCount: 3,
                      gameType: GameType.cash,
                      heroSeat: 1,
                    ),
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

                const SizedBox(height: 120), // bottom nav clearance
              ],
            ),
          ),
        ],
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
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, size: 18, color: AppColors.contentInactive),
                          ),
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
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 18, color: AppColors.contentInactive),
                        ),
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
