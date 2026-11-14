import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../utils/poker_positions.dart';
import '../models/hand_completeness.dart';
import '../services/ai_analyzer_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/partner_grant_service.dart';
import '../services/subscription_service.dart';
import '../services/pokerstars_export_service.dart';
import '../services/hand_sharing_service.dart';
import '../services/hand_display_prefs.dart';
import '../services/opponent_service.dart';
import '../services/play_style_detector.dart';
import 'package:share_plus/share_plus.dart';
import '../services/opponent_stats_service.dart';
import '../l10n/app_localizations.dart';
import 'paywall_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/feature_flag_service.dart';
import '../design_system/components/app_toggle.dart';
import '../design_system/components/bodies/message_body.dart';
import '../design_system/components/buttons/app_button.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/components/headers/section_header.dart';
import '../design_system/components/buttons/back_button_circle.dart';
import '../design_system/components/form_drawer.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_prefs.dart';
import '../widgets/hand_details/hand_ai_analysis_card.dart';
import '../widgets/hand_details/hand_street_section.dart';
import '../widgets/hand_details/hand_summary_card.dart';
import '../widgets/hand_details/hand_tools_strip.dart';
import '../services/currency_service.dart';
import '../widgets/hand_details/hand_view_data.dart';

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

  // Phase-6 onboarding: spotlights for the tools row + AI analysis button
  final GlobalKey _aiButtonKey = GlobalKey();
  final GlobalKey _toolsRowKey = GlobalKey();

  // Star, tags, and display state
  late bool _isStarred;
  bool _showBB = HandDisplayPrefs.showBB;
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
    _loadShowBB();
    _loadExistingAnalysis();
    _scheduleOnboardingTour();
  }

  /// First-ever load only: later screens start with the cached value.
  Future<void> _loadShowBB() async {
    final v = await HandDisplayPrefs.load();
    if (mounted && v != _showBB) setState(() => _showBB = v);
  }

  /// Phase 6 — after the hand-card handoff: explain the hand tools (BB /
  /// export / share / star) all at once, then scroll to and spotlight the AI
  /// analysis button, run the free analysis, and wrap up the tour.
  void _scheduleOnboardingTour() async {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 6 ||
        !OnboardingState.aiAnalysisTourPending) return;
    OnboardingState.aiAnalysisTourPending = false;

    // The tools strip sits in the summary card at the top of the scroll view.
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (_toolsRowKey.currentContext != null) break;
    }
    if (!mounted) return;

    if (_toolsRowKey.currentContext != null) {
      await Scrollable.ensureVisible(
        _toolsRowKey.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
      );
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      HandToolsTour(toolsRowKey: _toolsRowKey)
          .show(context, onNext: _showAiAnalysisStep);
    } else {
      _showAiAnalysisStep();
    }
  }

  /// Scrolls the AI analysis button into view (it lives below the fold), then
  /// spotlights it. Fixes the coach-mark card being hidden off-screen.
  Future<void> _showAiAnalysisStep() async {
    // Give the AI button a chance to attach, scroll it to centre so the
    // spotlight card isn't clipped at the bottom of the screen.
    for (int i = 0; i < 20; i++) {
      if (!mounted) return;
      if (_aiButtonKey.currentContext != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    if (_aiButtonKey.currentContext == null) {
      // No spotlight possible — defer completion to when the user leaves.
      OnboardingState.tourCompletionPending = true;
      return;
    }

    await Scrollable.ensureVisible(
      _aiButtonKey.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    // Let the scroll settle before the coach mark measures the target.
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    AiAnalysisTour(aiButtonKey: _aiButtonKey)
        .show(context, onAnalyze: _runTourAnalysis);
  }

  Future<void> _runTourAnalysis() async {
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;
    final hasHeroCards =
        card1 != null && card2 != null && card1.isNotEmpty && card2.isNotEmpty;

    // Mark the tour as pending completion up front: don't finish here (let the
    // user read the analysis) — the completion dialog fires only
    // once they LEAVE this screen (SessionHandsScreen runs finishOnboardingTour
    // on return). Setting it before the await means leaving mid-analysis still
    // triggers completion.
    OnboardingState.tourCompletionPending = true;

    if (hasHeroCards && _aiAnalysis == null && !_isAnalyzing) {
      await _handleAnalyzeButtonTap();
    }
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
            backgroundColor: AppColors.accentDanger,
          ),
        );
      }
    }
  }

  Future<void> _handleShareButtonTap() async {
    if (_isSharing) return;
    final l10n = AppLocalizations.of(context);

    // Standard drawer with a single "Show hole cards" toggle; the checkmark
    // confirms and shares, closing without it cancels.
    bool showCards = true;
    final confirmed = await FormDrawer.show<bool>(
      context: context,
      title: l10n.handActionsShareHand,
      heightFraction: null, // hug content — single toggle row
      scrollable: false,
      onSave: () => Navigator.of(context).pop(true),
      body: StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppDecorations.radius14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(
                showCards ? Icons.visibility : Icons.visibility_off,
                color: AppColors.accentPrimary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.handActionsShowHoleCards,
                      style: AppTypography.ibm(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showCards
                          ? l10n.handActionsShowHoleCardsSubtitle
                          : l10n.handActionsHideHoleCardsSubtitle,
                      style: AppTypography.ibm(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              AppToggle(
                value: showCards,
                onChanged: (v) => setSheetState(() => showCards = v),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final hideHoleCards = !showCards;

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
            content: Text('${AppLocalizations.of(context).handActionsFailedToShareHand}: ${UserFacingError.message(e)}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
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
      AppDialog.show<void>(
        context,
        title: l10n.quotaExportLimitTitle,
        body: MessageBody(l10n.quotaExportLimitPro(_maxMonthlyExportsPro)),
        actions: DialogActionBar(
          confirmLabel: l10n.quotaUpgradeToElite,
          cancelLabel: l10n.quotaOk,
          onConfirm: () =>
              PaywallScreen.show(context, featureName: 'Unlimited Exports'),
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
            backgroundColor: AppColors.profitGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).handActionsFailedToExport(UserFacingError.message(e))),
            backgroundColor: AppColors.accentDanger,
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

  /// Returns true only when a valid analysis was obtained and saved.
  Future<bool> _analyzeHand() async {
    // Remote kill-switch (super-admin feature flag) for backend outages.
    if (!FeatureFlagService.isEnabled(FeatureFlagService.aiHandAnalysis)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('AI analysis is temporarily unavailable.')));
      }
      return false;
    }
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    if (card1 == null || card2 == null || card1.isEmpty || card2.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppDialog.show<void>(
          context,
          title: l10n.handActionsMissingHeroCards,
          body: MessageBody(l10n.handActionsMissingHeroCardsMessage),
          actions: DialogActionBar.single(cancelLabel: l10n.quotaOk),
        );
      }
      return false;
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
      return true;
    } on AiAnalysisUnavailableException {
      if (mounted) {
        setState(() {
          _analysisError =
              AppLocalizations.of(context).handActionsAnalysisUnavailable;
          _isAnalyzing = false;
        });
      }
      return false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = UserFacingError.message(e);
          _isAnalyzing = false;
        });
      }
      return false;
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
    final l10n = AppLocalizations.of(context);
    final data = HandViewData.from(widget.hand,
        ourSeat: widget.ourSeat, showBB: _showBB);
    final heroSeatNumber = widget.hand['heroSeatNumber'] as int?;
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final rawPlayerCount = (widget.hand['playerCount'] as int?) ?? 6;
    final playerCount = math.max(2, rawPlayerCount);
    final heroSeat =
        widget.ourSeat ?? heroSeatNumber ?? widget.hand['heroPosition'] ?? 1;
    final positionName = (widget.hand['heroPositionName'] as String?) ??
        PokerPositions.getPositionName(heroSeat, buttonPosition, playerCount);
    final title =
        l10n.handActionsHandNumber('${widget.hand['handNumber'] ?? 'N/A'}');
    final subtitle = [
      positionName,
      HandSummaryCard.blindsText(
          widget.hand, data.formatter, data.formatter.isCash),
      data.formatter.isCash ? l10n.statsCash : l10n.statsTournament,
    ].where((e) => e.toString().isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(title, subtitle),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HandSummaryCard(
                        data: data, footer: _buildToolsStrip(data)),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTagsSection(),
                    ],
                    if (_notes != null && _notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildNotesSection(),
                    ],
                    if (data.streets.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SectionHeader(title: l10n.handActionsAction),
                      const SizedBox(height: 12),
                      for (final block in data.streets)
                        HandStreetSection(block: block, data: data),
                    ],
                    const SizedBox(height: 8),
                    if (_completeness == HandCompleteness.reconstructed) ...[
                      _buildReconstructedBadge(),
                      const SizedBox(height: 8),
                    ],
                    // AI analysis is for fully logged hands only.
                    if (_completeness.isAnalyzable) _buildAIAnalyzerButton(),
                    if (_aiAnalysis != null) ...[
                      const SizedBox(height: 24),
                      HandAiAnalysisCard(analysis: _aiAnalysis!),
                    ],
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
    );
  }

  /// Back | title block (Hand #N + subtitle) | star. One aligned row; the
  /// display/export/share tools live on the summary card's footer.
  Widget _buildHeader(String title, String subtitle) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: BackButtonCircle(onPressed: () => Navigator.pop(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleBase().copyWith(fontSize: 21),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.ibm(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            tooltip:
                _isStarred ? l10n.handActionsUnstarHand : l10n.handActionsStarHand,
            selected: _isStarred,
            selectedColor: AppColors.accentTertiary,
            onTap: _toggleStar,
            child: Icon(
              _isStarred ? Icons.star : Icons.star_border,
              color:
                  _isStarred ? AppColors.accentTertiary : AppColors.textPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  /// BB/currency switch + export + share, attached to the summary card.
  /// The Container gives TutorialCoachMark a full bounding box to spotlight.
  Widget _buildToolsStrip(HandViewData data) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: _toolsRowKey,
      child: HandToolsStrip(
        showBB: _showBB,
        onShowBBChanged: (v) {
          setState(() => _showBB = v);
          HandDisplayPrefs.setShowBB(v);
        },
        amountLabel:
            data.formatter.isCash ? CurrencyService.symbol : l10n.handActionsUnitChips,
        onExport: _handleExportButtonTap,
        onShare: _handleShareButtonTap,
        isSharing: _isSharing,
      ),
    );
  }

  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map(_buildTagBadge).toList(),
    );
  }

  Widget _buildTagBadge(String tag) {
    const icons = {
      'Bluff': Icons.psychology,
      'Value': Icons.attach_money,
      'Mistake': Icons.error_outline,
      'Cooler': Icons.ac_unit,
      'Hero Call': Icons.shield,
      'Exploit': Icons.gps_fixed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border:
            Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[tag] ?? Icons.label,
              size: 16, color: AppColors.accentPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tag,
              style: AppTypography.ibm(
                fontSize: 14,
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).handActionsNotes,
              style: AppTypography.caption()),
          const SizedBox(height: 6),
          Text(
            _notes!,
            style: AppTypography.ibm(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  HandCompleteness get _completeness =>
      HandCompletenessX.fromHandMap(widget.hand);

  Widget _buildReconstructedBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxxs),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          border: Border.all(color: AppColors.accentPrimary),
        ),
        child: Text(
          AppLocalizations.of(context).easyLogReconstructedBadge,
          style: AppTypography.caption(),
        ),
      ),
    );
  }

  Widget _buildAIAnalyzerButton() {
    final l10n = AppLocalizations.of(context);
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;
    final hasHeroCards =
        card1 != null && card2 != null && card1.isNotEmpty && card2.isNotEmpty;

    final String label;
    final Widget icon;
    final AppButtonVariant variant;
    if (_isAnalyzing) {
      label = l10n.handActionsAnalyzingHand;
      variant = AppButtonVariant.secondaryLarge;
      icon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.textPrimary),
      );
    } else if (!hasHeroCards) {
      label = l10n.handActionsHeroCardsMissing;
      variant = AppButtonVariant.secondaryLarge;
      icon = const Icon(Icons.block, color: AppColors.textPrimary, size: 20);
    } else if (_aiAnalysis != null) {
      label = l10n.handActionsAnalysisComplete;
      variant = AppButtonVariant.ghost;
      icon = const Icon(Icons.check_circle_outline,
          color: AppColors.accentPrimary, size: 20);
    } else {
      label = l10n.handActionsAiAnalyzerBeta;
      variant = AppButtonVariant.secondaryLarge;
      icon = SvgPicture.asset(
        'icons/figma_icons/sparkle.svg',
        width: 20,
        height: 20,
        colorFilter:
            const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
      );
    }
    final enabled = !_isAnalyzing && hasHeroCards && _aiAnalysis == null;

    // The keyed box is the tour's spotlight target for the AI step.
    return SizedBox(
      key: _aiButtonKey,
      width: double.infinity,
      child: AppButton(
        label: label,
        variant: variant,
        fullWidth: true,
        leadingIcon: icon,
        onTap: enabled ? _handleAnalyzeButtonTap : null,
      ),
    );
  }

  Widget _buildAnalysisError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
        border:
            Border.all(color: AppColors.accentDanger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.accentDanger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).handActionsAnalysisFailed,
                  style: AppTypography.ibm(
                    color: AppColors.accentDanger,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _analysisError ?? 'Unknown error',
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const int _maxMonthlyAnalysesPro = 20;
  static const int _maxMonthlyAnalysesElite = 50;
  static const String _analysisCountKeyPro = 'monthly_ai_analysis_count_pro';
  static const String _analysisCountKeyElite = 'monthly_ai_analysis_count_elite';
  static const String _analysisMonthKey = 'monthly_ai_analysis_month';

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}';
  }

  Future<void> _handleAnalyzeButtonTap() async {
    // One free analysis for non-premium users — the tour's taste of the
    // premium feature. Consumed only on success; persisted on the user doc
    // so it survives reinstall and account linking.
    if (!SubscriptionService.isPremium &&
        await OnboardingPrefs.canUseTourAnalysis()) {
      if (!mounted) return;
      await _analyzeHand();
      if (_aiAnalysis != null) {
        await OnboardingPrefs.markTourAnalysisUsed();
      }
      return;
    }
    if (!mounted) return;

    // Gate free users at the paywall — AI analysis requires at least Pro
    if (!SubscriptionService.isPremium) {
      final purchased = await PaywallScreen.show(context, featureName: 'AI Hand Analysis');
      if (purchased != true || !mounted) return;
      // Re-check after purchase
      if (!SubscriptionService.isPremium) return;
    }

    // Club tier: unlimited — no quota check
    if (SubscriptionService.isClub) {
      await _analyzeHand();
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
      await _analyzeHand();
      return;
    }

    // Partner grant custom AI quota
    final partnerQuota = PartnerGrantService.partnerAiQuota;
    if (partnerQuota != null) {
      if (partnerQuota == -1) {
        await _analyzeHand();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final storedMonth = prefs.getString(_analysisMonthKey) ?? '';
      final currentMonth = _currentMonthKey();
      const partnerCountKey = 'monthly_ai_analysis_count_partner';
      if (storedMonth != currentMonth) {
        await prefs.setString(_analysisMonthKey, currentMonth);
        await prefs.setInt(partnerCountKey, 0);
        await prefs.setInt(_analysisCountKeyPro, 0);
        await prefs.setInt(_analysisCountKeyElite, 0);
      }
      final used = prefs.getInt(partnerCountKey) ?? 0;
      if (used >= partnerQuota) {
        if (mounted) _showAnalysisQuotaDialog(used, partnerQuota, true);
        return;
      }
      // Count only a valid analysis (never the backend fallback / errors).
      if (await _analyzeHand()) await prefs.setInt(partnerCountKey, used + 1);
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

    // Count only a valid analysis (never the backend fallback / errors).
    if (await _analyzeHand()) await prefs.setInt(countKey, usedCount + 1);
  }

  void _showAnalysisQuotaDialog(int used, int max, bool isElite) {
    final l10n = AppLocalizations.of(context);
    AppDialog.show<void>(
      context,
      title: l10n.quotaMonthlyLimitTitle,
      body: MessageBody(isElite
          ? l10n.quotaAiLimitElite(max)
          : l10n.quotaAiLimitPro(max, _maxMonthlyAnalysesElite)),
      actions: isElite
          ? DialogActionBar.single(cancelLabel: l10n.quotaOk)
          : DialogActionBar(
              confirmLabel: l10n.quotaUpgradeToElite,
              cancelLabel: l10n.quotaOk,
              onConfirm: () =>
                  PaywallScreen.show(context, featureName: 'More AI Analyses'),
            ),
    );
  }
}

/// Circular header tool button with ripple, tooltip and screen-reader label.
class _ToolButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final Color selectedColor;

  const _ToolButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.selectedColor = AppColors.accentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: selected
              ? selectedColor.withValues(alpha: 0.2)
              : AppColors.bgSurface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
