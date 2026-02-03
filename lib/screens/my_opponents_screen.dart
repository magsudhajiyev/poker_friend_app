import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../widgets/global_loading_spinner.dart';
import '../widgets/global_bottom_nav_bar.dart';
import 'opponent_detail_screen.dart';
import '../design_system/design_system.dart';

class MyOpponentsScreen extends StatefulWidget {
  @override
  _MyOpponentsScreenState createState() => _MyOpponentsScreenState();
}

class _MyOpponentsScreenState extends State<MyOpponentsScreen> {
  List<Opponent> opponents = [];
  Map<String, int> opponentHandsCounts = {}; // Fast lookup for hands count
  Map<String, OpponentStats> opponentStats = {}; // Fast lookup for stats (playingStyle, playerType)
  bool isLoading = true;
  String? error;
  String searchQuery = '';

  // In-memory cache to avoid reloading on every screen visit
  static List<Opponent>? _cachedOpponents;
  static Map<String, int>? _cachedHandsCounts;
  static Map<String, OpponentStats>? _cachedStats;

  @override
  void initState() {
    super.initState();
    _loadOpponents(useCache: true);
  }

  Future<void> _loadOpponents({bool useCache = false}) async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Use cache if available and requested
      if (useCache && _cachedOpponents != null && _cachedHandsCounts != null && _cachedStats != null) {
        setState(() {
          opponents = _cachedOpponents!;
          opponentHandsCounts = _cachedHandsCounts!;
          opponentStats = _cachedStats!;
          isLoading = false;
        });
        return;
      }

      // Load basic opponent data (name, color, notes, dates) - fast operation
      final loadedOpponents = await OpponentService.getAllOpponents();

      // PARALLEL LOADING: Load all opponent stats simultaneously instead of sequentially
      // Use opponent.id (not name) since stats are stored by ID in Firebase
      final statsFutures = loadedOpponents.map((opponent) =>
        OpponentStatsService.getOpponentStats(opponent.id)
      ).toList();

      final allStats = await Future.wait(statsFutures);

      // Build lookup maps keyed by opponent ID
      final handsCounts = <String, int>{};
      final statsMap = <String, OpponentStats>{};
      for (int i = 0; i < loadedOpponents.length; i++) {
        final opponent = loadedOpponents[i];
        final stats = allStats[i];
        handsCounts[opponent.id] = stats?.handsPlayed ?? 0;
        if (stats != null) {
          statsMap[opponent.id] = stats;
        }
      }

      // Cache the results
      _cachedOpponents = loadedOpponents;
      _cachedHandsCounts = handsCounts;
      _cachedStats = statsMap;

