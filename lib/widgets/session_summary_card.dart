import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game_types.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Data needed to render the post-session summary card.
class SessionSummaryData {
  final String sessionName;
  final GameType gameType;
  final double profitLoss;
  final double totalBuyIn;
  final int handsPlayed;
  final double biggestPot;
  final double? biggestPotBB; // BB level when biggest pot occurred
  final int durationMinutes;
  final int? finishedPlace; // tournament only
  final int? fieldSize; // tournament only
  final double? prizeWon; // tournament only
  final String? biggestPotWonCards; // e.g. "A♠ K♥"
  final String? biggestPotLostCards; // e.g. "Q♦ J♣"

  const SessionSummaryData({
    required this.sessionName,
    required this.gameType,
    required this.profitLoss,
    required this.totalBuyIn,
    required this.handsPlayed,
    required this.biggestPot,
    this.biggestPotBB = 0.0,
    required this.durationMinutes,
    this.finishedPlace,
    this.fieldSize,
    this.prizeWon,
    this.biggestPotWonCards,
    this.biggestPotLostCards,
  });

  bool get isCash => gameType == GameType.cash;
  bool get isProfit => profitLoss >= 0;

  String get formattedDuration {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

/// Shows a post-session summary card dialog with share functionality.
class SessionSummaryCard extends StatefulWidget {
  final SessionSummaryData data;

  const SessionSummaryCard({super.key, required this.data});

  /// Show the summary card as a dialog. Returns when user closes it.
  static Future<void> show({
    required BuildContext context,
    required SessionSummaryData data,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return Material(
          type: MaterialType.transparency,
          child: SessionSummaryCard(data: data),
        );
      },
    );
  }

  @override
  State<SessionSummaryCard> createState() => _SessionSummaryCardState();
}

class _SessionSummaryCardState extends State<SessionSummaryCard> {
  final _repaintKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareCard() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/session_summary.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Session Summary — ${widget.data.sessionName}',
      );
    } catch (e) {
      // Silently fail
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.88).clamp(300.0, 400.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The card (captured for sharing)
            RepaintBoundary(
              key: _repaintKey,
              child: Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppDecorations.radius20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: _buildCardContent(),
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            SizedBox(
              width: cardWidth,
              child: Row(
                children: [
                  // Close button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                        ),
                        child: Center(
                          child: Text(
                            'Close',
                            style: AppTypography.ibm(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share button
                  Expanded(
                    child: GestureDetector(
                      onTap: _isSharing ? null : _shareCard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.tealPrimary,
                          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                        ),
                        child: Center(
                          child: _isSharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.share, size: 18, color: Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Share',
                                      style: AppTypography.ibm(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    final data = widget.data;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: logo + session info side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
                child: Image.asset(
                  'assets/logo.png',
                  width: 48,
                  height: 48,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.sessionName,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: data.isCash
                                ? AppColors.tealPrimary.withValues(alpha: 0.15)
                                : AppColors.warningAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                          ),
                          child: Text(
                            data.isCash ? 'CASH' : 'TOURNAMENT',
                            style: AppTypography.ibm(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: data.isCash
                                  ? AppColors.tealPrimary
                                  : AppColors.warningAmber,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          data.formattedDuration,
                          style: AppTypography.ibm(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Hero stat
          if (data.isCash)
            _buildCashHeroStat()
          else
            _buildTournamentHeroStat(),

          const SizedBox(height: 24),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats grid
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItemCentered('Hands', '${data.handsPlayed}'),
              const SizedBox(width: 40),
              _buildStatItemCentered('Biggest Pot', _formatBiggestPot()),
            ],
          ),
          if (data.biggestPotWonCards != null || data.biggestPotLostCards != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (data.biggestPotWonCards != null)
                  _buildStatItemCentered('Best Hand', data.biggestPotWonCards!),
                if (data.biggestPotWonCards != null && data.biggestPotLostCards != null)
                  const SizedBox(width: 40),
                if (data.biggestPotLostCards != null)
                  _buildStatItemCentered('Worst Hand', data.biggestPotLostCards!),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Footer
          Center(
            child: Text(
              'Tracked with Final Table',
              style: AppTypography.ibm(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.25),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashHeroStat() {
    final data = widget.data;
    final prefix = data.isProfit ? '+' : '';
    final color = data.isProfit
        ? AppColors.tealPrimary
        : AppColors.errorRed;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$prefix${CurrencyService.formatCash(data.profitLoss)}',
          style: AppTypography.grotesk(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentHeroStat() {
    final data = widget.data;
    final color = data.isProfit
        ? AppColors.tealPrimary
        : AppColors.errorRed;

    return Center(
      child: Column(
        children: [
          // Placement
          if (data.finishedPlace != null) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.fieldSize != null
                    ? '${_ordinal(data.finishedPlace!)} / ${data.fieldSize}'
                    : _ordinal(data.finishedPlace!),
                style: AppTypography.grotesk(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warningAmber,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Prize
          if (data.prizeWon != null && data.prizeWon! > 0) ...[
            Text(
              'Prize: ${CurrencyService.formatCash(data.prizeWon!)}',
              style: AppTypography.mono(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
          ],
          // Net profit/loss
          Text(
            'Net: ${data.isProfit ? '+' : ''}${CurrencyService.formatCash(data.profitLoss)}',
            style: AppTypography.mono(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemCentered(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.mono(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatBiggestPot() {
    final data = widget.data;
    if (data.isCash) {
      return CurrencyService.formatCash(data.biggestPot);
    }
    // Tournament: show BB equivalent if we know the BB level
    if (data.biggestPotBB != null && data.biggestPotBB! > 0) {
      final bb = (data.biggestPot / data.biggestPotBB!).round();
      return '$bb BB';
    }
    return data.biggestPot.toStringAsFixed(0);
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
}
