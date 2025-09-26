import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/poker_positions.dart';
import '../models/game_types.dart';

class HandActionsScreen extends StatefulWidget {
  final Map<String, dynamic> hand;

  const HandActionsScreen({Key? key, required this.hand}) : super(key: key);

  @override
  _HandActionsScreenState createState() => _HandActionsScreenState();
}

class _HandActionsScreenState extends State<HandActionsScreen> {
  @override
  Widget build(BuildContext context) {
    final actions = List<Map<String, dynamic>>.from(widget.hand['actions'] ?? []);
    final startTime = DateTime.parse(widget.hand['startTime']);
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final playerCount = widget.hand['playerCount'] ?? 6;
    final heroPosition = widget.hand['heroPosition'] ?? 1;
    
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
                    ),
                  ),
                  SizedBox(width: 16),
                  // Hand info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hand #${widget.hand['handNumber'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your Position: ${PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9A9A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hand Summary Cards
                    _buildHandSummaryCards(),
                    
                    SizedBox(height: 24),
                    
                    // Hero Cards and Winner Info
                    _buildHeroCardsAndWinner(),
                    
                    SizedBox(height: 24),
                    
                    // Street-by-street action table
                    _buildStreetByStreetTable(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCardsAndWinner() {
    final ourHoleCardsData = widget.hand['ourHoleCards'];
    final winnerId = widget.hand['winnerId'];
    final playerNamesData = widget.hand['playerNames'];
    
    String? heroCard1;
    String? heroCard2;
    if (ourHoleCardsData != null && ourHoleCardsData is Map) {
      heroCard1 = ourHoleCardsData['card1'];
      heroCard2 = ourHoleCardsData['card2'];
    }
    
    // Get winner name
    String? winnerName;
    if (winnerId != null && playerNamesData != null && playerNamesData is Map) {
      winnerName = playerNamesData[winnerId.toString()];
    }
    
    if ((heroCard1 == null && heroCard2 == null) && winnerId == null) {
      return SizedBox.shrink(); // Don't show section if no data
    }
    
    return Row(
      children: [
        // Hero Cards
        if (heroCard1 != null || heroCard2 != null)
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFF5AC95A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style, color: Color(0xFF5AC95A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Your Cards',
                        style: TextStyle(
                          color: Color(0xFF5AC95A),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (heroCard1 != null) _buildCard(heroCard1),
                      if (heroCard1 != null && heroCard2 != null) SizedBox(width: 12),
                      if (heroCard2 != null) _buildCard(heroCard2),
                    ],
                  ),
                ],
              ),
            ),
          ),
        
        if ((heroCard1 != null || heroCard2 != null) && winnerId != null)
          SizedBox(width: 16),
        
        // Winner Info
        if (winnerId != null || (widget.hand['isChoppedPot'] == true))
          Expanded(
            child: _buildWinnerCard(),
          ),
      ],
    );
  }

  Widget _buildWinnerCard() {
    final isChoppedPot = widget.hand['isChoppedPot'] == true;
    final winnerId = widget.hand['winnerId'];
    final choppedWinners = widget.hand['choppedWinners'] as List<dynamic>?;
    final individualShares = widget.hand['individualShares'] as Map<String, dynamic>?;
    final playerNamesData = widget.hand['playerNames'];
    final potAmount = (widget.hand['potAmount'] ?? 0).toDouble();
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    final heroPosition = widget.hand['heroPosition'];

    String formatAmount(double amount) {
      if (gameTypeStr == 'cash') {
        return '\$${amount.toStringAsFixed(2)}';
      } else {
        return '${amount.toInt()}';
      }
    }

    String getPlayerName(int playerId) {
      if (playerNamesData != null && playerNamesData is Map) {
        return playerNamesData[playerId.toString()] ?? 'Player $playerId';
      }
      return 'Player $playerId';
    }

    // ALWAYS prioritize chopped pot display over single winner
    if (isChoppedPot) {
      // Chopped pot display - get winners from choppedWinners or fallback to winnerId
      List<int> winners = [];
      if (choppedWinners != null && choppedWinners.isNotEmpty) {
        winners = choppedWinners.map((w) => w as int).toList();
      } else if (winnerId != null) {
        // Fallback: if no choppedWinners but marked as chopped, at least show the winnerId
        winners = [winnerId];
      }

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.call_split, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Chopped Pot',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (individualShares != null && individualShares.isNotEmpty) ...[
              ...individualShares.entries.map((entry) {
                final playerId = int.parse(entry.key);
                final amount = (entry.value as num).toDouble();
                final playerName = getPlayerName(playerId);
                final isHero = heroPosition != null && playerId == heroPosition;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isHero)
                            Text(
                              'You won!',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        formatAmount(amount),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else if (winners.isNotEmpty) ...[
              // Fallback to equal shares
              ...winners.map((winnerIdInt) {
                final playerName = getPlayerName(winnerIdInt);
                final shareAmount = potAmount / winners.length;
                final isHero = heroPosition != null && winnerIdInt == heroPosition;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isHero)
                            Text(
                              'You won!',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        formatAmount(shareAmount),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              // No winners data available
              Text(
                'Chopped pot - winner details not available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (winnerId != null) {
      // Single winner display
      final winnerName = getPlayerName(winnerId);
      final isHero = heroPosition != null && winnerId == heroPosition;

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFFFD700)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 20),
                SizedBox(width: 8),
                Text(
                  'Winner',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              winnerName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isHero)
              Text(
                'You won!',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _buildHandSummaryCards() {
    
    final pot = widget.hand['potAmount'] ?? widget.hand['pot'] ?? 0;
    final startTime = DateTime.parse(widget.hand['startTime']);
    
    // Get blinds and game type from session data
    final smallBlind = widget.hand['smallBlind'] ?? 1;
    final bigBlind = widget.hand['bigBlind'] ?? 2;
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    
    // Convert string to GameType enum for proper currency formatting
    final gameType = GameTypeExtension.fromString(gameTypeStr);
    
    // Debug what we're actually getting
    print('🎯 GAME TYPE DEBUG:');
    print('  Raw gameTypeStr: "$gameTypeStr"');
    print('  Converted gameType: ${gameType.name}');
    print('  Should show \$? ${gameType == GameType.cash}');
    
    // Format blinds display - only show $ for cash games
    String blindsText;
    if (gameType == GameType.cash) {
      blindsText = '\$${smallBlind}/\$${bigBlind}';
    } else {
      blindsText = '${smallBlind}/${bigBlind}';
    }
    
    // Format pot display - only show $ for cash games
    String potText;
    if (gameType == GameType.cash) {
      potText = '\$${pot.toStringAsFixed(0)}';
    } else {
      potText = '${pot.toStringAsFixed(0)}';
    }
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Pot Size',
            potText,
            Icons.account_balance_wallet,
            Color(0xFF5AC95A),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Blinds',
            blindsText,
            Icons.visibility,
            Color(0xFF8B5CF6),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Time',
            DateFormat('HH:mm').format(startTime),
            Icons.access_time,
            Color(0xFFFF9500),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 12,
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
    final playerCount = widget.hand['playerCount'] ?? 6;
    final heroPosition = widget.hand['heroPosition'];
    final playerNamesData = widget.hand['playerNames'];
    final winnerId = widget.hand['winnerId'];
    final gameTypeStr = widget.hand['gameType'] ?? 'cash';
    final gameType = GameTypeExtension.fromString(gameTypeStr);
    
    // Parse player names
    Map<String, String> playerNamesMap = {};
    if (playerNamesData != null && playerNamesData is Map) {
      playerNamesData.forEach((key, value) {
        playerNamesMap[key.toString()] = value.toString();
      });
    }
    
    // Parse board cards
    List<String> flop = [];
    String? turn;
    String? river;
    if (boardCardsData != null && boardCardsData is Map) {
      flop = List<String>.from(boardCardsData['flop'] ?? []);
      turn = boardCardsData['turn'] as String?;
      river = boardCardsData['river'] as String?;
    }
    
    // Group actions by street
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
          'Action Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        
        // Preflop
        if (actionsByStreet['preflop']!.isNotEmpty)
          _buildStreetSection('PREFLOP', null, actionsByStreet['preflop']!, 
                            buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['preflopPot']),
        
        // Show board cards - either by street (if there were actions) or combined (if all-in)
        _buildPostflopSections(widget.hand, flop, turn, river, actionsByStreet,
                             buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType),
      ],
    );
  }
  
  Widget _buildStreetSection(String streetName, List<String>? cards, List<Map<String, dynamic>> actions,
                            int buttonPosition, int playerCount, int? heroPosition, 
                            Map<String, String> playerNamesMap, int? winnerId, String gameType, dynamic potAmount) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Street header with cards
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      streetName,
                      style: TextStyle(
                        color: Color(0xFF5AC95A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (cards != null && cards.isNotEmpty) ...[
                      SizedBox(width: 16),
                      ...cards.map((card) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _buildCard(card),
                      )),
                    ],
                  ],
                ),
                // Pot amount on the right side
                if (potAmount != null && (potAmount as double) > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF5AC95A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF5AC95A).withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatPotAmount(potAmount as double, gameType),
                      style: TextStyle(
                        color: Color(0xFF5AC95A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
      padding: EdgeInsets.all(16),
      child: Table(
        columnWidths: {
          0: FlexColumnWidth(2.5), // Player (Position)
          1: FlexColumnWidth(1.5), // Stack
          2: FlexColumnWidth(1.5), // Action
          3: FlexColumnWidth(1), // Amount
        },
        children: [
          // Header row
          TableRow(
            children: [
              _buildTableHeader('PLAYER'),
              _buildTableHeader('STACK'),
              _buildTableHeader('ACTION'),
              _buildTableHeader('AMT'),
            ],
          ),
          // Data rows
          ...actions.map((action) => _buildActionRow(
            action, buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType
          )),
        ],
      ),
    );
  }
  
  Widget _buildTableHeader(String text) {
    return Container(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  // Check if an action is an all-in action
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

    return betAmount >= (stack - 0.01); // Allow for small rounding errors
  }

  // Check if this hand has any all-in actions
  bool _isAllInSituation(Map<String, dynamic> hand) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    return actions.any((action) => _isAllInAction(action));
  }

  // Check if there are any postflop actions
  bool _hasPostflopActions(Map<String, dynamic> hand) {
    final actions = hand['actions'] as List<dynamic>? ?? [];
    return actions.any((action) =>
      action['street'] != null &&
      action['street'].toString().toLowerCase() != 'preflop'
    );
  }

  // Build postflop sections with smart layout for all-in vs regular hands
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

    // If it's an all-in situation with no postflop actions, combine all cards in one section
    if (isAllInSituation && !hasPostflopActions) {
      return _buildCombinedBoardSection(flop, turn, river, gameType);
    } else {
      // Regular situation or all-in with postflop actions: show by street
      return _buildStreetByStreetSections(
        flop, turn, river, actionsByStreet,
        buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType
      );
    }
  }

  // Build combined board section for all-in situations
  Widget _buildCombinedBoardSection(List<String> flop, String? turn, String? river, GameType gameType) {
    // Collect all board cards
    final allCards = <String>[];
    allCards.addAll(flop);
    if (turn != null && turn.isNotEmpty) allCards.add(turn);
    if (river != null && river.isNotEmpty) allCards.add(river);

    if (allCards.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'BOARD',
                  style: TextStyle(
                    color: Color(0xFF5AC95A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Cards
          Container(
            padding: EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: allCards.map((card) => Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  card,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Build street-by-street sections for regular hands
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
        // Flop - show if there are cards (with or without actions)
        if (flop.isNotEmpty)
          _buildStreetSection('FLOP', flop, actionsByStreet['flop']!,
                            buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['flopPot']),

        // Turn - show if there are cards (with or without actions)
        if (turn != null && turn.isNotEmpty)
          _buildStreetSection('TURN', [turn], actionsByStreet['turn']!,
                            buttonPosition, playerCount, heroPosition, playerNamesMap, winnerId, gameType.value, widget.hand['turnPot']),

        // River - show if there are cards (with or without actions)
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
    
    // Get player name
    String playerName = playerNamesMap[playerSeat.toString()] ?? 
                       action['playerName'] as String? ?? 
                       'Player $playerSeat';
    
    final isHero = heroPosition != null && playerSeat == heroPosition;
    final isWinner = winnerId != null && playerSeat == winnerId;
    final positionName = PokerPositions.getPositionName(playerSeat, buttonPosition, playerCount);
    
    // Format player display
    String playerDisplay = isHero ? 'You' : playerName;
    playerDisplay = '$playerDisplay ($positionName)';
    
    // Get action color
    Color actionColor = Color(0xFF9A9A9A);
    switch (actionType.toLowerCase()) {
      case 'fold':
        actionColor = Colors.red;
        break;
      case 'call':
      case 'check':
        actionColor = Color(0xFF5AC95A);
        break;
      case 'raise':
      case 'bet':
        actionColor = Color(0xFFFF9500);
        break;
      case 'all in':
      case 'allin':
        actionColor = Colors.red;
        break;
    }
    
    return TableRow(
      children: [
        // Player column
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (isWinner)
                Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 14),
              if (isWinner) SizedBox(width: 4),
              Expanded(
                child: Text(
                  playerDisplay,
                  style: TextStyle(
                    color: isHero ? Color(0xFF5AC95A) : Colors.white,
                    fontSize: 12,
                    fontWeight: isHero ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Stack column
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            stack > 0 ? '${gameType == GameType.cash ? '\$' : ''}$stack' : '-',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 12,
            ),
          ),
        ),
        // Action column
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _isAllInAction(action) ? 'ALL IN' : actionType.toUpperCase(),
            style: TextStyle(
              color: actionColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Amount column
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            amount != null ? '${gameType == GameType.cash ? '\$' : ''}$amount' : '-',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCard(String? card) {
    if (card == null || card.isEmpty) return SizedBox.shrink();
    
    final suit = card.length > 1 ? card.substring(1) : '';
    final rank = card.isNotEmpty ? card[0] : '';
    
    Color suitColor = Colors.white;
    if (suit == '♥' || suit == '♦') suitColor = Colors.red;
    
    return Container(
      width: 36,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF2A2A2E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            suit,
            style: TextStyle(
              color: suitColor == Colors.red ? Colors.red : Colors.black,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenCard() {
    return Container(
      width: 36,
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3A3A3E)),
      ),
      child: Center(
        child: Icon(
          Icons.help_outline,
          color: Color(0xFF9A9A9A),
          size: 16,
        ),
      ),
    );
  }

  String _formatPotAmount(double amount, String gameType) {
    if (amount <= 0) return '';
    
    final isCashGame = gameType == 'cash';
    
    if (isCashGame) {
      return 'Pot: \$${amount.toStringAsFixed(2)}';
    } else {
      return 'Pot: ${amount.toInt()}';
    }
  }
}