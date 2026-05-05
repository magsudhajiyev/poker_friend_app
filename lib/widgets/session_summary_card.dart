import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game_types.dart';
import '../services/currency_service.dart';

/// Data needed to render the post-session summary card.
class SessionSummaryData {
  final String sessionName;
  final GameType gameType;
  final double profitLoss;
  final double totalBuyIn;
  final int handsPlayed;
  final double biggestPot;
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
                  color: const Color(0xFF101115),
                  borderRadius: BorderRadius.circular(20),
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
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Center(
                          child: Text(
                            'Close',
                            style: GoogleFonts.ibmPlexSans(
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
                          color: const Color(0xFF62E3BC),
                          borderRadius: BorderRadius.circular(60),
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
                                      style: GoogleFonts.ibmPlexSans(
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
          // Header: logo + app name
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  width: 28,
                  height: 28,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Final Table',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Session name
          Text(
            data.sessionName,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Game type pill + duration
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: data.isCash
                      ? const Color(0xFF62E3BC).withValues(alpha: 0.15)
                      : const Color(0xFFFFB74D).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Text(
                  data.isCash ? 'CASH' : 'TOURNAMENT',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: data.isCash
                        ? const Color(0xFF62E3BC)
                        : const Color(0xFFFFB74D),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                data.formattedDuration,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
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
              _buildStatItemCentered('Biggest Pot', data.isCash
                  ? CurrencyService.formatCash(data.biggestPot)
                  : data.biggestPot.toStringAsFixed(0)),
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
              style: GoogleFonts.ibmPlexSans(
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
        ? const Color(0xFF62E3BC)
        : const Color(0xFFD55A41);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$prefix${CurrencyService.formatCash(data.profitLoss)}',
          style: GoogleFonts.familjenGrotesk(
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
        ? const Color(0xFF62E3BC)
        : const Color(0xFFD55A41);

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
                style: GoogleFonts.familjenGrotesk(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFB74D),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Prize
          if (data.prizeWon != null && data.prizeWon! > 0) ...[
            Text(
              'Prize: ${CurrencyService.formatCash(data.prizeWon!)}',
              style: GoogleFonts.robotoMono(
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
            style: GoogleFonts.robotoMono(
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
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
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
