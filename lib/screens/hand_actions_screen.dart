import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../design_system/components/backgrounds/gradient_background.dart';
import '../design_system/components/buttons/glassy_icon_button.dart';
import '../utils/poker_positions.dart';
import '../models/game_types.dart';
import '../services/ai_analyzer_service.dart';
import '../services/firebase_service.dart';

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

  // Star and tags state
  late bool _isStarred;
  late List<String> _tags;
  String? _notes;

  @override
  void initState() {
    super.initState();
    // Initialize star and tags from hand data
    _isStarred = widget.hand['isStarred'] == true;
    _tags = (widget.hand['tags'] as List<dynamic>?)?.cast<String>() ?? [];
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

    // Save to Firebase
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
      // Revert on error
      if (mounted) {
        setState(() {
          _isStarred = !newStarredState;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update star status'),
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
    // Check if hero has hole cards
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;

    if (card1 == null || card2 == null || card1.isEmpty || card2.isEmpty) {
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF1F1F23),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text(
                  'Missing Hero Cards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'AI analysis requires your hole cards to be recorded. This hand cannot be analyzed because hero cards are missing.',
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFF5AC95A),
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
      // Prepare hand data for analysis
      final handData = AIAnalyzerService.prepareHandDataForAnalysis(widget.hand);

      // Call AI analyzer
      final analysis = await AIAnalyzerService.analyzeHand(
        handId: handData['handId'] as String,
        handData: handData,
      );

      // Save to Firebase
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

        // Auto-scroll to show the analysis results
        Future.delayed(Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 500),
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

  @override
  Widget build(BuildContext context) {
    final actions = List<Map<String, dynamic>>.from(widget.hand['actions'] ?? []);
    final startTime = DateTime.parse(widget.hand['startTime']);
    final buttonPosition = widget.hand['buttonPosition'] ?? 1;
    final playerCount = widget.hand['playerCount'] ?? 6;
    // New fields for position tracking
    final heroPositionName = widget.hand['heroPositionName'] as String?;
    final heroSeatNumber = widget.hand['heroSeatNumber'] as int?;
    // Old field for backward compatibility - prefer widget.ourSeat from navigation
    final heroPosition = widget.ourSeat ?? heroSeatNumber ?? widget.hand['heroPosition'] ?? 1;
    
    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: Stack(
        children: [
          GradientBackground(),
          SafeArea(
            child: Column(
          children: [
            // Glassmorphic Header
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Color(0x03FFFFFF),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      GlassyIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 12),
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your Position: ${heroPositionName ?? PokerPositions.getPositionName(heroPosition, buttonPosition, playerCount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Star button
                      GestureDetector(
                        onTap: _toggleStar,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isStarred ? Color(0x33FFD700) : Color(0x1AFFFFFF),
                            borderRadius: BorderRadius.circular(10),
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
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags row (if any)
                    if (_tags.isNotEmpty) ...[
                      _buildTagsSection(),
                      SizedBox(height: 12),
                    ],

                    // Notes section (if any)
                    if (_notes != null && _notes!.isNotEmpty) ...[
                      _buildNotesSection(),
                      SizedBox(height: 12),
                    ],

                    // Hand Summary Stats (compact)
                    _buildHandSummaryCards(),

                    SizedBox(height: 16),

                    // Hero Cards and Winner Info
                    _buildHeroCardsAndWinner(),

                    SizedBox(height: 16),

                    // Street-by-street action table
                    _buildStreetByStreetTable(),

                    SizedBox(height: 16),

                    // AI Analyzer Button
                    _buildAIAnalyzerButton(),

                    // AI Analysis Results
                    if (_aiAnalysis != null) ...[
                      SizedBox(height: 16),
                      _buildAIAnalysisResults(),
                    ],

                    // Analysis Error
                    if (_analysisError != null) ...[
                      SizedBox(height: 16),
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

    // Get opponent cards from showdown data
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
      return SizedBox.shrink(); // Don't show section if no data
    }

    return Row(
      children: [
        // Hero Cards
        if (hasHeroCards)
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF5AC95A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.style, color: Color(0xFF5AC95A), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Your Cards',
                        style: TextStyle(
                          color: Color(0xFF5AC95A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (heroCard1 != null) _buildCard(heroCard1),
                      if (heroCard1 != null && heroCard2 != null) SizedBox(width: 8),
                      if (heroCard2 != null) _buildCard(heroCard2),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (hasHeroCards && hasOpponentCards)
          SizedBox(width: 12),

        // Opponent Cards (replaces Winner Card)
        if (hasOpponentCards)
          Expanded(
            child: _buildOpponentCardsCard(opponentCards!, playerNamesData),
          ),
      ],
    );
  }

  Widget _buildOpponentCardsCard(Map<int, Map<String, String?>> opponentCards, dynamic playerNamesData) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF8B5CF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Color(0xFF8B5CF6), size: 16),
              SizedBox(width: 6),
              Text(
                'Opponent Cards',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Show each opponent's cards
          ...opponentCards.entries.map((entry) {
            final playerId = entry.key;
            final cards = entry.value;
            final card1 = cards['card1'];
            final card2 = cards['card2'];

            if (card1 == null || card2 == null) {
              return SizedBox.shrink();
            }

            String? playerName;
            if (playerNamesData != null && playerNamesData is Map) {
              playerName = playerNamesData[playerId.toString()];
            }
            playerName ??= 'Player $playerId';

            return Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      playerName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6),
                  _buildSmallCard(card1),
                  SizedBox(width: 4),
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
        border: Border.all(color: Colors.grey[300]!),
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

    // Format values
    String potText = gameType == GameType.cash
        ? '\$${pot.toStringAsFixed(0)}'
        : '${pot.toStringAsFixed(0)}';
    String blindsText = gameType == GameType.cash
        ? '\$${smallBlind}/\$${bigBlind}'
        : '${smallBlind}/${bigBlind}';
    String? winnerText = _getWinnerText();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCompactStat('POT', potText)),
          Container(width: 1, height: 32, color: Color(0xFF2A2A2E)),
          Expanded(child: _buildCompactStat('BLINDS', blindsText)),
          if (winnerText != null) ...[
            Container(width: 1, height: 32, color: Color(0xFF2A2A2E)),
            Expanded(child: _buildCompactStat('WINNER', winnerText, isWinner: true)),
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
      if (choppedWinners.length <= 2) {
        List<String> names = choppedWinners.map((w) {
          if (playerNamesData is Map) {
            return (playerNamesData[w.toString()] ?? 'P$w') as String;
          }
          return 'P$w';
        }).toList();
        return names.join(', ');
      }
      return '${choppedWinners.length} players';
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
          style: TextStyle(
            color: isWinner ? Color(0xFFFFD700) : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF9A9A9A),
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
    // Get icon for tag
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFBAFF9A).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFBAFF9A).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tagIcon,
            size: 14,
            color: Color(0xFFBAFF9A),
          ),
          SizedBox(width: 6),
          Text(
            tag,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFBAFF9A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: Color(0xFF9A9A9A), size: 18),
              SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _notes!,
            style: TextStyle(
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
    final playerCount = widget.hand['playerCount'] ?? 6;
    final heroPosition = widget.ourSeat ?? widget.hand['heroPosition'];
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
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2A2A2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Street header with cards
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (cards != null && cards.isNotEmpty) ...[
                      SizedBox(width: 12),
                      ...cards.map((card) => Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: _buildCard(card),
                      )),
                    ],
                  ],
                ),
                // Pot amount on the right side
                if (potAmount != null && (potAmount as double) > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF5AC95A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Color(0xFF5AC95A).withOpacity(0.3)),
                    ),
                    child: Text(
                      _formatPotAmount(potAmount as double, gameType),
                      style: TextStyle(
                        color: Color(0xFF5AC95A),
                        fontSize: 11,
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
      padding: EdgeInsets.all(10),
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
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 10,
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
    // CRITICAL: Use saved position from action (calculated with active seats during hand)
    // DO NOT recalculate with playerCount=9 as it will give wrong positions
    final positionName = action['playerPosition'] as String? ??
                        PokerPositions.getPositionName(playerSeat, buttonPosition, playerCount);
    
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
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              if (isWinner)
                Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 12),
              if (isWinner) SizedBox(width: 3),
              Expanded(
                child: Text(
                  playerDisplay,
                  style: TextStyle(
                    color: isHero ? Color(0xFF5AC95A) : Colors.white,
                    fontSize: 11,
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
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            stack > 0 ? '${gameType == GameType.cash ? '\$' : ''}$stack' : '-',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 11,
            ),
          ),
        ),
        // Action column
        Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _isAllInAction(action) ? 'ALL IN' : actionType.toUpperCase(),
            style: TextStyle(
              color: actionColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Amount column
        Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            amount != null ? '${gameType == GameType.cash ? '\$' : ''}$amount' : '-',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 11,
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
      width: 30,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFF2A2A2E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: Offset(0, 1),
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
          SizedBox(height: 1),
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

  String _formatPotAmount(double amount, String gameType) {
    if (amount <= 0) return '';

    final isCashGame = gameType == 'cash';

    if (isCashGame) {
      return 'Pot: \$${amount.toStringAsFixed(2)}';
    } else {
      return 'Pot: ${amount.toInt()}';
    }
  }

  Color _getCardColor(String card) {
    if (card.contains('♥') || card.contains('♦')) {
      return Colors.red;
    }
    return Colors.black;
  }

  Widget _buildAIAnalyzerButton() {
    // Check if hero has hole cards
    final ourHoleCards = widget.hand['ourHoleCards'] as Map<String, dynamic>?;
    final card1 = ourHoleCards?['card1'] as String?;
    final card2 = ourHoleCards?['card2'] as String?;
    final hasHeroCards = card1 != null && card2 != null && card1.isNotEmpty && card2.isNotEmpty;

    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isAnalyzing || !hasHeroCards) ? null : _analyzeHand,
        style: ElevatedButton.styleFrom(
          backgroundColor: !hasHeroCards
              ? Color(0xFF9A9A9A)
              : (_aiAnalysis != null ? Color(0xFF8B5CF6) : Color(0xFF5AC95A)),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          disabledBackgroundColor: Color(0xFF9A9A9A).withOpacity(0.3),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Analyzing Hand...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (!hasHeroCards) ...[
              Icon(
                Icons.block,
                color: Color(0xFF9A9A9A),
              ),
              SizedBox(width: 12),
              Text(
                'Hero Cards Missing',
                style: TextStyle(
                  color: Color(0xFF9A9A9A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Icon(
                _aiAnalysis != null ? Icons.refresh : Icons.psychology,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Text(
                _aiAnalysis != null ? 'Re-analyze Hand' : 'AI Analyzer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisError() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Failed',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _analysisError ?? 'Unknown error',
                  style: TextStyle(
                    color: Color(0xFF9A9A9A),
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
    if (_aiAnalysis == null) return SizedBox.shrink();

    final correct = _aiAnalysis!['correct'] as bool? ?? false;
    final severity = _aiAnalysis!['severity'] as String? ?? 'unknown';
    final scenarioCovered = _aiAnalysis!['scenarioCovered'] as bool? ?? true;
    final gtoAnalysis = _aiAnalysis!['gtoAnalysis'] as Map<String, dynamic>?;
    final aiAnalysis = _aiAnalysis!['aiAnalysis'] as Map<String, dynamic>?;
    final processingTime = _aiAnalysis!['processingTimeMs'] as int? ?? 0;

    // Determine if this is a preflop-only hand or went postflop
    final actions = List<Map<String, dynamic>>.from(widget.hand['actions'] ?? []);
    final wentPostflop = actions.any((action) {
      final street = action['street'] as String? ?? 'preflop';
      return street != 'preflop';
    });

    Color severityColor;
    IconData severityIcon;
    switch (severity.toLowerCase()) {
      case 'optimal':
        severityColor = Color(0xFF5AC95A);
        severityIcon = Icons.check_circle;
        break;
      case 'minor':
        severityColor = Color(0xFFFFD700);
        severityIcon = Icons.warning;
        break;
      case 'major':
        severityColor = Colors.orange;
        severityIcon = Icons.error;
        break;
      case 'critical':
        severityColor = Colors.red;
        severityIcon = Icons.dangerous;
        break;
      default:
        severityColor = Color(0xFF9A9A9A);
        severityIcon = Icons.help;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'AI Analysis',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),

        // Overall Result
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color(0xFF1F1F23),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: severityColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(severityIcon, color: severityColor, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          correct ? 'Correct Play' : 'Mistake Detected',
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Severity: ${severity.toUpperCase()}',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // AI Analysis
        if (aiAnalysis != null) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF1F1F23),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFF2A2A2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Color(0xFF5AC95A), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Insights (Preflop Only)',
                        style: TextStyle(
                          color: Color(0xFF5AC95A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Show range % when available
                    if (scenarioCovered && gtoAnalysis != null && gtoAnalysis['rangePercentile'] != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF8B5CF6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF8B5CF6).withOpacity(0.3)),
                        ),
                        child: Text(
                          'Range: ${gtoAnalysis['rangePercentile']}%',
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12),
                if (aiAnalysis['reasoning'] != null) ...[
                  Text(
                    aiAnalysis['reasoning'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                if (aiAnalysis['optimalAction'] != null) ...[
                  _buildHighlightedText('Optimal Play', aiAnalysis['optimalAction']),
                  SizedBox(height: 12),
                ],
                if (aiAnalysis['exploitativeAdjustment'] != null) ...[
                  _buildHighlightedText('Exploitative Adjustment', aiAnalysis['exploitativeAdjustment']),
                  SizedBox(height: 12),
                ],
                if (aiAnalysis['learningPoint'] != null) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            aiAnalysis['learningPoint'],
                            style: TextStyle(
                              color: Color(0xFFFFD700),
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

        // Processing Time
        SizedBox(height: 12),
        Center(
          child: Text(
            'Analysis completed in ${(processingTime / 1000).toStringAsFixed(2)}s',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedText(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Color(0xFF5AC95A),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}