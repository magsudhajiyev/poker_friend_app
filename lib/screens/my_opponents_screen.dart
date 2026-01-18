import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../widgets/global_loading_spinner.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../widgets/global_top_header.dart';
import 'opponent_detail_screen.dart';

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
      final statsFutures = loadedOpponents.map((opponent) =>
        OpponentStatsService.getOpponentStats(opponent.name)
      ).toList();

      final allStats = await Future.wait(statsFutures);

      // Build lookup maps
      final handsCounts = <String, int>{};
      final statsMap = <String, OpponentStats>{};
      for (int i = 0; i < loadedOpponents.length; i++) {
        final opponent = loadedOpponents[i];
        final stats = allStats[i];
        handsCounts[opponent.name] = stats?.handsPlayed ?? 0;
        if (stats != null) {
          statsMap[opponent.name] = stats;
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
      final stats = opponentStats[opponent.name];
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
          // Green gradient background overlay at top
          Positioned(
            left: -98,
            top: -148,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 132, sigmaY: 132),
                child: Container(
                  width: 595,
                  height: 727,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFABFFB4).withOpacity(0.6),
                        const Color(0xFF006434).withOpacity(0.6),
                        const Color(0xFF000000).withOpacity(0.6),
                      ],
                      stops: [0.0, 0.32, 1.0],
                    ),
                    borderRadius: BorderRadius.all(Radius.elliptical(297.5, 363.5)),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar - Fixed
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: GlobalTopHeader(currentScreen: 'opponents'),
                ),
                const SizedBox(height: 28),

                // Opponents Header Section - Fixed
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Opponents',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.56,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                '${opponents.length} tracked players',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: Color(0xFFFFFFFF).withOpacity(0.8),
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.32,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add opponent button
                        GestureDetector(
                          onTap: _showAddOpponentDialog,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar - Fixed
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(0xFF546165).withOpacity(0.74),
                            borderRadius: BorderRadius.circular(12),
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
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(Icons.people_outline, color: Color(0xFF9A9A9A), size: 32),
            ),
            SizedBox(height: 16),
            Text(
              searchQuery.isEmpty ? 'No Opponents Yet' : 'No Results',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              searchQuery.isEmpty 
                ? 'Add opponents to track their playing styles and statistics!'
                : 'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 16,
              ),
            ),
            if (searchQuery.isEmpty) ...[
              SizedBox(height: 16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFcb5242), Color(0xFFb8442f)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: _showAddOpponentDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  icon: Icon(Icons.person_add, color: Colors.white),
                  label: Text(
                    'Add Opponent',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF546165).withOpacity(0.74),
              borderRadius: BorderRadius.circular(12),
            ),
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
                            // Color indicator avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(55),
                              ),
                              child: Center(
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
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
                                    color: Color(0xFFFFFFFF).withOpacity(0.84),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                    height: 1.4,
                                  ),
                                ),
                                Text(
                                  opponentStats[opponent.name]?.playingStyle ?? 'No Data',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: _getStyleColor(opponentStats[opponent.name]?.playerType ?? PlayerType.unknown).withOpacity(0.84),
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
                              '${opponentHandsCounts[opponent.name] ?? 0}',
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
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
                            Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: Color(0xFFFFFFFF).withOpacity(0.84),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Last Seen: ${DateFormat('MMM dd').format(opponent.lastSeenAt)}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFFFFFFFF).withOpacity(0.84),
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
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 28.5,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(Icons.edit, size: 18, color: Colors.white),
                                onPressed: () => _showEditOpponentDialog(opponent),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Color(0xFFB63131),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 28.5,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(Icons.delete, size: 18, color: Colors.white),
                                onPressed: () => _showDeleteConfirmation(opponent),
                                padding: EdgeInsets.zero,
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
                              'Update',
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Opponent?'),
        content: Text('Are you sure you want to delete "${opponent.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await OpponentService.deleteOpponent(opponent.id);
                Navigator.pop(context);
                _loadOpponents(useCache: false); // Invalidate cache
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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