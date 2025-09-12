import 'package:flutter/material.dart';
import '../models/opponent.dart';
import '../services/opponent_service.dart';
import '../services/local_storage_service.dart';
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
      final stats = await _calculateOpponentStatistics(_opponent.name);
      setState(() {
        _statistics = stats;
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
      // Get all hands from the database - use LocalStorageService method for proper parsing
      final db = await LocalStorageService.database;
      
      // Get all session IDs first
      final sessions = await db.query('sessions');
      
      Map<String, int> actionCounts = {
        'fold': 0,
        'call': 0,
        'bet': 0,
        'raise': 0,
        'check': 0,
      };
      
      int totalHands = 0;
      int sessionsWithOpponent = 0;
      Set<String> sessionsWithThisOpponent = {};
      
      print('DEBUG: Looking for opponent: "$opponentName"');
      
      for (final session in sessions) {
        // Get all hands for this session using the proper method
        final hands = await LocalStorageService.getSessionHands(session['id'] as String);
        
        bool opponentFoundInSession = false;
        
        for (final hand in hands) {
          bool opponentInHand = false;
          
          // Check if opponent is in playerNames
          final playerNames = hand['playerNames'] as Map<int, String>?;
          if (playerNames != null) {
            for (final playerName in playerNames.values) {
              if (playerName.toLowerCase().contains(opponentName.toLowerCase()) || 
                  opponentName.toLowerCase().contains(playerName.toLowerCase())) {
                opponentInHand = true;
                break;
              }
            }
          }
          
          // Also check actions for playerName field
          if (!opponentInHand && hand['actions'] != null) {
            final actions = hand['actions'] as List<dynamic>;
            for (final action in actions) {
              final actionMap = action as Map<String, dynamic>;
              final actionPlayerName = actionMap['playerName'] as String?;
              if (actionPlayerName != null && 
                  (actionPlayerName.toLowerCase().contains(opponentName.toLowerCase()) ||
                   opponentName.toLowerCase().contains(actionPlayerName.toLowerCase()))) {
                opponentInHand = true;
                break;
              }
            }
          }
          
          if (opponentInHand) {
            totalHands++;
            opponentFoundInSession = true;
            sessionsWithThisOpponent.add(session['id'] as String);
            
            // Count actions for this opponent in this hand
            if (hand['actions'] != null) {
              final actions = hand['actions'] as List<dynamic>;
              
              // Track the most aggressive action by this opponent in this hand
              String? mostAggressiveAction;
              int aggressionLevel = 0; // fold:1, check:2, call:3, bet:4, raise:5
              
              for (final action in actions) {
                final actionMap = action as Map<String, dynamic>;
                final actionPlayerName = actionMap['playerName'] as String?;
                final actionType = actionMap['action'] as String?;
                
                if (actionPlayerName != null && actionType != null &&
                    (actionPlayerName.toLowerCase().contains(opponentName.toLowerCase()) ||
                     opponentName.toLowerCase().contains(actionPlayerName.toLowerCase()))) {
                  
                  int currentAggression = 0;
                  switch (actionType.toLowerCase()) {
                    case 'fold': currentAggression = 1; break;
                    case 'check': currentAggression = 2; break;
                    case 'call': currentAggression = 3; break;
                    case 'bet': currentAggression = 4; break;
                    case 'raise': currentAggression = 5; break;
                  }
                  
                  if (currentAggression > aggressionLevel) {
                    aggressionLevel = currentAggression;
                    mostAggressiveAction = actionType.toLowerCase();
                  }
                }
              }
              
              // Count the most aggressive action for this hand
              if (mostAggressiveAction != null && actionCounts.containsKey(mostAggressiveAction)) {
                actionCounts[mostAggressiveAction] = actionCounts[mostAggressiveAction]! + 1;
              }
            }
          }
        }
      }
      
      sessionsWithOpponent = sessionsWithThisOpponent.length;
      print('DEBUG: Found opponent in $totalHands hands across $sessionsWithOpponent sessions');
      print('DEBUG: Action counts: $actionCounts');

      final totalActions = totalHands > 0 ? actionCounts.values.reduce((a, b) => a + b) : 0;
      
      // Calculate VPIP (call + bet + raise)
      final vpipActions = actionCounts['call']! + actionCounts['bet']! + actionCounts['raise']!;
      final vpip = totalHands > 0 ? (vpipActions / totalHands * 100) : 0.0;
      
      // Calculate PFR (preflop raise frequency - simplified)
      final pfr = totalHands > 0 ? (actionCounts['raise']! / totalHands * 100) : 0.0;
      
      // Calculate aggression factor
      final aggressiveActions = actionCounts['bet']! + actionCounts['raise']!;
      final passiveActions = actionCounts['call']! + actionCounts['check']!;
      final aggression = passiveActions > 0 ? (aggressiveActions / passiveActions) : 
                        (aggressiveActions > 0 ? 999.0 : 0.0);

      return {
        'totalHands': totalHands,
        'totalSessions': sessionsWithOpponent,
        'totalActions': totalActions,
        'vpip': vpip,
        'pfr': pfr,
        'aggression': aggression,
        'foldToBet': totalActions > 0 ? (actionCounts['fold']! / totalActions * 100) : 0.0,
        'callPercentage': totalActions > 0 ? (actionCounts['call']! / totalActions * 100) : 0.0,
        'betPercentage': totalActions > 0 ? (actionCounts['bet']! / totalActions * 100) : 0.0,
        'raisePercentage': totalActions > 0 ? (actionCounts['raise']! / totalActions * 100) : 0.0,
        'foldPercentage': totalActions > 0 ? (actionCounts['fold']! / totalActions * 100) : 0.0,
        'checkPercentage': totalActions > 0 ? (actionCounts['check']! / totalActions * 100) : 0.0,
        'positionHandsPlayed': <String, int>{},
      };
    } catch (e) {
      print('Error calculating statistics: $e');
      return {
        'totalHands': 0,
        'totalSessions': 0,
        'totalActions': 0,
        'vpip': 0.0,
        'pfr': 0.0,
        'aggression': 0.0,
        'foldToBet': 0.0,
        'callPercentage': 0.0,
        'betPercentage': 0.0,
        'raisePercentage': 0.0,
        'foldPercentage': 0.0,
        'checkPercentage': 0.0,
        'positionHandsPlayed': <String, int>{},
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
                        'Playing Style: ${_opponent.playingStyle}',
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
              _buildInfoRow(Icons.person, 'Name', _opponent.name),
              if (_opponent.notes != null && _opponent.notes!.isNotEmpty)
                _buildInfoRow(Icons.note, 'Notes', _opponent.notes!),
              _buildInfoRow(Icons.calendar_today, 'First Seen', 
                  _opponent.createdAt.toString().split(' ')[0]),
              _buildInfoRow(Icons.access_time, 'Last Seen', 
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bar_chart, size: 18, color: Colors.white),
                ),
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
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Hands Played', '${_statistics!['totalHands']}'),
                  ),
                  Expanded(
                    child: _buildStatItem('Sessions', '${_statistics!['totalSessions']}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('VPIP', '${_statistics!['vpip'].toStringAsFixed(1)}%'),
                  ),
                  Expanded(
                    child: _buildStatItem('PFR', '${_statistics!['pfr'].toStringAsFixed(1)}%'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Aggression', _statistics!['aggression'] >= 999 ? '∞' : _statistics!['aggression'].toStringAsFixed(2)),
                  ),
                  Expanded(
                    child: _buildStatItem('Fold %', '${_statistics!['foldPercentage'].toStringAsFixed(1)}%'),
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
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(0xFF161618),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.trending_up, size: 14, color: Color(0xFF9A9A9A)),
                  ),
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
                    child: _buildStatItem('Call', '${_statistics!['callPercentage'].toStringAsFixed(1)}%'),
                  ),
                  Expanded(
                    child: _buildStatItem('Bet', '${_statistics!['betPercentage'].toStringAsFixed(1)}%'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Raise', '${_statistics!['raisePercentage'].toStringAsFixed(1)}%'),
                  ),
                  Expanded(
                    child: _buildStatItem('Check', '${_statistics!['checkPercentage'].toStringAsFixed(1)}%'),
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

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5AC95A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9A9A9A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFF161618),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.history, size: 18, color: Color(0xFF9A9A9A)),
                ),
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
                          Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 20,
                          ),
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
}