      setState(() {
        opponents = loadedOpponents;
        opponentHandsCounts = handsCounts;
        opponentStats = statsMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load opponents: $e';
        isLoading = false;
      });
    }
  }

  List<Opponent> get filteredOpponents {
    if (searchQuery.isEmpty) return opponents;
    return opponents.where((opponent) {
      final nameMatch = opponent.name.toLowerCase().contains(searchQuery.toLowerCase());
      final stats = opponentStats[opponent.id];
      final styleMatch = stats?.playingStyle.toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
      return nameMatch || styleMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Gradient background from design system
          GradientBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with title + back/add buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Title + subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Opponents',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.48,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '${opponents.length} tracked players',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFFFFFFFF).withOpacity(0.8),
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.24,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      // Right: Back + Add buttons
                      Row(
                        children: [
                          GlassyIconButton(
                            imagePath: 'icons/flat_icons/back.png',
                            onPressed: () => Navigator.pop(context),
                          ),
                          SizedBox(width: 4),
                          GlassyIconButton(
                            imagePath: 'icons/flat_icons/plus.png',
                            onPressed: _showAddOpponentDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search bar - Fixed (pill shape with border)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 24),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A2925),
                      borderRadius: BorderRadius.circular(90),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Inter',
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search opponents...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontFamily: 'Inter',
                        ),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Image.asset(
                            'icons/flat_icons/search.png',
                            width: 20,
                            height: 20,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),

                // Scrollable opponent cards list
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'opponents'),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: GlobalLoadingSpinner(
          message: 'Loading opponents...',
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.error, color: Colors.red, size: 32),
            ),
            SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 14),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOpponents,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFcb5242),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final displayOpponents = filteredOpponents;

    if (displayOpponents.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 280),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon section
              Image.asset(
                'icons/flat_icons/people.png',
                width: 44,
                height: 44,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              // Text section with horizontal padding
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 62),
                child: Column(
                  children: [
                    Text(
                      searchQuery.isEmpty ? 'No Opponents Yet' : 'No Results',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.5, // line-height: 24px / 16px
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      searchQuery.isEmpty
                        ? 'Add opponents to track their playing styles and statistics!'
                        : 'Try a different search term',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFFF8FFF7),
                        fontWeight: FontWeight.w400,
                        height: 1.5, // line-height: 18px / 12px
                      ),
                    ),
                  ],
                ),
              ),
              if (searchQuery.isEmpty) ...[
                SizedBox(height: 50),
                // Button section
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _showAddOpponentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFBAFF9A), // --secondary-100
                      foregroundColor: Color(0xFF011100), // --primary-100
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add Opponent',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF011100), // --primary-100
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 20),
      itemCount: displayOpponents.length,
      itemBuilder: (context, index) {
        final opponent = displayOpponents[index];
        return _buildOpponentCard(opponent);
      },
    );
  }

  Widget _buildOpponentCard(Opponent opponent) {
    final cardColor = _getColorForOpponent(opponent.color);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1A2925),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OpponentDetailScreen(opponent: opponent),
              ),
            );
            // Only reload if opponent was modified (invalidate cache)
            if (result == true) {
              _loadOpponents(useCache: false);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Column(
              children: [
                // Top section: User info + hands count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: CardIcon + Name/Style
                    Row(
                      children: [
                        // Color indicator avatar (28px solid circle)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: cardColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        // Name and playing style column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opponent.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18,
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              opponentStats[opponent.id]?.playingStyle ?? 'No Data',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: _getStyleColor(opponentStats[opponent.id]?.playerType ?? PlayerType.unknown),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Right: Hands count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${opponentHandsCounts[opponent.id] ?? 0}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          'Hands',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Bottom section: Last seen + action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Last seen
                    Row(
                      children: [
                        Image.asset(
                          'icons/flat_icons/eye.png',
                          width: 18,
                          height: 18,
                          color: Color(0xFFFFFFFF).withOpacity(0.8),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Last Seen: ${DateFormat('MMM dd').format(opponent.lastSeenAt)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(0xFFFFFFFF).withOpacity(0.8),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    // Right: Action buttons
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showEditOpponentDialog(opponent),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFF1A291A), // --primary-90
                              borderRadius: BorderRadius.circular(70),
                            ),
                            child: Center(
                              child: Image.asset(
                                'icons/flat_icons/edit.png',
                                width: 20,
                                height: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showDeleteConfirmation(opponent),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(0xFFB63131),
                              borderRadius: BorderRadius.circular(70),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x33000000), // #00000033
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'icons/flat_icons/bin.png',
                                width: 20,
                                height: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Color _getStyleColor(PlayerType playerType) {
    switch (playerType) {
      case PlayerType.tightAggressive:
      case PlayerType.tagRegular:
        return Colors.green;
      case PlayerType.looseAggressive:
        return Colors.orange;
      case PlayerType.tightPassive:
        return Colors.blue;
      case PlayerType.loosePassive:
      case PlayerType.calling_station:
        return Colors.red;
      case PlayerType.maniac:
        return Colors.purple;
      case PlayerType.unknown:
        return Colors.grey;
    }
  }

  void _showAddOpponentDialog() {
    _showOpponentDialog();
  }

  void _showEditOpponentDialog(Opponent opponent) {
    _showOpponentDialog(opponent: opponent);
  }

  void _showOpponentDialog({Opponent? opponent}) {
    final isEditing = opponent != null;
    final nameController = TextEditingController(text: opponent?.name ?? '');
    final notesController = TextEditingController(text: opponent?.notes ?? '');
    OpponentColor selectedColor = opponent?.color ?? OpponentColor.blue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: Navigator.of(context) as TickerProvider,
      )..forward(),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF1a2925),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle line
                      Container(
                        width: 80,
                        height: 2,
                        margin: EdgeInsets.only(top: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),

                      SizedBox(height: 38),

                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isEditing ? 'Edit Opponent' : 'Add Opponent',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Input fields
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // Opponent Name field
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: nameController,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Opponent Name',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 18),

                            // Notes field
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: notesController,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Notes (Optional)',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                maxLines: 6,
                                maxLength: null,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Color picker section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick a color:',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.28,
                              ),
                            ),
                            SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: OpponentColor.values.map((color) {
                                final isSelected = selectedColor == color;
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getColorForOpponent(color),
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 56),

                      // Update button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;

                              try {
                                final newOpponent = isEditing
                                    ? opponent!.copyWith(
                                        name: name,
                                        notes: notesController.text.trim().isEmpty
                                            ? null
                                            : notesController.text.trim(),
                                        color: selectedColor,
                                      )
                                    : OpponentService.createNewOpponent(
                                        name: name,
                                        notes: notesController.text.trim().isEmpty
                                            ? null
                                            : notesController.text.trim(),
                                        color: selectedColor,
                                      );

                                await OpponentService.saveOpponent(newOpponent);
                                Navigator.pop(context);
                                _loadOpponents(useCache: false);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isEditing
                                        ? 'Opponent updated successfully'
                                        : 'Opponent added successfully'),
                                    backgroundColor: Color(0xFFA5EC44),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFA5EC44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isEditing ? 'Update' : 'Add Opponent',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Cancel button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }




  void _showDeleteConfirmation(Opponent opponent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main card with title, description, and delete button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF131613), // --background
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    // Title
                    Text(
                      'Delete opponents?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 24),
                    // Description
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Are you sure you want to delete "${opponent.name}"?\nThis action can not be undone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.24,
                          height: 1.7,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Divider line
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    // Delete button
                    GestureDetector(
                      onTap: () async {
                        try {
                          await OpponentService.deleteOpponent(opponent.id);
                          Navigator.pop(context);
                          _loadOpponents(useCache: false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Opponent deleted successfully'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting opponent: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        child: Text(
                          'Delete',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD55A41), // --error
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              // Cancel button (separate card)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFF131613), // --background
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalyticsDialog() async {
    final analytics = await OpponentService.getOpponentAnalytics();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Opponent Analytics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Total Opponents', '${analytics['totalOpponents']}'),
              _buildDetailRow('Total Hands Tracked', '${analytics['totalHandsTracked']}'),
              _buildDetailRow('Average Hands/Opponent', '${analytics['averageHands']}'),
              if (analytics['mostPlayedAgainst'] != null)
                _buildDetailRow('Most Played Against', analytics['mostPlayedAgainst']),
              SizedBox(height: 16),
              Text('Player Type Distribution:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...(analytics['playerTypeDistribution'] as Map<String, int>).entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key, style: TextStyle(fontSize: 12))),
                      Text('${entry.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All Opponents?'),
          ],
        ),
        content: Text('This will permanently delete all opponent data. This action cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await OpponentService.clearAllOpponents();
                Navigator.pop(context);
                _loadOpponents(useCache: false); // Invalidate cache
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All opponents cleared'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error clearing opponents: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}