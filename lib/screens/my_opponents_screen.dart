import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/opponent.dart';
import '../models/opponent_stats.dart';
import '../services/opponent_service.dart';
import '../services/opponent_stats_service.dart';
import '../widgets/global_loading_spinner.dart';
import '../widgets/global_bottom_nav_bar.dart';
import 'opponent_detail_screen.dart';
import 'opponent_hands_screen.dart';
import '../design_system/components/drawer_dots.dart';
import '../design_system/components/form_drawer.dart';
import '../design_system/components/cards/error_state_card.dart';
import '../services/app_data_cache.dart';

class MyOpponentsScreen extends StatefulWidget {
  // Static cache accessible from other screens
  static List<Opponent>? _cachedOpponents;
  static Map<String, int>? _cachedHandsCounts;
  static Map<String, OpponentStats>? _cachedStats;

  /// Clear the static cache - call this when opponents are added/modified from other screens
  static void invalidateCache() {
    _cachedOpponents = null;
    _cachedHandsCounts = null;
    _cachedStats = null;
  }

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

  @override
  void initState() {
    super.initState();
    _loadOpponents(useCache: !AppDataCache.isOpponentsDirty);
  }

  Future<void> _loadOpponents({bool useCache = false}) async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Use cache if available and requested
      if (useCache && MyOpponentsScreen._cachedOpponents != null && MyOpponentsScreen._cachedHandsCounts != null && MyOpponentsScreen._cachedStats != null) {
        setState(() {
          opponents = MyOpponentsScreen._cachedOpponents!;
          opponentHandsCounts = MyOpponentsScreen._cachedHandsCounts!;
          opponentStats = MyOpponentsScreen._cachedStats!;
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
      MyOpponentsScreen._cachedOpponents = loadedOpponents;
      MyOpponentsScreen._cachedHandsCounts = handsCounts;
      MyOpponentsScreen._cachedStats = statsMap;
      AppDataCache.clearOpponentsDirty();

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

  Widget _buildIcon(String path, double size, Color color) {
    if (path.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Subtle teal gradient at top (like home screen)
          Positioned(
            top: -screenWidth * 0.3,
            right: -screenWidth * 0.25,
            child: Transform.scale(
              scaleX: 1.0,
              scaleY: 0.7,
              child: Container(
                width: screenWidth * 1.5,
                height: screenWidth * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [
                      Color(0xFF1A4A4A),
                      Color(0xFF133538).withOpacity(0.7),
                      Color(0xFF133538).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with back arrow + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    children: [
                      // Back button on LEFT
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Opponents',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${opponents.length} tracked players',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 15,
                                color: Color(0xFFEBEBF5).withOpacity(0.6),
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add opponent button on RIGHT
                      GestureDetector(
                        onTap: _showAddOpponentDialog,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF89F1EC),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search bar (Figma node 27-3112)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF1F272F)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/search.svg',
                              15,
                              const Color(0xFFADF9F5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              height: 1.44,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search opponents...',
                              hintStyle: GoogleFonts.ibmPlexSans(
                                color: const Color(0xFF8C8C8C),
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                height: 1.44,
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ],
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
      return ErrorStateCard(onRetry: () => _loadOpponents(useCache: false));
    }

    final displayOpponents = filteredOpponents;

    if (displayOpponents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF101115),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              _buildIcon(
                'icons/figma_icons/opponents.svg',
                24,
                const Color(0xFF89F1EC),
              ),
              const SizedBox(height: 6),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  searchQuery.isEmpty ? 'No Opponents Yet' : 'No Results',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
              ),
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  searchQuery.isEmpty
                    ? 'Opponents to track their playing styles and statistics'
                    : 'Try a different search term',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: const Color(0xFFB3B4B6),
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
              ),
              if (searchQuery.isEmpty) ...[
                const SizedBox(height: 24),
                // Add Opponent button
                GestureDetector(
                  onTap: _showAddOpponentDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(110),
                      border: Border.all(
                        color: const Color(0xFF75A6CB),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Opponent',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 24 / 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100), // Extra padding for nav bar
      itemCount: displayOpponents.length,
      itemBuilder: (context, index) {
        final opponent = displayOpponents[index];
        return _buildOpponentCard(opponent);
      },
    );
  }

  /// Get initials (first two letters of the name, or first letter of each word)
  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }

  Widget _buildOpponentCard(Opponent opponent) {
    final cardColor = _getColorForOpponent(opponent.color);
    final dotsKey = GlobalKey();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black),
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
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              children: [
                // Top row: Avatar + Name/LastSeen + dots menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar: 40x40 rounded square with initials
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(opponent.name),
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Name + Last Seen
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Player name
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              opponent.name,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                height: 1.44,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          // Last Seen row
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Color(0xFF4E5054),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Last Seen: ${DateFormat('MMM dd, h:mm a').format(opponent.lastSeenAt)}',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  color: Color(0xFF4E5054),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Dots menu icon
                    SizedBox(
                      key: dotsKey,
                      child: DrawerDots(
                        onTap: () => _showOpponentOptionsMenu(opponent, dotsKey),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14),

                // Separator line
                Container(
                  height: 1,
                  color: Color(0xFF1C1F21),
                ),

                SizedBox(height: 14),

                // Hands row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hands',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Color(0xFFB3B4B6),
                        fontWeight: FontWeight.w500,
                        height: 1.44,
                      ),
                    ),
                    Text(
                      '${OpponentHandsScreen.filteredHandCounts[opponent.id] ?? opponentHandsCounts[opponent.id] ?? 0}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Color(0xFFD3FFFD),
                        fontWeight: FontWeight.w500,
                        height: 1.44,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Notes row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        opponent.notes?.isNotEmpty == true
                            ? opponent.notes!
                            : 'Notes (Optional)',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Color(0xFF8C8C8C),
                          fontWeight: FontWeight.w500,
                          height: 1.44,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  void _showOpponentOptionsMenu(Opponent opponent, GlobalKey dotsKey) {
    // Get position of the dots icon
    final RenderBox renderBox = dotsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // Calculate menu position: top-right of menu aligns with center-right of dots icon
    final screenWidth = MediaQuery.of(context).size.width;
    final dotsRight = screenWidth - (offset.dx + size.width);
    final menuTop = offset.dy + size.height + 4; // Just below the dots icon

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Positioned popup menu (Figma node 622:5241)
          Positioned(
            right: dotsRight, // Align right edge with dots icon right edge
            top: menuTop, // Below center of dots icon
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 184,
                decoration: BoxDecoration(
                  color: Color(0xFF02050B),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 34,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edit Opponent row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showEditOpponentDialog(opponent);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          _buildIcon(
                            'icons/figma_icons/edit.svg',
                            16,
                            Colors.white,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Edit Opponent',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Separator
                    Container(
                      height: 1,
                      color: Color(0xFF1C1F21),
                    ),
                    // Delete Opponent row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(opponent);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          _buildIcon(
                            'icons/figma_icons/delete.svg',
                            16,
                            Color(0xFFD55A41),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Delete Opponent',
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
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
            ),
          ),
        ],
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
    final colorPickerKey = GlobalKey();

    // Color name mapping
    String getColorName(OpponentColor color) {
      switch (color) {
        case OpponentColor.red: return 'Red';
        case OpponentColor.blue: return 'Light Blue';
        case OpponentColor.green: return 'Green';
        case OpponentColor.orange: return 'Orange';
        case OpponentColor.purple: return 'Purple';
        case OpponentColor.teal: return 'Teal';
        case OpponentColor.pink: return 'Pink';
        case OpponentColor.indigo: return 'Indigo';
      }
    }

    void showColorPicker(StateSetter setSheetState) {
      final colors = OpponentColor.values;

      // Get the position of the color picker row
      final RenderBox renderBox = colorPickerKey.currentContext!.findRenderObject() as RenderBox;
      final Offset offset = renderBox.localToGlobal(Offset.zero);

      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) {
          return Stack(
            children: [
              // Dismiss on tap outside
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Positioned dropdown
              Positioned(
                right: 32,
                top: offset.dy,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 184,
                    decoration: BoxDecoration(
                      color: Color(0xFF161619),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 34,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...colors.asMap().entries.map((entry) {
                          final index = entry.key;
                          final color = entry.value;
                          final isSelected = color == selectedColor;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  setSheetState(() {
                                    selectedColor = color;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      if (isSelected) ...[
                                        Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                      ],
                                      Container(
                                        width: 16,
                                        height: 16,
                                        margin: EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _getColorForOpponent(color),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        getColorName(color),
                                        style: GoogleFonts.ibmPlexSans(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (index < colors.length - 1)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    Future<void> saveOpponent() async {
      final name = nameController.text.trim();
      if (name.isEmpty) return;

      try {
        final newOpponent = isEditing
            ? opponent!.copyWith(
                name: name,
                notes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
                clearNotes: notesController.text.trim().isEmpty,
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
            backgroundColor: Color(0xFF44D69B),
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
    }

    FormDrawer.show(
      context: context,
      title: isEditing ? 'Edit Opponent' : 'Add Opponent',
      onSave: saveOpponent,
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF131616),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  // Opponent Name field
                  Padding(
                    padding: EdgeInsets.fromLTRB(10, 10, 8, 10),
                    child: TextField(
                      controller: nameController,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Opponent Name',
                        hintStyle: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          height: 1.44,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  // Separator
                  Container(
                    height: 21,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: Container(height: 1, color: Color(0xFF3A3A3C)),
                  ),
                  // Notes field
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: TextField(
                      controller: notesController,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Notes (Optional)',
                        hintStyle: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w400,
                          height: 1.44,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 4,
                    ),
                  ),
                  // Separator
                  Container(
                    height: 21,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: Container(height: 1, color: Color(0xFF3A3A3C)),
                  ),
                  // Pick a color row
                  GestureDetector(
                    key: colorPickerKey,
                    onTap: () => showColorPicker(setSheetState),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pick a color',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              color: Color(0xFFB9B9B9),
                              fontWeight: FontWeight.w400,
                              height: 1.44,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                getColorName(selectedColor),
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 17,
                                  color: Color(0xFFB9B9B9),
                                  fontWeight: FontWeight.w400,
                                  height: 1.44,
                                ),
                              ),
                              SizedBox(width: 10),
                              _buildIcon(
                                'icons/figma_icons/up_and_down.svg',
                                20,
                                Color(0xFFB9B9B9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      style: GoogleFonts.ibmPlexSans(
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
                        style: GoogleFonts.ibmPlexSans(
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
                          style: GoogleFonts.ibmPlexSans(
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
                    style: GoogleFonts.ibmPlexSans(
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