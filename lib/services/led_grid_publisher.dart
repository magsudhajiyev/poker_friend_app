import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';
import 'range_grid_service.dart';

/// EXPERIMENTAL — physical 13×13 LED range board (ESP32 + WS2812B panel).
///
/// Serializes the range grid into a compact payload and pushes it to the
/// board. v0 transport is plain HTTP on the local network (the board runs a
/// tiny web server, see `hardware/led-range-board/`); v1 will swap the
/// transport for Firebase RTDB streaming so the board syncs from anywhere.
///
/// PAYLOAD SPEC v2 (shared with led_range_board.ino — keep both in sync):
/// 169 cells, row-major over the canonical grid (ranks AKQJT98765432;
/// pairs on the diagonal, suited above, offsuit below — identical to
/// RangeGridView._classFor). THREE bytes per cell, hex-encoded → 1014
/// chars. Mixed strategies are first-class: the payload carries each
/// action's share of the sample, not just the dominant action.
///   byte 0: raise share << 4 | call share   (shares 0..15)
///   byte 1: check share << 4 | fold share
///   byte 2: intensity — min(255, hands in sample)
/// Shares are largest-remainder normalized to sum EXACTLY 15 for any cell
/// with data, all zero for empty cells. Firmware renders shares however
/// its hardware allows (LED-count split, color blend, ...).
class LedGridPublisher {
  LedGridPublisher._();

  static const _ranks = 'AKQJT98765432';
  static const _ipPrefKey = 'led_board_ip';

  /// Shares per cell sum to this (one hex nibble of resolution).
  static const _shareScale = 15;

  static Future<String?> getBoardIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_ipPrefKey);
    return (ip == null || ip.isEmpty) ? null : ip;
  }

  static Future<void> setBoardIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipPrefKey, ip.trim());
  }

  /// 1014-char hex payload for the board. Pure — unit-testable.
  static String encodeGrid(Map<String, RangeCellAggregate> aggregates) {
    final buf = StringBuffer();
    for (int row = 0; row < 13; row++) {
      for (int col = 0; col < 13; col++) {
        final String handClass;
        if (row == col) {
          handClass = '${_ranks[row]}${_ranks[row]}';
        } else if (row < col) {
          handClass = '${_ranks[row]}${_ranks[col]}s';
        } else {
          handClass = '${_ranks[col]}${_ranks[row]}o';
        }
        for (final byte in _cellBytes(aggregates[handClass])) {
          buf.write(byte.toRadixString(16).padLeft(2, '0'));
        }
      }
    }
    return buf.toString();
  }

  /// [raise<<4|call, check<<4|fold, intensity] for one cell.
  /// The app tracks all-in as its own category; the wire spec stays
  /// 4-action (v2), so all-in jams count into the raise share here.
  static List<int> _cellBytes(RangeCellAggregate? agg) {
    if (agg == null || agg.total == 0) return const [0, 0, 0];
    final shares = _normalizedShares(
        [
          agg.raiseCount + agg.allInCount,
          agg.callCount,
          agg.checkCount,
          agg.foldCount
        ],
        agg.total);
    return [
      (shares[0] << 4) | shares[1],
      (shares[2] << 4) | shares[3],
      min(255, agg.total),
    ];
  }

  /// Largest-remainder scaling of [counts] to integers summing exactly
  /// [_shareScale]. Guarantees a played action never rounds away to zero
  /// unless its true share is zero... within nibble resolution.
  static List<int> _normalizedShares(List<int> counts, int total) {
    final base = <int>[];
    final remainders = <double>[];
    var used = 0;
    for (final c in counts) {
      final exact = c * _shareScale / total;
      final floor = exact.floor();
      base.add(floor);
      remainders.add(exact - floor);
      used += floor;
    }
    var leftover = _shareScale - used;
    // Hand out leftover units to the largest remainders.
    final order = List<int>.generate(4, (i) => i)
      ..sort((a, b) => remainders[b].compareTo(remainders[a]));
    for (final i in order) {
      if (leftover == 0) break;
      base[i] += 1;
      leftover -= 1;
    }
    return base;
  }

  /// Encode an ordered list of cells (tap order = physical cluster order)
  /// for the /cells endpoint: 3 bytes per cell, same layout as the grid
  /// payload. Null entries render dark.
  static String encodeCells(List<RangeCellAggregate?> cells) {
    final buf = StringBuffer();
    for (final cell in cells) {
      for (final byte in _cellBytes(cell)) {
        buf.write(byte.toRadixString(16).padLeft(2, '0'));
      }
    }
    return buf.toString();
  }

  /// Push explicit cells to the board's clusters (selection mode).
  static Future<bool> pushCells(List<RangeCellAggregate?> cells) async {
    final ip = await getBoardIp();
    if (ip == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('http://$ip/cells'),
            headers: {'Content-Type': 'text/plain'},
            body: encodeCells(cells),
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      unawaited(LoggerService.debug('LED board cells push failed: $e'));
      return false;
    }
  }

  /// Turn all board LEDs off (LED mode deactivated in the app).
  static Future<bool> pushOff() async {
    final ip = await getBoardIp();
    if (ip == null) return false;
    try {
      final response = await http
          .post(Uri.parse('http://$ip/off'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      unawaited(LoggerService.debug('LED board off failed: $e'));
      return false;
    }
  }

  /// Aggregate under the given filters and push to the stored board IP.
  /// Returns true when the board acknowledged the frame.
  static Future<bool> push({
    required String gameType,
    String? posGroup,
    String? stackBucket,
    String? scenario,
  }) async {
    final ip = await getBoardIp();
    if (ip == null) return false;

    final aggregates = await RangeGridService.aggregateByHandClass(
      gameType: gameType,
      posGroup: posGroup,
      stackBucket: stackBucket,
      scenario: scenario,
    );
    final payload = encodeGrid(aggregates);

    try {
      final response = await http
          .post(
            Uri.parse('http://$ip/grid'),
            headers: {'Content-Type': 'text/plain'},
            body: payload,
          )
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      unawaited(LoggerService.debug('LED board push failed: $e'));
      return false;
    }
  }
}
