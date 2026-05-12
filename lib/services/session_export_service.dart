import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pokerstars_export_service.dart';

/// Service for exporting a full session as PokerStars hand history + stats summary.
///
/// Generates the export text locally, sends it to the backend which emails
/// it to the user as a .txt attachment.
class SessionExportService {
  SessionExportService._();

  static const String _baseUrl =
      'https://poker-friend-engine.onrender.com/api/v1/export';
  static const String _apiKey =
      'oCx_2Be-_wkxXGa_cacuG4Dm0--sglzSSddJD46bibI';

  /// Export a full session via backend email.
  ///
  /// Throws on failure (network error, backend error, etc.).
  static Future<void> exportSession({
    required String userId,
    required String userEmail,
    required Map<String, dynamic> session,
    required List<Map<String, dynamic>> hands,
  }) async {
    if (hands.isEmpty) throw Exception('No hands to export');

    debugPrint('SessionExport: Generating export for ${hands.length} hands...');

    final pokerstarsText =
        PokerStarsExportService.exportSession(session, hands);
    final statsSummary = generateStatsSummary(session, hands);
    final fullText = '$statsSummary\n\n$pokerstarsText';

    debugPrint('SessionExport: Export text generated (${fullText.length} chars)');
    debugPrint('SessionExport: Sending to $userEmail via $_baseUrl/session-email');

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/session-email'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _apiKey,
              'X-User-ID': userId,
            },
            body: jsonEncode({
              'export_text': fullText,
              'user_email': userEmail,
              'session_name':
                  session['sessionName'] as String? ?? 'Poker Session',
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('SessionExport: Response status=${response.statusCode}');
      debugPrint('SessionExport: Response body=${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      debugPrint('SessionExport: Email sent successfully to $userEmail');
    } catch (e) {
      debugPrint('SessionExport: ERROR — $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Stats summary generation
  // ─────────────────────────────────────────────────────────────

  /// Generate a plain-text stats summary for the session.
  static String generateStatsSummary(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> hands,
  ) {
    final sessionName = session['sessionName'] as String? ?? 'Poker Session';
    final gameType = (session['gameType'] as String? ?? 'cash').toLowerCase();
    final sb = session['smallBlind'] ?? 0;
    final bb = session['bigBlind'] ?? 0;

    // Date and duration
    final startTime = _parseDateTime(session['startTime']);
    final endTime = _parseDateTime(session['endTime']);
    final dateStr = startTime != null
        ? '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}'
        : 'N/A';
    final duration = (startTime != null && endTime != null)
        ? _formatDuration(endTime.difference(startTime))
        : 'N/A';

    // Hand counts
    final totalHands = hands.length;
    int wonHands = 0;
    int vpipCount = 0;
    int pfrCount = 0;
    double biggestPotWon = 0;
    double biggestPotLost = 0;

    for (final hand in hands) {
      final heroSeat = hand['heroSeatNumber'] as int?;
      final winnerId = hand['winnerId'] as int?;
      final isChopped = hand['isChoppedPot'] == true;
      final choppedWinners =
          (hand['choppedWinners'] as List<dynamic>?)?.cast<int>() ?? [];
      final potAmount = (hand['potAmount'] as num?)?.toDouble() ?? 0;

      final heroWon = isChopped
          ? choppedWinners.contains(heroSeat)
          : winnerId == heroSeat;

      if (heroWon) {
        wonHands++;
        if (potAmount > biggestPotWon) biggestPotWon = potAmount;
      } else if (heroSeat != null) {
        // Check if hero was involved (put money in)
        final actions = (hand['actions'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final heroInvolved = actions.any((a) =>
            a['player'] == heroSeat &&
            _isVoluntaryAction(a['action'] as String? ?? ''));
        if (heroInvolved && potAmount > biggestPotLost) {
          biggestPotLost = potAmount;
        }
      }

      // VPIP / PFR from preflop actions
      if (heroSeat != null) {
        final preflopActions = (hand['actions'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .where((a) =>
                    (a['street'] as String?)?.toLowerCase() == 'preflop' &&
                    a['player'] == heroSeat)
                .toList() ??
            [];

        bool heroVpip = false;
        bool heroPfr = false;
        for (final a in preflopActions) {
          final action = (a['action'] as String?)?.toLowerCase() ?? '';
          if (action == 'call' || action == 'raise' || action == 'all-in') {
            heroVpip = true;
          }
          if (action == 'raise' || action == 'all-in') {
            heroPfr = true;
          }
        }
        if (heroVpip) vpipCount++;
        if (heroPfr) pfrCount++;
      }
    }

    final winRate =
        totalHands > 0 ? (wonHands / totalHands * 100).toStringAsFixed(1) : '0';
    final vpipPct =
        totalHands > 0 ? (vpipCount / totalHands * 100).toStringAsFixed(1) : '0';
    final pfrPct =
        totalHands > 0 ? (pfrCount / totalHands * 100).toStringAsFixed(1) : '0';

    // Net result
    final startingStack =
        (session['startingStack'] as num?)?.toDouble() ?? 0;
    final finalStack =
        (session['finalStack'] as num?)?.toDouble() ??
        (session['currentStack'] as num?)?.toDouble() ??
        0;
    final totalBuyIn =
        (session['totalBuyIn'] as num?)?.toDouble() ??
        (session['buyInAmount'] as num?)?.toDouble() ??
        startingStack;
    final netResult = finalStack - totalBuyIn;
    final netStr = netResult >= 0
        ? '+${_fmtAmt(netResult)}'
        : _fmtAmt(netResult);
    final unit = gameType == 'tournament' ? 'chips' : '\$';

    final buf = StringBuffer();
    buf.writeln('=== SESSION SUMMARY ===');
    buf.writeln('Session: $sessionName');
    buf.writeln('Stakes: $sb/$bb');
    buf.writeln('Date: $dateStr');
    buf.writeln('Duration: $duration');
    buf.writeln('Hands Played: $totalHands');
    buf.writeln('Hands Won: $wonHands ($winRate%)');
    buf.writeln('Net Result: $netStr $unit');
    buf.writeln('');
    buf.writeln('VPIP: $vpipPct% | PFR: $pfrPct%');
    if (biggestPotWon > 0) {
      buf.writeln('Biggest Pot Won: ${_fmtAmt(biggestPotWon)}');
    }
    if (biggestPotLost > 0) {
      buf.writeln('Biggest Pot Lost: ${_fmtAmt(biggestPotLost)}');
    }
    buf.write('========================');

    return buf.toString();
  }

  static bool _isVoluntaryAction(String action) {
    final a = action.toLowerCase();
    return a == 'call' || a == 'bet' || a == 'raise' || a == 'all-in';
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static String _fmtAmt(double amount) {
    if (amount == amount.roundToDouble() && amount.abs() < 1e15) {
      return amount.toInt().toString();
    }
    String s = amount.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
