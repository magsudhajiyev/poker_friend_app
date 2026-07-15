import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/currency_service.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_service.dart';
import '../services/dealer_service.dart';
import '../services/auth_service.dart';
import '../utils/poker_positions.dart';
import '../widgets/loading_screen.dart';
import 'hand_actions_page_view.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';

class SessionHandsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionHandsScreen({Key? key, required this.session}) : super(key: key);

  @override
  _SessionHandsScreenState createState() => _SessionHandsScreenState();
}

class _SessionHandsScreenState extends State<SessionHandsScreen> {
  List<Map<String, dynamic>> hands = [];
  bool isLoading = true;
  String? error;

  // Phase-6 onboarding: spotlight for the tour hand card
  final GlobalKey _tourHandCardKey = GlobalKey();
  int? _tourHighlightIndex;

  @override
  void initState() {
    super.initState();
    _loadHands();
    _scheduleOnboardingTour();
  }

  /// Phase 6 — spotlight a hand card after the logged-hands handoff.
  /// Prefers a hand with hero hole cards so the AI-analysis step can run.
  void _scheduleOnboardingTour() async {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6 ||
        !OnboardingState.handCardTourPending) return;
    OnboardingState.handCardTourPending = false;

    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (!isLoading) break;
    }
    if (!mounted) return;
    if (hands.isEmpty) {
      finishOnboardingTour(context);
      return;
    }

    var targetIndex = hands.indexWhere((h) {
      final holeCards = h['ourHoleCards'];
      return holeCards is Map && holeCards.isNotEmpty;
    });
    if (targetIndex == -1) targetIndex = 0;

    setState(() => _tourHighlightIndex = targetIndex);

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (_tourHandCardKey.currentContext != null) break;
    }
    if (!mounted) return;
    if (_tourHandCardKey.currentContext == null) {
      finishOnboardingTour(context);
      return;
    }

    HandCardTour(handCardKey: _tourHandCardKey).show(context);
  }

  Future<void> _loadHands() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // For dealer sessions, fetch from dealer_sessions collection
      // which also merges player-submitted hole cards
      final dealerSessionIds = (widget.session['dealerSessionIds'] as List<dynamic>?)
          ?.cast<String>();
      final dealerSessionId = widget.session['dealerSessionId'] as String?;

      List<Map<String, dynamic>> loadedHands;
      if (dealerSessionIds != null && dealerSessionIds.isNotEmpty) {
        // Multi-table event: fetch and merge hands from ALL dealer sessions
        // Apply hand number offsets for continuous numbering across tables
        loadedHands = [];
        int handOffset = 0;
        for (final dsId in dealerSessionIds) {
          final sessionHands = await DealerService.getSessionHands(dsId);
          int maxHandNum = 0;
          for (final hand in sessionHands) {
            final origNum = hand['handNumber'] as int? ?? 0;
            if (origNum > maxHandNum) maxHandNum = origNum;
            hand['handNumber'] = origNum + handOffset;
          }
          loadedHands.addAll(sessionHands);
          handOffset += maxHandNum;
        }
        // Sort by timestamp for chronological order across tables
        loadedHands.sort((a, b) =>
            (a['startTime'] ?? '').compareTo(b['startTime'] ?? ''));
      } else if (dealerSessionId != null) {
        // Single dealer session (legacy or non-event)
        loadedHands = await DealerService.getSessionHands(dealerSessionId);
      } else {
        loadedHands = await FirebaseService.getSessionHands(widget.session['id']);
      }

      // For dealer session hands, inject heroSeatNumber from playerIds map
      final currentUserId = AuthService.userId;
      if (dealerSessionIds != null || dealerSessionId != null) {
        if (currentUserId != null) {
          for (final hand in loadedHands) {
            if (hand['heroSeatNumber'] == null) {
              final playerIds = hand['playerIds'] as Map<String, dynamic>?;
              if (playerIds != null) {
                for (final entry in playerIds.entries) {
                  if (entry.value == currentUserId) {
                    hand['heroSeatNumber'] = int.tryParse(entry.key);
                    break;
                  }
                }
              }
            }
          }
        }
      }

      // Filter hands by participation periods for live sessions
      final isLiveSession = widget.session['isLive'] == true;

      if (isLiveSession && currentUserId != null) {
        final participationPeriods = widget.session['participationPeriods'] as Map<String, dynamic>?;
        if (participationPeriods != null && participationPeriods.containsKey(currentUserId)) {
          final periods = List<Map<String, dynamic>>.from(participationPeriods[currentUserId] ?? []);
          if (periods.isNotEmpty) {
            loadedHands = loadedHands.where((hand) {
              final handNumber = hand['handNumber'] as int? ?? 0;
              return periods.any((period) {
                final joined = period['joinedAtHand'] as int? ?? 1;
                final left = period['leftAtHand'] as int?;
                return handNumber >= joined && (left == null || handNumber <= left);
              });
            }).toList();
          }
        }
      }

      setState(() {
        hands = loadedHands;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load hands: ${UserFacingError.message(e)}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          Column(
              children: [
                // Header — matches TopNavBar geometry (statusBar + 56 + 12)
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    bottom: 12,
                  ),
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: BackButtonCircle(
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.session['sessionName'] != null &&
                                          widget.session['sessionName'].isNotEmpty
                                      ? widget.session['sessionName']
                                      : AppLocalizations.of(context).sessionHistorySessionId(widget.session['id'].substring(0, 8)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.ibm(
                                    fontSize: 17,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 22 / 17,
                                    letterSpacing: -0.43,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.of(context).sessionHandsHandsLogged(hands.length),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.ibm(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w400,
                                    height: 18 / 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return LoadingScreen(message: AppLocalizations.of(context).sessionHandsLoading);
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).sessionHandsError,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              style: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadHands,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
                child: Text(
                  AppLocalizations.of(context).commonRetry,
                  style: AppTypography.ibm(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (hands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.infoCardBg,
                borderRadius: BorderRadius.circular(AppDecorations.radius20),
              ),
              child: Image.asset(
                'assets/logo.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).sessionHandsNoHandsTitle,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).sessionHandsNoHandsSubtitle,
              style: AppTypography.ibm(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: hands.length,
      itemBuilder: (context, index) =>
          _buildHandCard(hands[index], index + 1, index),
    );
  }

  static const _mint = AppColors.accentPrimary;

  Widget _buildHandCard(Map<String, dynamic> hand, int handNumber, int index) {
    final l10n = AppLocalizations.of(context);
    final actions = hand['actions'] as List<dynamic>? ?? [];
    final startTime = DateTime.parse(hand['startTime']);
    final isStarred = hand['isStarred'] == true;
    final potAmount = hand['potAmount'] ?? 0;
    final isCash = hand['gameType'] == 'cash';
    final heroPositionName = hand['heroPositionName'] ??
        PokerPositions.getPositionName(
          hand['heroPosition'] ?? 1,
          hand['buttonPosition'],
          hand['playerCount'],
        );
    final winnerId = hand['winnerId'];
    final heroSeat = hand['heroSeatNumber'] ??
        widget.session['ourSeatNumber'] ??
        widget.session['ourSeat'];
    final heroWon = winnerId != null && winnerId == heroSeat;

    final potText =
        '${l10n.sessionHandsPot} ${isCash ? CurrencyService.formatCash((potAmount is double ? potAmount : (potAmount as num).toDouble())) : '${potAmount is double ? potAmount.toStringAsFixed(0) : potAmount}'}';

    final timeInfo =
        '${DateFormat('HH:mm').format(startTime)}  ·  ${l10n.sessionHandsActions(actions.length)}  ·  ${hand['playerCount']}p';

    return GestureDetector(
      key: index == _tourHighlightIndex ? _tourHandCardKey : null,
      onTap: () => _navigateToHandActions(hand),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.borderDefault, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: hand number chip + time info | WON badge
            Row(
              children: [
                Container(
                  width: 38,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$handNumber',
                        style: AppTypography.ibm(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 20 / 13,
                        ),
                      ),
                      if (isStarred) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeInfo,
                    style: AppTypography.ibm(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 22 / 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (heroWon)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                    ),
                    child: Text(
                      l10n.sessionHandsWon,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _mint,
                        height: 20 / 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: position chip + hero cards | pot chip
            Row(
              children: [
                _buildPlayerChip(
                    l10n.opponentHandsYou, heroPositionName,
                    isHero: true),
                if (_hasHeroCards(hand)) ...[
                  const SizedBox(width: 8),
                  _buildMiniCards(hand),
                ],
                const Spacer(),
                // Pot chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        potText,
                        style: AppTypography.ibm(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentPrimary,
                          height: 20 / 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 12, color: AppColors.accentPrimary),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerChip(String label, String position,
      {required bool isHero}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 28,
            child: Center(
              child: Text(
                label,
                style: AppTypography.ibm(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 20 / 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              position,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isHero
                    ? AppColors.accentSecondary
                    : AppColors.textSecondary,
                height: 20 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasHeroCards(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    if (ourHoleCards == null) return false;
    final card1 = ourHoleCards['card1'] as String?;
    final card2 = ourHoleCards['card2'] as String?;
    return card1 != null && card1.isNotEmpty && card2 != null && card2.isNotEmpty;
  }

  Widget _buildMiniCards(Map<String, dynamic> hand) {
    final ourHoleCards = hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (card1 != null) _buildMiniCard(card1),
        const SizedBox(width: 2),
        if (card2 != null) _buildMiniCard(card2),
      ],
    );
  }

  Widget _buildMiniCard(String card) {
    if (card.isEmpty) return const SizedBox.shrink();

    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';
    final isRedSuit = suit == '♥' || suit == '♦';
    final cardColor = isRedSuit ? Colors.red : Colors.black;

    return Container(
      width: 20,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: cardColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          Text(
            suit,
            style: TextStyle(
              color: cardColor,
              fontSize: 7,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHandActions(Map<String, dynamic> hand) async {
    final index = hands.indexOf(hand);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HandActionsPageView(
          hands: hands,
          initialIndex: index < 0 ? 0 : index,
          ourSeat: null, // Use per-hand heroSeatNumber instead of stale session-level seat
        ),
      ),
    );
    // Refresh data when returning (in case star was toggled)
    _loadHands();

    // The guided tour defers its completion (and guest sign-up) until the user
    // leaves the hand-details screen — fire it now, back on the hand list.
    if (OnboardingState.tourCompletionPending) {
      OnboardingState.tourCompletionPending = false;
      if (mounted) finishOnboardingTour(context);
    }
  }
}
