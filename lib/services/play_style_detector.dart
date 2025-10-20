class PlayStyleDetector {
  /// Detects play style based on poker statistics
  /// Returns a map with 'style' and 'description'
  static Map<String, String> detectPlayStyle({
    required double vpip,
    required double pfr,
    required double threeBet,
    required double aggressionFactor,
    double? wtsd,
    double? wsd,
  }) {
    // Handle edge cases
    if (vpip == 0 && pfr == 0) {
      return {
        'style': 'Unknown',
        'icon': 'tag.png', // Default icon
        'description': 'Not enough data to determine play style',
      };
    }

    final vpipPfrGap = vpip - pfr;

    // Decision tree for play style detection

    // MANIAC: VPIP ≥40%, PFR ≥20%, small gap, 3-bet ≥12%, AF ≥4
    if (vpip >= 40 && pfr >= 20 && vpipPfrGap <= 15 && threeBet >= 12 && aggressionFactor >= 4) {
      return {
        'style': 'Maniac',
        'icon': 'maniac.png',
        'description': 'Ultra-aggressive, plays many hands with constant pressure',
      };
    }

    // CALLING STATION: VPIP ≥25%, PFR <10%, big gap (≥15), 3-bet <3%, AF <1
    if (vpip >= 25 && pfr < 10 && vpipPfrGap >= 15 && threeBet < 3 && aggressionFactor < 1) {
      return {
        'style': 'Calling Station',
        'icon': 'calling_station.png',
        'description': 'Plays many hands passively, calls too often',
      };
    }

    // NIT: VPIP ≤15%, PFR ≤12%, 3-bet ≤5%, AF ≤2
    if (vpip <= 15 && pfr <= 12 && threeBet <= 5 && aggressionFactor <= 2) {
      return {
        'style': 'Nit',
        'icon': 'nit.png',
        'description': 'Very tight and passive, plays only premium hands',
      };
    }

    // LAG: VPIP >25%, PFR >18%, small gap (≤8), 3-bet ≥7%, AF ≥3
    if (vpip > 25 && pfr > 18 && vpipPfrGap <= 8 && threeBet >= 7 && aggressionFactor >= 3) {
      return {
        'style': 'LAG',
        'icon': 'lag.png',
        'description': 'Loose and aggressive, applies constant pressure',
      };
    }

    // TAG: VPIP 15-22%, PFR 12-18%, small gap (2-4), 3-bet 6-10%, AF ~3
    if (vpip >= 15 && vpip <= 22 && pfr >= 12 && pfr <= 18 &&
        vpipPfrGap >= 2 && vpipPfrGap <= 4 &&
        threeBet >= 6 && threeBet <= 10 &&
        aggressionFactor >= 2.5 && aggressionFactor <= 3.5) {
      return {
        'style': 'TAG',
        'icon': 'tag.png',
        'description': 'Tight and aggressive, plays solid fundamental poker',
      };
    }

    // BALANCED/SOLID: VPIP 20-28%, PFR 17-22%, small gap (2-5), 3-bet 6-10%, AF 2-4
    if (vpip >= 20 && vpip <= 28 && pfr >= 17 && pfr <= 22 &&
        vpipPfrGap >= 2 && vpipPfrGap <= 5 &&
        threeBet >= 6 && threeBet <= 10 &&
        aggressionFactor >= 2 && aggressionFactor <= 4) {
      return {
        'style': 'Balanced',
        'icon': 'balanced.png',
        'description': 'Balanced approach, adjusts strategy to opponents',
      };
    }

    // Fallback classifications based on primary stats

    // Tight-Passive (between Nit and TAG but more passive)
    if (vpip < 22 && pfr < 15 && vpipPfrGap > 4 && aggressionFactor < 2.5) {
      return {
        'style': 'Tight-Passive',
        'icon': 'nit.png',
        'description': 'Plays few hands with passive approach',
      };
    }

    // Loose-Passive (not quite a calling station but loose and passive)
    if (vpip >= 25 && pfr < 15 && vpipPfrGap >= 10 && aggressionFactor < 2) {
      return {
        'style': 'Loose-Passive',
        'icon': 'calling_station.png',
        'description': 'Plays many hands with passive approach',
      };
    }

    // Loose-Aggressive (close to LAG but not quite)
    if (vpip > 22 && pfr > 15 && vpipPfrGap <= 10 && aggressionFactor >= 2.5) {
      return {
        'style': 'LAG',
        'icon': 'lag.png',
        'description': 'Loose and aggressive, plays many hands aggressively',
      };
    }

    // Aggressive but with moderate AF (still LAG-ish)
    if (vpip > 30 && pfr > 20 && aggressionFactor >= 1.0) {
      return {
        'style': 'LAG',
        'icon': 'lag.png',
        'description': 'Loose and aggressive, plays many hands with aggression',
      };
    }

    // Default to TAG if aggressive with reasonable stats
    if (pfr >= 12 && aggressionFactor >= 2.5 && vpipPfrGap <= 6) {
      return {
        'style': 'TAG',
        'icon': 'tag.png',
        'description': 'Tight and aggressive, plays solid poker',
      };
    }

    // Final fallback
    return {
      'style': 'Unknown',
      'icon': 'tag.png',
      'description': 'Play style unclear, need more data',
    };
  }

  /// Get play style abbreviation for compact display
  static String getStyleAbbreviation(String style) {
    switch (style) {
      case 'Nit':
      case 'Tight-Passive':
        return 'NIT';
      case 'TAG':
        return 'TAG';
      case 'Balanced':
        return 'SOLID';
      case 'LAG':
        return 'LAG';
      case 'Calling Station':
      case 'Loose-Passive':
        return 'FISH';
      case 'Maniac':
        return 'MANIAC';
      default:
        return 'N/A';
    }
  }

  /// Get color for play style
  static String getStyleColor(String style) {
    switch (style) {
      case 'Nit':
      case 'Tight-Passive':
        return '#9B59B6'; // Purple
      case 'TAG':
        return '#5AC95A'; // Green
      case 'Balanced':
        return '#5B9CDF'; // Blue
      case 'LAG':
        return '#E67E22'; // Orange
      case 'Calling Station':
      case 'Loose-Passive':
        return '#E74C3C'; // Red
      case 'Maniac':
        return '#FF4757'; // Bright red
      default:
        return '#9A9A9A'; // Gray
    }
  }
}
