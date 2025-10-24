import 'package:flutter/material.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import '../services/opponent_stats_service.dart';
import 'opponent_hands_screen.dart';

class OpponentDetailScreen extends StatefulWidget {
  final Opponent opponent;

  const OpponentDetailScreen({
    Key? key,
    required this.opponent,
  }) : super(key: key);

  @override
  State<OpponentDetailScreen> createState() => _OpponentDetailScreenState();
}

class _OpponentDetailScreenState extends State<OpponentDetailScreen> {
  late Opponent _opponent;
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  Map<String, dynamic>? _statistics;
  OpponentStats? _opponentStats; // Store the actual OpponentStats object
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent;
    _nameController = TextEditingController(text: _opponent.name);
    _notesController = TextEditingController(text: _opponent.notes ?? '');
    _loadStatistics();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      // Load stats from optimized structure - no recalculation needed!
      final stats = await _calculateOpponentStatistics(_opponent.name);
      final opponentStats = await OpponentStatsService.getOpponentStats(_opponent.name);
      setState(() {
        _statistics = stats;
        _opponentStats = opponentStats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateOpponentStatistics(String opponentName) async {
    try {
      // 🚀 OPTIMIZED: Fast O(1) stats lookup from dedicated table
      final optimizedStats = await OpponentStatsService.getOpponentStats(opponentName);

      if (optimizedStats != null) {
        print('✅ Using optimized stats for $opponentName (${optimizedStats.handsPlayed} hands)');
        final legacyMap = optimizedStats.toLegacyStatsMap();
        print('🔍 DEBUG: Legacy map for $opponentName: totalHands=${legacyMap['totalHands']}, totalSessions=${legacyMap['totalSessions']}');
        return legacyMap;
      } else {
        print('⚠️ No optimized stats found for $opponentName - calculating from hand data');
        // Fall back to legacy calculation method
        return await _calculateLegacyOpponentStatistics(opponentName);
      }
    } catch (e) {
      print('❌ Error loading optimized stats: $e');
      return {
        'handsPlayed': 0,
        'vpip': 0.0,
        'pfr': 0.0,
        'aggression': 0.0,
        'actions': {
          'preflop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'flop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'turn': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'river': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
        },
      };
    }
  }

  /// Legacy calculation method used as fallback when optimized stats not available
  Future<Map<String, dynamic>> _calculateLegacyOpponentStatistics(String opponentName) async {
    try {
      // Initialize counters
      int totalHands = 0;
      int totalSessions = 0;
      int vpipHands = 0;
      int pfrHands = 0;
      int foldCount = 0;
      int callCount = 0;
      int betCount = 0;
      int raiseCount = 0;
      int checkCount = 0;
      int aggressiveActions = 0;
      int passiveActions = 0;

      Set<String> sessionsPlayed = <String>{};

      // Get all sessions
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
        print('🔍 DEBUG: Found ${sessions.length} sessions from Firebase');
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
        print('🔍 DEBUG: Found ${sessions.length} sessions from local storage');
      }

      // Process each session
      for (final session in sessions) {
        final sessionId = session['id'] as String;
        final playerNames = session['playerNames'] as Map<String, dynamic>?;

        if (playerNames != null) {
          // Check if opponent played in this session
          bool opponentInSession = false;
          print('🔍 DEBUG: Session $sessionId has players: ${playerNames.values.toList()}');
          for (final playerName in playerNames.values) {
            print('🔍 DEBUG: Comparing "${playerName.toString().toLowerCase()}" with "${opponentName.toLowerCase()}"');
            if (playerName.toString().toLowerCase() == opponentName.toLowerCase()) {
              opponentInSession = true;
              print('✅ DEBUG: Found $opponentName in session $sessionId');
              break;
            }
          }

          if (opponentInSession) {
            sessionsPlayed.add(sessionId);

            // Get hands for this session
            List<Map<String, dynamic>> hands;
            try {
              hands = await FirebaseService.getSessionHands(sessionId);
              print('🔍 DEBUG: Found ${hands.length} hands in Firebase for session $sessionId');
            } catch (e) {
              hands = await LocalStorageService.getSessionHands(sessionId);
              print('🔍 DEBUG: Found ${hands.length} hands in local storage for session $sessionId');
            }

            // Process each hand
            for (final hand in hands) {
              bool opponentInThisHand = false;
              bool vpipThisHand = false;
              bool pfrThisHand = false;

              // Process actions if available
              if (hand['actions'] != null) {
                final actions = hand['actions'] as List<dynamic>;
                String currentStreet = 'preflop';

                for (final action in actions) {
                  final actionMap = action as Map<String, dynamic>;
                  final actionPlayerName = actionMap['playerName'] as String?;
                  final actionType = actionMap['action'] as String?;
                  final street = actionMap['street'] as String?;

                  if (street != null) {
                    currentStreet = street.toLowerCase();
                  }

                  if (actionPlayerName != null && actionType != null &&
                      actionPlayerName.toLowerCase().contains(opponentName.toLowerCase())) {

                    opponentInThisHand = true;
                    final actionKey = actionType.toLowerCase();

                    // Count action types
                    switch (actionKey) {
                      case 'fold':
                        foldCount++;
                        break;
                      case 'call':
                        callCount++;
                        passiveActions++;
                        if (currentStreet == 'preflop' && !vpipThisHand) {
                          vpipThisHand = true;
                        }
                        break;
                      case 'bet':
                        betCount++;
                        aggressiveActions++;
                        if (currentStreet == 'preflop') {
                          if (!vpipThisHand) vpipThisHand = true;
                          if (!pfrThisHand) pfrThisHand = true;
                        }
                        break;
                      case 'raise':
                        raiseCount++;
                        aggressiveActions++;
                        if (currentStreet == 'preflop') {
                          if (!vpipThisHand) vpipThisHand = true;
                          if (!pfrThisHand) pfrThisHand = true;
                        }
                        break;
                      case 'check':
                        checkCount++;
                        passiveActions++;
                        break;
                    }
                  }
                }
              }

              // Only count the hand if opponent participated
              if (opponentInThisHand) {
                totalHands++;
                if (vpipThisHand) vpipHands++;
                if (pfrThisHand) pfrHands++;
              }
            }
          }
        }
      }

      totalSessions = sessionsPlayed.length;

      // Calculate percentages
      final vpip = totalHands > 0 ? (vpipHands / totalHands * 100) : 0.0;
      final pfr = totalHands > 0 ? (pfrHands / totalHands * 100) : 0.0;
      final foldPercentage = totalHands > 0 ? (foldCount / totalHands * 100) : 0.0;
      final callPercentage = totalHands > 0 ? (callCount / totalHands * 100) : 0.0;
      final betPercentage = totalHands > 0 ? (betCount / totalHands * 100) : 0.0;
      final raisePercentage = totalHands > 0 ? (raiseCount / totalHands * 100) : 0.0;
      final checkPercentage = totalHands > 0 ? (checkCount / totalHands * 100) : 0.0;

      final totalActions = aggressiveActions + passiveActions;
      final aggression = totalActions > 0 ? (aggressiveActions / totalActions) : 0.0;

      print('📊 Calculated legacy stats for $opponentName: $totalHands hands, VPIP: ${vpip.toStringAsFixed(1)}%, PFR: ${pfr.toStringAsFixed(1)}%');

      return {
        'totalHands': totalHands,
        'totalSessions': totalSessions,
        'vpip': vpip,
        'pfr': pfr,
        'aggression': aggression,
        'foldPercentage': foldPercentage,
        'callPercentage': callPercentage,
        'betPercentage': betPercentage,
        'raisePercentage': raisePercentage,
        'checkPercentage': checkPercentage,
        'actions': {
          'preflop': {'fold': foldCount, 'call': callCount, 'bet': betCount, 'raise': raiseCount},
          'flop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'turn': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'river': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
        },
      };
    } catch (e) {
      print('❌ Error calculating legacy stats: $e');
      return {
        'totalHands': 0,
        'totalSessions': 0,
        'vpip': 0.0,
        'pfr': 0.0,
        'aggression': 0.0,
        'foldPercentage': 0.0,
        'callPercentage': 0.0,
        'betPercentage': 0.0,
        'raisePercentage': 0.0,
        'checkPercentage': 0.0,
        'actions': {
          'preflop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'flop': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'turn': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
          'river': {'fold': 0, 'call': 0, 'bet': 0, 'raise': 0},
        },
      };
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    final updatedOpponent = _opponent.copyWith(
      name: _nameController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    try {
      await OpponentService.saveOpponent(updatedOpponent);
      setState(() {
        _opponent = updatedOpponent;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opponent updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating opponent: $e')),
      );
    }
  }

  Color _getColorForOpponent(OpponentColor color) {
    switch (color) {
      case OpponentColor.red:
        return Colors.red;
      case OpponentColor.blue:
        return Colors.blue;
      case OpponentColor.green:
        return Colors.green;
      case OpponentColor.orange:
        return Colors.orange;
      case OpponentColor.purple:
        return Colors.purple;
      case OpponentColor.teal:
        return Colors.teal;
      case OpponentColor.pink:
        return Colors.pink;
      case OpponentColor.indigo:
        return Colors.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
              ),
              child: Row(
                children: [
                  // Back button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  
                  // Title section
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _isEditing ? 'Edit Opponent' : _opponent.name,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Player Statistics',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9A9A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isEditing ? Color(0xFF5AC95A) : Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _isEditing ? _saveChanges : () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      icon: Icon(
                        _isEditing ? Icons.check : Icons.edit,
                        color: Colors.white,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  
                  if (_isEditing) ...[
                    SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF161618),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _nameController.text = _opponent.name;
                            _notesController.text = _opponent.notes ?? '';
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoCard(),
                    const SizedBox(height: 16),
                    _buildStatisticsCard(),
                    const SizedBox(height: 16),
                    _buildHandsButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getColorForOpponent(_opponent.color),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getColorForOpponent(_opponent.color).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _opponent.name.isNotEmpty ? _opponent.name[0].toUpperCase() : 'O',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Player Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Playing Style: ${_opponentStats?.playingStyle ?? 'No Data'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isEditing)
                  _buildColorSelector(),
              ],
            ),
            const SizedBox(height: 20),
            if (_isEditing) ...[
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF161618),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF2A2A2E)),
                ),
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Player Name',
                    labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF161618),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF2A2A2E)),
                ),
                child: TextField(
                  controller: _notesController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  maxLines: 3,
                ),
              ),
            ] else ...[
              _buildInfoRowWithCustomIcon('icons/id.png', 'Name', _opponent.name),
              if (_opponent.notes != null && _opponent.notes!.isNotEmpty)
                _buildInfoRowWithCustomIcon('icons/notepad.png', 'Notes', _opponent.notes!),
              _buildInfoRowWithCustomIcon('icons/calendar.png', 'First Seen',
                  _opponent.createdAt.toString().split(' ')[0]),
              _buildInfoRowWithCustomIcon('icons/clock.png', 'Last Seen',
                  _opponent.lastSeenAt.toString().split(' ')[0]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Color(0xFF9A9A9A)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    return PopupMenuButton<OpponentColor>(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _getColorForOpponent(_opponent.color),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
      ),
      onSelected: (color) {
        setState(() {
          _opponent = _opponent.copyWith(color: color);
        });
      },
      itemBuilder: (context) => OpponentColor.values.map((color) {
        return PopupMenuItem<OpponentColor>(
          value: color,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _getColorForOpponent(color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(color.displayName),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('icons/stats.png', width: 28, height: 28),
                SizedBox(width: 12),
                Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoadingStats)
              Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF5AC95A),
                ),
              )
            else if (_statistics != null) ...[
              // Stats are loaded from OpponentStats - no need to update Opponent model
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Hands Played', '${_statistics!['totalHands']}', iconPath: 'icons/hands_played.png'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Sessions', '${_statistics!['totalSessions']}', iconPath: 'icons/session.png'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('VPIP', '${_formatStat(_statistics!['vpip'])}%', iconPath: 'icons/vpip.png'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('PFR', '${_formatStat(_statistics!['pfr'])}%', iconPath: 'icons/bet.png'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Aggression', _formatAggression(_statistics!['aggression']), iconPath: 'icons/aggression.png'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Fold %', '${_formatStat(_statistics!['foldPercentage'])}%', iconPath: 'icons/fold.png'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 1,
                color: Color(0xFF2A2A2E),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Image.asset('icons/action_distribution.png', width: 28, height: 28),
                  SizedBox(width: 8),
                  Text(
                    'Action Distribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Call', '${_formatStat(_statistics!['callPercentage'])}%', iconPath: 'icons/play_style/calling_station.png'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Bet', '${_formatStat(_statistics!['betPercentage'])}%', iconPath: 'icons/bet_with_chips.png'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Raise', '${_formatStat(_statistics!['raisePercentage'])}%', iconPath: 'icons/bet.png'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: _buildStatItem('Check', '${_formatStat(_statistics!['checkPercentage'])}%', iconPath: 'icons/check.png'),
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                'No statistics available',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {String? iconPath}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (iconPath != null)
                Image.asset(
                  iconPath,
                  width: 32,
                  height: 32,
                ),
            ],
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper function to safely format statistics with null safety
  String _formatStat(dynamic value, {int decimals = 1}) {
    if (value == null) return '-';
    if (value is num) {
      return value.toStringAsFixed(decimals);
    }
    return '-';
  }

  /// Helper function to format aggression factor with infinity handling
  String _formatAggression(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      if (value >= 999) return '∞';
      return value.toStringAsFixed(2);
    }
    return '-';
  }

  // REMOVED: _updateOpponentStoredStats() is no longer needed
  // Stats are stored in OpponentStats only, not in Opponent model

  Widget _buildHandsButton() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('icons/history.png', width: 28, height: 28),
                SizedBox(width: 12),
                Text(
                  'Hand History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'View all hands played with this opponent',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9A9A9A),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFcb5242),
                      Color(0xFFb8442f),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFcb5242).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OpponentHandsScreen(
                            opponent: _opponent,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('icons/history.png', width: 20, height: 20),
                          SizedBox(width: 8),
                          Text(
                            'View Hand History',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowWithCustomIcon(String iconPath, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Image.asset(iconPath, width: 32, height: 32),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF9A9A9A),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}