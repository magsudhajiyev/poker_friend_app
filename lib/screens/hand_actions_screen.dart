import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../utils/poker_positions.dart';
import '../utils/number_formatter.dart';
import '../models/game_types.dart';
import '../services/ai_analyzer_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/subscription_service.dart';
import '../services/pokerstars_export_service.dart';
import '../services/hand_sharing_service.dart';
import '../services/opponent_service.dart';
import '../services/play_style_detector.dart';
import 'package:share_plus/share_plus.dart';
import '../services/opponent_stats_service.dart';
import '../l10n/app_localizations.dart';
import 'paywall_screen.dart';
import '../services/currency_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/feature_flag_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class HandActionsScreen extends StatefulWidget {
  final Map<String, dynamic> hand;
  final int? ourSeat;

  const HandActionsScreen({Key? key, required this.hand, this.ourSeat}) : super(key: key);

  @override
  _HandActionsScreenState createState() => _HandActionsScreenState();
}

class _HandActionsScreenState extends State<HandActionsScreen> {
  Map<String, dynamic>? _aiAnalysis;
  bool _isAnalyzing = false;
  String? _analysisError;
  final ScrollController _scrollController = ScrollController();

  // Star, tags, and display state
  late bool _isStarred;
  bool _showBB = false;
  bool _isSharing = false;
  late List<String> _tags;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _isStarred = widget.hand['isStarred'] == true;
    final rawTags = widget.hand['tags'];
    _tags = rawTags is List ? rawTags.cast<String>() : [];
    _notes = widget.hand['notes'] as String?;
    _loadExistingAnalysis();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleStar() async {
    final newStarredState = !_isStarred;
    setState(() {
      _isStarred = newStarredState;
    });

    try {
      final sessionId = widget.hand['sessionId'] as String?;
      final handId = widget.hand['id'] as String?;

      if (sessionId != null && handId != null) {
        await FirebaseService.updateHandAnnotations(
          sessionId: sessionId,
          handId: handId,
          isStarred: newStarredState,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStarred = !newStarredState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).handActionsFailedToUpdateStar),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleShareButtonTap() async {
    if (_isSharing) return;

    // Ask whether to hide hole cards
    final hideHoleCards = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDecorations.radius20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).handActionsShareHand,
                style: AppTypography.ibm(
                  fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _buildShareOption(
                ctx,
                icon: Icons.visibility,
                label: AppLocalizations.of(context).handActionsShowHoleCards,
                subtitle: AppLocalizations.of(context).handActionsShowHoleCardsSubtitle,
                value: false,
              ),
              const SizedBox(height: 10),
              _buildShareOption(
                ctx,
                icon: Icons.visibility_off,
                label: AppLocalizations.of(context).handActionsHideHoleCards,
                subtitle: AppLocalizations.of(context).handActionsHideHoleCardsSubtitle,
                value: true,
              ),
            ],
          ),
        ),
      ),
    );

    if (hideHoleCards == null || !mounted) return;

    setState(() => _isSharing = true);

    try {
      // Fetch session name
      String? sessionName;
      final sessionId = widget.hand['sessionId'] as String?;
      if (sessionId != null) {
        final session = await FirebaseService.getSession(sessionId);
        sessionName = session?['sessionName'] as String?;
      }

      final url = await HandSharingService.shareHand(
        widget.hand,
        hideHoleCards: hideHoleCards,
        sessionName: sessionName,
      );
      if (url != null && mounted) {
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        await Share.share(
          '${AppLocalizations.of(context).handActionsShareMessage}\n$url',
          subject: AppLocalizations.of(context).handActionsShareSubject('${widget.hand['handNumber']}'),
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context).handActionsFailedToShareHand}: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildShareOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDecorations.radius14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.tealPrimary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.ibm(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.ibm(
                    fontSize: 12, color: Colors.white.withOpacity(0.4),
                  )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  static const int _maxMonthlyExportsPro = 30;
  static const String _exportCountKey = 'monthly_export_count';
  static const String _exportMonthKey = 'monthly_export_month';

  Future<void> _handleExportButtonTap() async {
    // Gate free users at the paywall
    if (!SubscriptionService.isPremium) {
      final purchased = await PaywallScreen.show(context, featureName: 'Hand Export');
      if (purchased != true || !mounted) return;
      if (!SubscriptionService.isPremium) return;
    }

    // Elite/Club: unlimited
    if (SubscriptionService.isElite) {
      if (mounted) _exportPokerStarsFormat();
      return;
    }

    // Pro: monthly quota of 30
    final prefs = await SharedPreferences.getInstance();
    final storedMonth = prefs.getString(_exportMonthKey) ?? '';
    final currentMonth = _currentMonthKey();

    if (storedMonth != currentMonth) {
      await prefs.setString(_exportMonthKey, currentMonth);
      await prefs.setInt(_exportCountKey, 0);
    }

    final int usedCount = prefs.getInt(_exportCountKey) ?? 0;

    if (usedCount >= _maxMonthlyExportsPro) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.infoCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius18)),
          title: Text(
            l10n.quotaExportLimitTitle,
            style: AppTypography.ibm(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.quotaExportLimitPro(_maxMonthlyExportsPro),
            style: AppTypography.ibm(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                PaywallScreen.show(context, featureName: 'Unlimited Exports');
              },
              child: Text(
                l10n.quotaUpgradeToElite,
                style: AppTypography.ibm(
                  color: AppColors.buttonPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l10n.quotaOk,
                style: AppTypography.ibm(
                  color: AppColors.buttonPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    _exportPokerStarsFormat();
    await prefs.setInt(_exportCountKey, usedCount + 1);
  }

  Future<void> _exportPokerStarsFormat() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).handActionsGeneratingExport),
          duration: const Duration(seconds: 2),
        ),
      );

      final sessionId = widget.hand['sessionId'] as String?;
      Map<String, dynamic> sessionData = {};
      if (sessionId != null) {
        final session = await FirebaseService.getSession(sessionId);
        if (session != null) {
          sessionData = session;
        }
      }

      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await PokerStarsExportService.exportAndShare(
        widget.hand,
        sessionData,
        sharePositionOrigin: origin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).handActionsExportedSuccessfully('${widget.hand['handNumber'] ?? 'N/A'}')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).handActionsFailedToExport(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadExistingAnalysis() async {
    try {
      final sessionId = widget.hand['sessionId'] as String?;
      final handId = widget.hand['id'] as String?;

      if (sessionId != null && handId != null) {
        final analysis = await AIAnalyzerService.getAnalysis(
          sessionId: sessionId,
          handId: handId,
        );

        if (analysis != null && mounted) {
          setState(() {
            _aiAnalysis = analysis;
          });
        }
      }
    } catch (e) {
      // Silently fail - analysis will be loaded on demand
    }
  }

  Future<void> _analyzeHand() async {
    // Remote kill-switch (super-admin feature flag) for backend outages.
    if (!FeatureFlagService.isEnabled(FeatureFlagService.aiHandAnalysis)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('AI analysis is temporarily unavailable.')));
      }
      return;
    }
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    if (card1 == null || card2 == null || card1.isEmpty || card2.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDecorations.radius18),
            ),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).handActionsMissingHeroCards,
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              AppLocalizations.of(context).handActionsMissingHeroCardsMessage,
              style: AppTypography.ibm(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTypography.ibm(
                    color: AppColors.tealPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      // Gather opponent stats for Claude analysis
      final opponentContext = await _buildOpponentContext();

      // Use full analysis (GTO + Claude street-by-street)
      final handData = AIAnalyzerService.prepareFullHandData(widget.hand);

      final analysis = await AIAnalyzerService.analyzeHandFull(
        handId: handData['handId'] as String,
        handData: handData,
        opponentContext: opponentContext,
      );

      final sessionId = widget.hand['sessionId'] as String?;
      final handId = widget.hand['id'] as String?;

      if (sessionId != null && handId != null) {
        await AIAnalyzerService.saveAnalysis(
          sessionId: sessionId,
          handId: handId,
          analysis: analysis,
        );
      }

      if (mounted) {
        setState(() {
          _aiAnalysis = analysis;
          _isAnalyzing = false;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Build opponent context map from hand actions for Claude analysis
  Future<Map<String, dynamic>> _buildOpponentContext() async {
    final Map<String, dynamic> context = {};
    final Set<String> processed = {};
    final actions = widget.hand['actions'] as List<dynamic>? ?? [];

    for (final action in actions) {
      final a = action as Map<String, dynamic>;
      final playerName = a['playerName'] as String?;
      final isHero = a['isCurrentUser'] == true;

      if (playerName == null || isHero || playerName == 'Hero') continue;
      if (playerName.startsWith('Player ')) continue;
      if (processed.contains(playerName)) continue;
      processed.add(playerName);

      try {
        final opponent = await OpponentService.findOpponentByName(playerName);
        if (opponent != null) {
          final stats = await OpponentStatsService.getOpponentStats(opponent.id);
          if (stats != null && stats.handsPlayed >= 10) {
            final playStyle = PlayStyleDetector.detectPlayStyle(
              vpip: stats.vpipPercentage,
              pfr: stats.pfrPercentage,
              threeBet: stats.threeBetPercentage,
              aggressionFactor: stats.aggressionFrequency,
              handsPlayed: stats.handsPlayed,
            );
            context[playerName] = {
              'style': playStyle['style'] ?? 'Unknown',
              'vpip': stats.vpipPercentage,
              'pfr': stats.pfrPercentage,
              'threeBet': stats.threeBetPercentage,
              'cbet': stats.cbetPercentage,
              'aggressionFreq': stats.aggressionFrequency,
              'fold3Bet': stats.fold3betPercentage,
              'steal': stats.stealPercentage,
              'hands': stats.handsPlayed,
            };
          }
        }
      } catch (_) {}
    }
    return context;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final heroPositionName = widget.hand['heroPositionName'] as String?;
    final heroSeatNumber = widget.hand['heroSeatNumber'] as int?;
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final rawPlayerCount = (widget.hand['playerCount'] as int?) ?? 6;
    final playerCount = math.max(2, rawPlayerCount);
    final heroPosition = widget.ourSeat ?? heroSeatNumber ?? widget.hand['heroPosition'] ?? 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal radial gradient at top
          Positioned(
            top: -screenWidth * 0.5,
            right: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 1.2,
              height: screenWidth * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A4A4A).withOpacity(0.6),
                    AppColors.headerGradientTeal.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      // Back button — unified top chevron (same as TopNavBar,
                      // no circular background)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SvgPicture.asset(
                              'assets/icons/CaretLeft.svg',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Hand info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).handActionsHandNumber('${widget.hand['handNumber'] ?? 'N/A'}'),
                              style: AppTypography.ibm(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context).handActionsPosition(heroPositionName ?? PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount)),
                              style: AppTypography.ibm(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // BB toggle button
                      GestureDetector(
                        onTap: () => setState(() => _showBB = !_showBB),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _showBB
                                ? AppColors.tealPrimary.withOpacity(0.2)
                                : AppColors.bgElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              'BB',
                              style: AppTypography.mono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _showBB
                                    ? AppColors.tealPrimary
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Export button
                      GestureDetector(
                        onTap: _handleExportButtonTap,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Share button
                      GestureDetector(
                        onTap: _handleShareButtonTap,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            shape: BoxShape.circle,
                          ),
                          child: _isSharing
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.ios_share,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Star button
                      GestureDetector(
                        onTap: _toggleStar,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isStarred
                                ? Colors.amber.withOpacity(0.2)
                                : AppColors.bgElevated,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isStarred ? Icons.star : Icons.star_border,
                            color: _isStarred ? Colors.amber : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tags row
                        if (_tags.isNotEmpty) ...[
                          _buildTagsSection(),
                          const SizedBox(height: 12),
                        ],

                        // Notes section
                        if (_notes != null && _notes!.isNotEmpty) ...[
                          _buildNotesSection(),
                          const SizedBox(height: 12),
                        ],

                        // Hand Summary Stats
                        _buildHandSummaryCards(),

                        const SizedBox(height: 16),

                        // Hero Cards and Winner Info
                        _buildHeroCardsAndWinner(),

                        const SizedBox(height: 16),

                        // Street-by-street action table
                        _buildStreetByStreetTable(),

                        const SizedBox(height: 16),

                        // AI Analyzer Button
                        _buildAIAnalyzerButton(),

                        // AI Analysis Results
                        if (_aiAnalysis != null) ...[
                          const SizedBox(height: 16),
                          _buildAIAnalysisResults(),
                        ],

                        // Analysis Error
                        if (_analysisError != null) ...[
                          const SizedBox(height: 16),
                          _buildAnalysisError(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCardsAndWinner() {
    final ourHoleCardsData = widget.hand['ourHoleCards'];
    final showdownData = widget.hand['showdownData'];
    final playerNamesData = widget.hand['playerNames'];

    String? heroCard1;
    String? heroCard2;
    if (ourHoleCardsData != null && ourHoleCardsData is Map) {
      heroCard1 = ourHoleCardsData['card1'];
      heroCard2 = ourHoleCardsData['card2'];
    }

    Map<int, Map<String, String?>>? opponentCards;
    if (showdownData != null && showdownData is Map) {
      final playerCardsData = showdownData['playerCards'];
      if (playerCardsData != null && playerCardsData is Map) {
        opponentCards = {};
        playerCardsData.forEach((key, value) {
          if (value != null && value is Map) {
            final playerId = int.tryParse(key.toString());
            if (playerId != null) {
              opponentCards![playerId] = {
                'card1': value['card1'] as String?,
                'card2': value['card2'] as String?,
              };
            }
          }
        });
      }
    }

    final bool hasHeroCards = (heroCard1 != null || heroCard2 != null);
    final bool hasOpponentCards = opponentCards != null && opponentCards.isNotEmpty;

    if (!hasHeroCards && !hasOpponentCards) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // Hero Cards
        if (hasHeroCards)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppDecorations.radius18),
                border: Border.all(color: AppColors.tealPrimary.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style, color: AppColors.tealPrimary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context).handActionsYourCards,
                        style: AppTypography.ibm(
                          color: AppColors.tealPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (heroCard1 != null) _buildCard(heroCard1),
                      if (heroCard1 != null && heroCard2 != null) const SizedBox(width: 8),
                      if (heroCard2 != null) _buildCard(heroCard2),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (hasHeroCards && hasOpponentCards)
          const SizedBox(width: 12),

        // Opponent Cards
        if (hasOpponentCards)
          Expanded(
            child: _buildOpponentCardsCard(opponentCards!, playerNamesData),
          ),
      ],
    );
  }

  Widget _buildOpponentCardsCard(Map<int, Map<String, String?>> opponentCards, dynamic playerNamesData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Color(0xFF8B5CF6), size: 16),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).handActionsOpponentCards,
                style: AppTypography.ibm(
                  color: const Color(0xFF8B5CF6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...opponentCards.entries.map((entry) {
            final playerId = entry.key;
            final cards = entry.value;
            final card1 = cards['card1'];
            final card2 = cards['card2'];

            if (card1 == null || card2 == null) {
              return const SizedBox.shrink();
            }

            String? playerName;
            if (playerNamesData != null && playerNamesData is Map) {
              playerName = playerNamesData[playerId.toString()];
            }
            playerName ??= AppLocalizations.of(context).handActionsPlayerSeat(playerId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      playerName,
                      style: AppTypography.ibm(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSmallCard(card1),
                  const SizedBox(width: 4),
                  _buildSmallCard(card2),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSmallCard(String card) {
    return Container(
      width: 24,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          card,
          style: TextStyle(
            color: _getCardColor(card),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHandSummaryCards() {
    final pot = widget.hand['potAmount'] ?? widget.hand['pot'] ?? 0;
    final smallBlind = widget.hand['smallBlind'] ?? 1;
    final bigBlind = widget.hand['bigBlind'] ?? 2;
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    final gameType = GameTypeExtension.fromString(gameTypeStr);

    final String potText;
    if (_showBB) {
      potText = _formatBB((pot as num).toDouble());
    } else if (gameType == GameType.cash) {
      potText = formatCompactCurrency(pot);
    } else {
      potText = formatCompactNumber(pot);
    }
    final String blindsText = gameType == GameType.cash
        ? '${formatCompactCurrency(smallBlind)}/${formatCompactCurrency(bigBlind)}'
        : '${formatCompactNumber(smallBlind)}/${formatCompactNumber(bigBlind)}';
    String? winnerText = _getWinnerText();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCompactStat(AppLocalizations.of(context).handActionsPot, potText)),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1)),
          Expanded(child: _buildCompactStat(AppLocalizations.of(context).handActionsBlinds, blindsText)),
          if (winnerText != null) ...[
            Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1)),
            Expanded(child: _buildCompactStat(AppLocalizations.of(context).handActionsWinner, winnerText, isWinner: true)),
          ],
        ],
      ),
    );
  }

  String? _getWinnerText() {
    final isChoppedPot = widget.hand['isChoppedPot'] == true;
    final winnerId = widget.hand['winnerId'];
    final choppedWinners = widget.hand['choppedWinners'] as List<dynamic>?;
    final playerNamesData = widget.hand['playerNames'];

    if (isChoppedPot && choppedWinners != null && choppedWinners.isNotEmpty) {
      // B11: split pots (winners of separate side pots) show every winner —
      // never collapse to a count — so a side-pot winner is never hidden.
      final isSplitPot = widget.hand['isSplitPot'] == true;
      String nameOf(dynamic w) {
        if (playerNamesData is Map) {
          return (playerNamesData[w.toString()] ?? 'P$w') as String;
        }
        return 'P$w';
      }

      if (isSplitPot || choppedWinners.length <= 2) {
        return choppedWinners.map(nameOf).join(', ');
      }
      return AppLocalizations.of(context).handActionsPlayersCount(choppedWinners.length);
    } else if (winnerId != null) {
      if (playerNamesData is Map) {
        return playerNamesData[winnerId.toString()] ?? 'P$winnerId';
      }
      return 'P$winnerId';
    }
    return null;
  }

  Widget _buildCompactStat(String label, String value, {bool isWinner = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.ibm(
            color: isWinner ? const Color(0xFFFFD700) : AppColors.tealPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.ibm(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _tags.map((tag) => _buildTagBadge(tag)).toList(),
    );
  }

  Widget _buildTagBadge(String tag) {
    IconData tagIcon;
    switch (tag) {
      case 'Bluff':
        tagIcon = Icons.psychology;
        break;
      case 'Value':
        tagIcon = Icons.attach_money;
        break;
      case 'Mistake':
        tagIcon = Icons.error_outline;
        break;
      case 'Cooler':
        tagIcon = Icons.ac_unit;
        break;
      case 'Hero Call':
        tagIcon = Icons.shield;
        break;
      case 'Exploit':
        tagIcon = Icons.gps_fixed;
        break;
      default:
        tagIcon = Icons.label;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tealPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(
          color: AppColors.tealPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tagIcon,
            size: 14,
            color: AppColors.tealPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            tag,
            style: AppTypography.ibm(
              fontSize: 13,
              color: AppColors.tealPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: Colors.white.withOpacity(0.5), size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).handActionsNotes,
                style: AppTypography.ibm(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _notes!,
            style: AppTypography.ibm(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreetByStreetTable() {
    final actions = List<Map<String, dynamic>>.from(widget.hand['actions'] ?? []);
    final boardCardsData = widget.hand['boardCards'];
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final rawPlayerCount = (widget.hand['playerCount'] as int?) ?? 6;
    final playerCount = math.max(2, rawPlayerCount);
    final heroPosition = widget.ourSeat ?? widget.hand['heroPosition'];
    final playerNamesData = widget.hand['playerNames'];
    final winnerId = widget.hand['winnerId'];
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    final gameType = GameTypeExtension.fromString(gameTypeStr);

    Map<String, String> playerNamesMap = {};
    if (playerNamesData != null && playerNamesData is Map) {
      playerNamesData.forEach((key, value) {
        playerNamesMap[key.toString()] = value.toString();
      });
    }

    List<String> flop = [];
    String? turn;
    String? river;
    if (boardCardsData != null && boardCardsData is Map) {
      flop = List<String>.from(boardCardsData['flop'] ?? []);
      turn = boardCardsData['turn'] as String?;
      river = boardCardsData['river'] as String?;
    }

    Map<String, List<Map<String, dynamic>>> actionsByStreet = {
      'preflop': [],
      'flop': [],
      'turn': [],
      'river': [],
    };

    for (final action in actions) {
      final street = action['street'] as String? ?? 'preflop';
      actionsByStreet[street]?.add(action);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).handActionsActionSummary,
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        // Preflop
        if (actionsByStreet['preflop']!.isNotEmpty)
          _buildStreetSection(AppLocalizations.of(context).handActionsPreflop, null, actionsByStreet['preflop']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['preflopPot']),

        _buildPostflopSections(widget.hand, flop, turn, river, actionsByStreet,
            buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType),
      ],
    );
  }

  Widget _buildStreetSection(String streetName, List<String>? cards, List<Map<String, dynamic>> actions,
      int buttonPosition, int playerCount, int? heroPosition,
      Map<String, String> playerNamesMap, int? winnerId, String gameType, dynamic potAmount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Street header with cards
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDecorations.radius18),
                topRight: Radius.circular(AppDecorations.radius18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      streetName,
                      style: AppTypography.ibm(
                        color: AppColors.tealPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (cards != null && cards.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ...cards.map((card) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildCard(card),
                      )),
                    ],
                  ],
                ),
                // Pot amount
                if (potAmount != null && (potAmount as double) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tealPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDecorations.radius10),
                      border: Border.all(color: AppColors.tealPrimary.withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatPotAmount(potAmount as double, gameType),
                      style: AppTypography.ibm(
                        color: AppColors.tealPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action table
          _buildActionTable(actions, buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType),
        ],
      ),
    );
  }

  Widget _buildActionTable(List<Map<String, dynamic>> actions, int buttonPosition, int playerCount,
      int? heroPosition, Map<String, String> playerNamesMap, int? winnerId, String gameType) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            children: [
              _buildTableHeader(AppLocalizations.of(context).handActionsPlayer),
              _buildTableHeader(AppLocalizations.of(context).handActionsStack),
              _buildTableHeader(AppLocalizations.of(context).handActionsAction),
              _buildTableHeader(AppLocalizations.of(context).handActionsAmount),
            ],
          ),
          ...actions.map((action) => _buildActionRow(
              action, buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType
          )),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.ibm(
          color: Colors.white.withOpacity(0.4),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  bool _isAllInAction(Map<String, dynamic> action) {
    final actionType = action['action'] as String?;
    final amount = action['amount'];
    final playerStack = action['playerStack'] ?? action['stack'];

    if (actionType == null || (actionType.toLowerCase() != 'raise' && actionType.toLowerCase() != 'bet')) {
      return false;
    }

    if (amount == null || playerStack == null) return false;

    final betAmount = (amount as num).toDouble();
    final stack = (playerStack as num).toDouble();

    return betAmount >= (stack - 0.01);
  }

  bool _isAllInSituation(Map<String, dynamic> hand) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    return actions.any((action) => _isAllInAction(action));
  }

  bool _hasPostflopActions(Map<String, dynamic> hand) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    return actions.any((action) =>
        action['street'] != null &&
            action['street'].toString().toLowerCase() != 'preflop'
    );
  }

  Widget _buildPostflopSections(
      Map<String, dynamic> hand,
      List<String> flop,
      String? turn,
      String? river,
      Map<String, List<Map<String, dynamic>>> actionsByStreet,
      int buttonPosition,
      int playerCount,
      int? heroPosition,
      Map<String, String> playerNamesMap,
      int? winnerId,
      GameType gameType,
      ) {
    final hasPostflopActions = _hasPostflopActions(hand);
    final isAllInSituation = _isAllInSituation(hand);

    if (isAllInSituation && !hasPostflopActions) {
      return _buildCombinedBoardSection(flop, turn, river, gameType);
    } else {
      return _buildStreetByStreetSections(
          flop, turn, river, actionsByStreet,
          buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType
      );
    }
  }

  Widget _buildCombinedBoardSection(List<String> flop, String? turn, String? river, GameType gameType) {
    final allCards = <String>[];
    allCards.addAll(flop);
    if (turn != null && turn.isNotEmpty) allCards.add(turn);
    if (river != null && river.isNotEmpty) allCards.add(river);

    if (allCards.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDecorations.radius18),
                topRight: Radius.circular(AppDecorations.radius18),
              ),
            ),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context).handActionsBoard,
                  style: AppTypography.ibm(
                    color: AppColors.tealPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: allCards.map((card) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  card,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getCardColor(card),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreetByStreetSections(
      List<String> flop,
      String? turn,
      String? river,
      Map<String, List<Map<String, dynamic>>> actionsByStreet,
      int buttonPosition,
      int playerCount,
      int? heroPosition,
      Map<String, String> playerNamesMap,
      int? winnerId,
      GameType gameType,
      ) {
    return Column(
      children: [
        if (flop.isNotEmpty)
          _buildStreetSection('FLOP', flop, actionsByStreet['flop']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['flopPot']),

        if (turn != null && turn.isNotEmpty)
          _buildStreetSection('TURN', [turn], actionsByStreet['turn']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['turnPot']),

        if (river != null && river.isNotEmpty)
          _buildStreetSection('RIVER', [river], actionsByStreet['river']!,
              buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['riverPot']),
      ],
    );
  }

  TableRow _buildActionRow(Map<String, dynamic> action, int buttonPosition, int playerCount,
      int? heroPosition, Map<String, String> playerNamesMap, int? winnerId, String gameType) {
    final playerSeat = action['player'] as int? ?? action['playerSeat'] as int? ?? 1;
    final actionType = action['action'] as String? ?? 'Unknown';
    final amount = action['amount'];
    final stack = action['playerStack'] ?? action['stack'] ?? 0;

    String playerName = playerNamesMap[playerSeat.toString()] ??
        action['playerName'] as String? ??
        AppLocalizations.of(context).handActionsPlayerSeat(playerSeat);

    final isHero = heroPosition != null && playerSeat == heroPosition;
    final isWinner = winnerId != null && playerSeat == winnerId;
    final positionName = action['playerPosition'] as String? ??
        PokerPositions.getPositionName(playerSeat, buttonPosition, playerCount);

    String playerDisplay = isHero ? AppLocalizations.of(context).handActionsYou : playerName;
    playerDisplay = '$playerDisplay ($positionName)';

    Color actionColor = Colors.white.withOpacity(0.5);
    switch (actionType.toLowerCase()) {
      case 'fold':
        actionColor = Colors.red;
        break;
      case 'call':
      case 'check':
        actionColor = AppColors.tealPrimary;
        break;
      case 'raise':
      case 'bet':
        actionColor = const Color(0xFFFF9500);
        break;
      case 'all in':
      case 'allin':
        actionColor = Colors.red;
        break;
    }

    return TableRow(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              if (isWinner)
                const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 12),
              if (isWinner) const SizedBox(width: 3),
              Expanded(
                child: Text(
                  playerDisplay,
                  style: AppTypography.ibm(
                    color: isHero ? AppColors.tealPrimary : Colors.white,
                    fontSize: 11,
                    fontWeight: isHero ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _formatStack(stack, gameType),
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _isAllInAction(action) ? AppLocalizations.of(context).handActionsAllIn : actionType.toUpperCase(),
            style: AppTypography.ibm(
              color: actionColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _formatAmount(amount, gameType),
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String? card) {
    if (card == null || card.isEmpty) return const SizedBox.shrink();

    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';

    Color suitColor = Colors.white;
    if (suit == '♥' || suit == '♦') suitColor = Colors.red;

    return Container(
      width: 30,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rank,
            style: TextStyle(
              color: suitColor == Colors.red ? Colors.red : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            suit,
            style: TextStyle(
              color: suitColor == Colors.red ? Colors.red : Colors.black,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBB(double value) {
    final bb = (widget.hand['bigBlind'] as num?)?.toDouble() ?? 2.0;
    final bbValue = value / bb;
    if (bbValue == bbValue.roundToDouble()) {
      return '${bbValue.toInt()}BB';
    }
    return '${bbValue.toStringAsFixed(1)}BB';
  }

  String _formatPotAmount(double amount, String gameType) {
    if (amount <= 0) return '';

    final l10n = AppLocalizations.of(context);

    if (_showBB) return l10n.handActionsPotAmount(_formatBB(amount));

    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return l10n.handActionsPotAmount(CurrencyService.formatCash(amount));
    } else {
      return l10n.handActionsPotAmount('${amount.toInt()}');
    }
  }

  String _formatStack(dynamic stack, String gameType) {
    if (stack == null || (stack is num && stack <= 0)) return '-';

    final stackNum = (stack is num) ? stack.toDouble() : 0.0;

    if (_showBB) return _formatBB(stackNum);

    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return formatCompactCurrency(stackNum);
    } else {
      return formatCompactNumber(stackNum);
    }
  }

  String _formatAmount(dynamic amount, String gameType) {
    if (amount == null) return '-';

    final amountNum = (amount is num) ? amount.toDouble() : 0.0;
    if (amountNum <= 0) return '-';

    if (_showBB) return _formatBB(amountNum);

    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return formatCompactCurrency(amountNum);
    } else {
      return formatCompactNumber(amountNum);
    }
  }

  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  Widget _buildAIAnalyzerButton() {
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;
    final hasHeroCards = card1 != null && card2 != null && card1.isNotEmpty && card2.isNotEmpty;

    Color buttonColor;
    Color textColor;
    if (!hasHeroCards) {
      buttonColor = Colors.white.withOpacity(0.1);
      textColor = Colors.white.withOpacity(0.3);
    } else if (_aiAnalysis != null) {
      buttonColor = Colors.white.withOpacity(0.1);
      textColor = Colors.white.withOpacity(0.4);
    } else {
      buttonColor = AppColors.tealPrimary;
      textColor = Colors.black;
    }

    return GestureDetector(
      onTap: (_isAnalyzing || !hasHeroCards || _aiAnalysis != null) ? null : () => _handleAnalyzeButtonTap(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnalyzing) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).handActionsAnalyzingHand,
                style: AppTypography.ibm(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (!hasHeroCards) ...[
              Icon(Icons.block, color: textColor),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).handActionsHeroCardsMissing,
                style: AppTypography.ibm(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              Icon(
                _aiAnalysis != null ? Icons.check_circle_outline : Icons.psychology,
                color: textColor,
              ),
              const SizedBox(width: 12),
              Text(
                _aiAnalysis != null ? AppLocalizations.of(context).handActionsAnalysisComplete : AppLocalizations.of(context).handActionsAiAnalyzerBeta,
                style: AppTypography.ibm(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const int _maxMonthlyAnalysesPro = 10;
  static const int _maxMonthlyAnalysesElite = 30;
  static const String _analysisCountKeyPro = 'monthly_ai_analysis_count_pro';
  static const String _analysisCountKeyElite = 'monthly_ai_analysis_count_elite';
  static const String _analysisMonthKey = 'monthly_ai_analysis_month';

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}';
  }

  Future<void> _handleAnalyzeButtonTap() async {
    // Gate free users at the paywall — AI analysis requires at least Pro
    if (!SubscriptionService.isPremium) {
      final purchased = await PaywallScreen.show(context, featureName: 'AI Hand Analysis');
      if (purchased != true || !mounted) return;
      // Re-check after purchase
      if (!SubscriptionService.isPremium) return;
    }

    // Club tier: unlimited — no quota check
    if (SubscriptionService.isClub) {
      _analyzeHand();
      return;
    }

    // Admin users bypass quota
    bool isAdmin = false;
    final uid = AuthService.userId;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        isAdmin = doc.data()?['role'] == 'admin';
      } catch (_) {}
    }
    if (isAdmin) {
      _analyzeHand();
      return;
    }

    // Determine per-tier quota
    final bool isElite = SubscriptionService.isElite;
    final String countKey = isElite ? _analysisCountKeyElite : _analysisCountKeyPro;
    final int maxAllowed = isElite ? _maxMonthlyAnalysesElite : _maxMonthlyAnalysesPro;

    final prefs = await SharedPreferences.getInstance();
    final storedMonth = prefs.getString(_analysisMonthKey) ?? '';
    final currentMonth = _currentMonthKey();

    // Reset both counters on month boundary
    if (storedMonth != currentMonth) {
      await prefs.setString(_analysisMonthKey, currentMonth);
      await prefs.setInt(_analysisCountKeyPro, 0);
      await prefs.setInt(_analysisCountKeyElite, 0);
    }

    final int usedCount = prefs.getInt(countKey) ?? 0;

    if (usedCount >= maxAllowed) {
      if (mounted) {
        _showAnalysisQuotaDialog(usedCount, maxAllowed, isElite);
      }
      return;
    }

    _analyzeHand();
    await prefs.setInt(countKey, usedCount + 1);
  }

  void _showAnalysisQuotaDialog(int used, int max, bool isElite) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.infoCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius18)),
        title: Text(
          l10n.quotaMonthlyLimitTitle,
          style: AppTypography.ibm(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isElite
              ? l10n.quotaAiLimitElite(max)
              : l10n.quotaAiLimitPro(max, _maxMonthlyAnalysesElite),
          style: AppTypography.ibm(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          if (!isElite)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                PaywallScreen.show(context, featureName: 'More AI Analyses');
              },
              child: Text(
                l10n.quotaUpgradeToElite,
                style: AppTypography.ibm(
                  color: AppColors.buttonPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.quotaOk,
              style: AppTypography.ibm(
                color: AppColors.buttonPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).handActionsAnalysisFailed,
                  style: AppTypography.ibm(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _analysisError ?? 'Unknown error',
                  style: AppTypography.ibm(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisResults() {
    if (_aiAnalysis == null) return const SizedBox.shrink();

    final aiAnalysis = _aiAnalysis!['aiAnalysis'] as Map<String, dynamic>?;
    final streetBreakdown = _aiAnalysis!['streetBreakdown'] as Map<String, dynamic>?;
    final exploitativeTip = _aiAnalysis!['exploitativeTip'] as String?;
    final hasStreetBreakdown = streetBreakdown != null && streetBreakdown.isNotEmpty;
    final processingTime = _aiAnalysis!['processingTimeMs'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Analysis
        if (aiAnalysis != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppDecorations.radius18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: AppColors.tealPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).handActionsAiAnalysis,
                      style: AppTypography.ibm(
                        color: AppColors.tealPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (aiAnalysis['reasoning'] != null) ...[
                  Text(
                    aiAnalysis['reasoning'],
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (aiAnalysis['learningPoint'] != null &&
                    (aiAnalysis['learningPoint'] as String).isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            aiAnalysis['learningPoint'],
                            style: AppTypography.ibm(
                              color: const Color(0xFFFFD700),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Street-by-street breakdown (from Claude)
        if (hasStreetBreakdown) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppDecorations.radius18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: AppColors.limeGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).handActionsStreetByStreetBreakdown,
                      style: AppTypography.ibm(
                        color: AppColors.limeGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...['preflop', 'flop', 'turn', 'river']
                    .where((s) => streetBreakdown!.containsKey(s))
                    .map((streetName) {
                  final street = streetBreakdown![streetName] as Map<String, dynamic>? ?? {};
                  final analysis = street['analysis'] as String? ?? '';
                  final grade = street['grade'] as String? ?? 'C';
                  return _buildStreetGradeRow(streetName, analysis, grade);
                }),
                // Exploitative tip
                if (exploitativeTip != null && exploitativeTip!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppDecorations.radius10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person_search,
                            color: Color(0xFFFFD700), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exploitativeTip!,
                            style: AppTypography.ibm(
                              fontSize: 13,
                              color: const Color(0xFFFFD700),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Processing Time
        const SizedBox(height: 12),
        Center(
          child: Text(
            AppLocalizations.of(context).handActionsAnalysisCompletedIn((processingTime / 1000).toStringAsFixed(2)),
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreetGradeRow(String streetName, String analysis, String grade) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _gradeColor(grade).withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            ),
            child: Center(
              child: Text(
                grade,
                style: AppTypography.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _gradeColor(grade),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streetName[0].toUpperCase() + streetName.substring(1),
                  style: AppTypography.ibm(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  analysis,
                  style: AppTypography.ibm(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A': return const Color(0xFF54E98A);
      case 'B': return AppColors.tealPrimary;
      case 'C': return const Color(0xFFFFD700);
      case 'D': return Colors.orange;
      case 'F': return Colors.red;
      default: return Colors.white.withOpacity(0.5);
    }
  }

}
