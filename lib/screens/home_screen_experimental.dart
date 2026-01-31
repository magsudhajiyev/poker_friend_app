import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/introduction_screen.dart';
import '../screens/logging_mode_selection_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/my_opponents_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/calendar_screen.dart';
import '../services/auth_service.dart';
import '../services/bankroll_service.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/session_result_service.dart';
import '../services/play_style_detector.dart';
import '../services/stats_verification_service.dart';
import '../screens/auth_screen.dart';
import '../widgets/loading_screen.dart';
import '../services/calendar_event_service.dart';
import '../widgets/global_bottom_nav_bar.dart';
import '../design_system/design_system.dart';

/// Experimental home screen with new design
class HomeScreenExperimental extends StatefulWidget {
  @override
  _HomeScreenExperimentalState createState() => _HomeScreenExperimentalState();
}

class _HomeScreenExperimentalState extends State<HomeScreenExperimental> with TickerProviderStateMixin {
  int _currentIndex = 2;
  List<Map<String, dynamic>> upcomingEvents = [];

  // Data variables
  double currentBankroll = 0.0;
  double bankrollGoal = 0.0;
  double bankrollProgress = 0.0;
  String userName = 'User';

  // Animation variables
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  Map<String, dynamic> playerStats = {};
  List<Map<String, dynamic>> recentSessions = [];
  List<Map<String, dynamic>> earningsChartData = [];
  double avgEarnings = 0.0;
  bool isLoadingData = true;

  // Context menu state
  String? _selectedEventId;
  Offset? _popupPosition;

  @override
  void initState() {
    super.initState();

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _loadData();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoadingData = true;
      });

      StatsVerificationService.verifyAllStats();

      final bankroll = await BankrollService.getCurrentBankroll();
      final goal = await BankrollService.getBankrollGoal();
      final progress = await BankrollService.getBankrollProgress();
      final stats = await BankrollService.getPlayerStatistics();
      final sessions = await _getRecentSessions();
      final earningsData = await _getEarningsData();
      final events = await _loadCalendarEvents();

      final user = AuthService.currentUser;
      String displayName = 'User';
      if (user != null) {
        displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      }

      if (mounted) {
        setState(() {
          currentBankroll = bankroll;
          bankrollGoal = goal;
          bankrollProgress = progress;
          playerStats = stats;
          recentSessions = sessions;
          earningsChartData = earningsData['chartData'];
          avgEarnings = earningsData['avgEarnings'];
          upcomingEvents = events;
          userName = displayName;
          isLoadingData = false;
        });

        _progressAnimationController.reset();
        _progressAnimationController.forward();
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoadingData = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentSessions() async {
    try {
      List<Map<String, dynamic>> sessions;
      try {
        sessions = await FirebaseService.getAllSessions();
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
      }

      sessions.sort((a, b) {
        try {
          DateTime dateA = _parseSessionDate(a);
          DateTime dateB = _parseSessionDate(b);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      return sessions.take(3).toList();
    } catch (e) {
      print('Error loading recent sessions: $e');
      return [];
    }
  }

  DateTime _parseSessionDate(Map<String, dynamic> session) {
    try {
      var createdAt = session['createdAt'];
      var timestamp = session['timestamp'];

      if (createdAt != null) {
        if (createdAt.runtimeType.toString().contains('Timestamp')) {
          return (createdAt as dynamic).toDate();
        }
        if (createdAt is DateTime) {
          return createdAt;
        }
        if (createdAt is String) {
          return DateTime.tryParse(createdAt) ?? DateTime(2000);
        }
      }

      if (timestamp != null) {
        if (timestamp.runtimeType.toString().contains('Timestamp')) {
          return (timestamp as dynamic).toDate();
        }
        if (timestamp is DateTime) {
          return timestamp;
        }
        if (timestamp is String) {
          return DateTime.tryParse(timestamp) ?? DateTime(2000);
        }
      }

      return DateTime(2000);
    } catch (e) {
      return DateTime(2000);
    }
  }

  Future<Map<String, dynamic>> _getEarningsData() async {
    try {
      final sessionResults = await SessionResultService.getAllSessionResults();

      final now = DateTime.now();
      final currentWeekday = now.weekday;
      final monday = now.subtract(Duration(days: currentWeekday - 1));
      final sunday = monday.add(Duration(days: 6));

      Map<String, Map<String, double>> dailyData = {};
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateKey = DateFormat('MMM d').format(date);
        dailyData[dateKey] = {'tournament': 0.0, 'cash': 0.0, 'dateObj': date.millisecondsSinceEpoch.toDouble()};
      }

      for (var result in sessionResults) {
        DateTime date;
        if (result['timestamp'] != null) {
          date = (result['timestamp'] as Timestamp).toDate();
        } else if (result['createdAt'] != null) {
          date = DateTime.parse(result['createdAt']);
        } else {
          continue;
        }

        if (date.isBefore(monday) || date.isAfter(sunday.add(Duration(days: 1)))) continue;

        final dateKey = DateFormat('MMM d').format(date);
        final gameType = result['gameType'] as String? ?? 'cash';
        final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;

        if (dailyData.containsKey(dateKey)) {
          dailyData[dateKey]![gameType] = (dailyData[dateKey]![gameType] ?? 0.0) + amount;
        }
      }

      List<Map<String, dynamic>> chartData = dailyData.entries.map((entry) {
        return {
          'date': entry.key,
          'tournament': entry.value['tournament']!,
          'cash': entry.value['cash']!,
          'dateObj': entry.value['dateObj']!,
        };
      }).toList();

      chartData.sort((a, b) => (a['dateObj'] as double).compareTo(b['dateObj'] as double));

      for (var item in chartData) {
        item.remove('dateObj');
      }

      double totalEarnings = sessionResults.fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0));
      double avgEarnings = sessionResults.isNotEmpty ? totalEarnings / sessionResults.length : 0.0;

      return {
        'chartData': chartData,
        'avgEarnings': avgEarnings,
      };
    } catch (e) {
      print('Error getting earnings data: $e');
      return {
        'chartData': <Map<String, dynamic>>[],
        'avgEarnings': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _loadCalendarEvents() async {
    try {
      final events = await CalendarEventService.getUpcomingEvents();
      return events;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData && currentBankroll == 0.0 && recentSessions.isEmpty) {
      return LoadingScreen(message: 'Loading your poker data...');
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // Gradient background from design system
          GradientBackground(),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFA5EC44),
              backgroundColor: const Color(0xFF1C2926),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // Top Header Bar
                      MainScreenHeader(
                        username: userName,
                        title: 'Home', // Fallback if no username
                        subtitle: 'Welcome back',
                        showLeftIcon: true,
                        leftImagePath: 'icons/flat_icons/stats.png',
                        onLeftPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => StatisticsScreen()),
                          );
                        },
                        rightImagePath: 'icons/flat_icons/bell.png',
                        onRightPressed: () {
                          // TODO: Navigate to notifications
                        },
                      ),

                      const SizedBox(height: 24),

                      // Goal Section
                      _buildGoalSection(),

                      const SizedBox(height: 40),

                      // Stats Grid
                      _buildStatsGrid(),

                      const SizedBox(height: 28),

                      // Earnings Chart
                      _buildEarningsCard(),

                      const SizedBox(height: 28),

                      // Recent Sessions
                      _buildRecentSessionsCard(),

                      const SizedBox(height: 28),

                      // Upcoming Events
                      _buildUpcomingEventsCard(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Blur overlay when popup is visible
          if (_selectedEventId != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEventId = null;
                  _popupPosition = null;
                });
              },
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  color: Colors.black.withOpacity(0.0),
                ),
              ),
            ),

          // Positioned popup menu
          if (_selectedEventId != null && _popupPosition != null)
            Positioned(
              left: _popupPosition!.dx,
              top: _popupPosition!.dy,
              child: _buildEventContextMenu(),
            ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'home'),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Home Icon
          IconButton(
            icon: Icon(Icons.home, color: Colors.white, size: 28),
            onPressed: () {
              // Already on home screen
            },
          ),
          // Opponents Icon
          IconButton(
            icon: Icon(Icons.group, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyOpponentsScreen()),
              );
            },
          ),
          // Center Plus Button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFA5EC44),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
                );
              },
            ),
          ),
          // Game/Cards Icon
          IconButton(
            icon: Icon(Icons.style, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
              );
            },
          ),
          // Profile Icon
          IconButton(
            icon: Icon(Icons.person, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Picture (frame)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),

          // Right side icons
          Row(
            children: [
              // Statistics Icon
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StatisticsScreen()),
                  );
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'icons/flat_icons/stats.png',
                      color: Colors.white,
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Notification Bell Icon
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to notifications
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'icons/flat_icons/bell.png',
                      color: Colors.white,
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // 144deg in CSS = Alignment(-0.8, -0.6) to Alignment(0.8, 0.6)
          begin: Alignment(-0.8, -0.6),
          end: Alignment(0.8, 0.6),
          colors: [
            Color(0xFF022F00), // rgba(2, 47, 0, 1) - darkest
            Color(0xFF033800), // Very subtle step
            Color(0xFF044100), // Very subtle step
            Color(0xFF054A00), // Very subtle step
            Color(0xFF055300), // Very subtle step
            Color(0xFF065C00), // Very subtle step
            Color(0xFF076500), // Softer bright green
          ],
          stops: [0.0, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Balance label
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Text(
              'Bankroll',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(height: 16),
          // Main balance text
          Text(
            '\$${currentBankroll.toStringAsFixed(0)} of \$${bankrollGoal.toStringAsFixed(0)}',
            style: GoogleFonts.robotoMono(
              fontSize: 38,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.0,
            ),
          ),
          SizedBox(height: 14),
          // Remaining balance text
          Text(
            '\$${(bankrollGoal - currentBankroll).toStringAsFixed(0)} left',
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              color: Color(0xFFC2EFBA),
              fontWeight: FontWeight.w500,
              letterSpacing: -1.0,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent Activity title
        Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF87ED81),
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
        SizedBox(height: 20),
        // Stats cards with dividers
        Column(
          children: [
            _buildStatCard(
              'Sessions',
              '${playerStats['totalSessions'] ?? 0}',
              iconAsset: 'assets/session.png',
            ),
            _buildDivider(),
            _buildStatCard(
              'Win Rate',
              '${(playerStats['winRate'] ?? 0.0).toStringAsFixed(0)}%',
              iconAsset: 'assets/trophy.png',
            ),
            _buildDivider(),
            _buildStatCard(
              'Hours',
              '${(playerStats['totalHours'] ?? 0.0).toStringAsFixed(1)}',
              iconAsset: 'assets/clock.png',
            ),
            _buildDivider(),
            _buildStatCard(
              'Play Style',
              _getPlayStyleName(),
              iconAsset: _getPlayStyleIcon(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, {IconData? icon, String? iconAsset}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and avg badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EARNINGS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF87ED81),
                fontWeight: FontWeight.w400,
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF009548),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Avg',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '\$${avgEarnings.toStringAsFixed(0)}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Legend
        Row(
          children: [
            _buildLegendItem('Tournament', const Color(0xFF00C3FF)),
            const SizedBox(width: 17),
            _buildLegendItem('Cash Game', const Color(0xFF44EC49)),
          ],
        ),
        const SizedBox(height: 24),
        // Chart
        Container(
          height: 167,
          child: earningsChartData.isEmpty
              ? Center(
                  child: Text(
                    'No earnings data yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.40),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : CustomPaint(
                  painter: EarningsChartPainter(earningsChartData),
                  size: Size.infinite,
                ),
        ),
      ],
    );
  }

  Widget _buildRecentSessionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and view all
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT SESSIONS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF87ED81),
                fontWeight: FontWeight.w400,
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SessionHistoryScreen()),
                );
              },
              child: Text(
                'View All',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Content
        recentSessions.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF2B2B2B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon (24x24)
                    Image.asset(
                      'icons/flat_icons/deuce.png',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Text content - centered, 200px width
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          Text(
                            'No recent sessions',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1.46,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start your first poker session!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0x4C2C3E2E), // #2c3e2e4c
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _buildSessionsList(),
                ),
              ),
      ],
    );
  }

  Widget _buildUpcomingEventsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and view all
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UPCOMING EVENTS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF87ED81),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CalendarScreen()),
                );
                _loadData();
              },
              child: Text(
                'View All',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Content
        upcomingEvents.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF2B2B2B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon (24x24)
                    Image.asset(
                      'icons/flat_icons/calendar_edit.png',
                      width: 24,
                      height: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Text content - centered, 200px width
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          Text(
                            'No upcoming events',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              height: 1.46,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Schedule your first event!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0x4C2C3E2E), // #2c3e2e4c
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _buildEventsList(),
                ),
              ),
      ],
    );
  }

  List<Widget> _buildSessionsList() {
    List<Widget> widgets = [];
    final sessions = recentSessions.take(3).toList();

    for (int i = 0; i < sessions.length; i++) {
      widgets.add(_buildSessionItem(sessions[i]));

      // Add divider between sessions (not after the last one)
      if (i < sessions.length - 1) {
        widgets.add(
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    String sessionName = session['sessionName'] ?? '';

    if (sessionName.isEmpty) {
      final createdAt = _parseSessionDate(session);
      final gameType = session['gameType'] ?? 'Poker';
      final dateStr = DateFormat('MMM d').format(createdAt);
      sessionName = '$gameType Session - $dateStr';
    }

    final createdAt = _parseSessionDate(session);
    final formattedDate = DateFormat('MMM dd, h:mma').format(createdAt).toLowerCase();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionHistoryScreen(targetSessionId: session['id']),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    color: Color(0xFFF8FFF7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFFF8FFF7),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Right side: Arrow icon
          Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFF87ED81),
            size: 18,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventsList() {
    List<Widget> widgets = [];
    final events = upcomingEvents.take(3).toList();

    for (int i = 0; i < events.length; i++) {
      widgets.add(_buildEventItem(events[i]));

      // Add divider between events (not after the last one)
      if (i < events.length - 1) {
        widgets.add(
          Container(
            height: 1,
            margin: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final GlobalKey eventKey = GlobalKey();

    String formattedDate = '';
    try {
      final dateTime = DateTime.parse(event['date']);
      formattedDate = DateFormat('MMM dd, h:mma').format(dateTime).toLowerCase();
    } catch (e) {
      formattedDate = event['date'] ?? '';
    }

    // Get buy-in amount from event
    String buyIn = '';
    if (event['buyIn'] != null) {
      final buyInValue = event['buyIn'];
      if (buyInValue is num) {
        buyIn = '\$${buyInValue.toStringAsFixed(0)}';
      } else {
        buyIn = buyInValue.toString();
      }
    }

    return GestureDetector(
      key: eventKey,
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        // Get the position of the card
        final RenderBox renderBox = eventKey.currentContext!.findRenderObject() as RenderBox;
        final cardPosition = renderBox.localToGlobal(Offset.zero);
        final cardSize = renderBox.size;

        // Position popup at top-right of the card
        final popupX = cardPosition.dx + cardSize.width - 184 - 16; // 184px menu width, 16px margin
        final popupY = cardPosition.dy;

        setState(() {
          _selectedEventId = event['id'];
          _popupPosition = Offset(popupX, popupY);
        });
      },
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Left side: Event info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event['title'] ?? 'Event',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  color: Color(0xFFF8FFF7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formattedDate,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFFF8FFF7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        // Right side: Buy-in price
        if (buyIn.isNotEmpty)
          Text(
            buyIn,
            style: GoogleFonts.robotoMono(
              fontSize: 22,
              color: Color(0xFF87ED81),
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.0,
            ),
          ),
      ],
        ),
      ),
    );
  }

  Widget _buildEventContextMenu() {
    if (_selectedEventId == null) return SizedBox.shrink();

    // Find the event data
    final event = upcomingEvents.firstWhere(
      (e) => e['id'] == _selectedEventId,
      orElse: () => {},
    );

    if (event.isEmpty) return SizedBox.shrink();

    final eventTitle = event['title'] ?? 'Event';

    return AnimatedScale(
      scale: _selectedEventId != null ? 1.0 : 0.0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _selectedEventId != null ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          width: 184,
          decoration: BoxDecoration(
            color: Color(0xFF131613),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Event title
              Text(
                eventTitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 14),

              // Menu items
              Column(
                children: [
                  // Edit Event
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEventId = null;
                        _popupPosition = null;
                      });
                      _showEditEventDialog(event);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Event',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFFEBFFEF),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              height: 1.2,
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            color: Color(0xFFEBFFEF),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.1),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // Delete Event
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEventId = null;
                        _popupPosition = null;
                      });
                      _handleDeleteEvent(event['id'], event['title'] ?? 'Event');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delete Event',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Color(0xFFEBFFEF),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              height: 1.2,
                            ),
                          ),
                          Icon(
                            Icons.delete,
                            color: Color(0xFFEBFFEF),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditEventDialog(Map<String, dynamic> event) async {
    final titleController = TextEditingController(text: event['title'] ?? '');
    final locationController = TextEditingController(text: event['location'] ?? '');
    final buyInController = TextEditingController(text: event['buyIn']?.toString() ?? '');

    final eventDate = DateTime.parse(event['date']);
    DateTime dialogSelectedDate = eventDate;
    TimeOfDay selectedTime = TimeOfDay(hour: eventDate.hour, minute: eventDate.minute);
    String selectedType = event['type'] ?? 'Tournament';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Blurred backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.0),
                  ),
                ),
              ),
            ),
            // Dialog content
            Center(
              child: StatefulBuilder(
                builder: (context, setDialogState) => Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: EdgeInsets.all(16),
                    width: 361,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFF000300),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and Close button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Edit Event',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 32),

                          // Event Type Selector
                          Container(
                            width: double.infinity,
                            height: 48,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Color(0x0AFFFFFF),
                              border: Border.all(color: Color(0xFF13321B)),
                              borderRadius: BorderRadius.circular(58),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedType,
                                dropdownColor: Color(0xFF000300),
                                icon: Icon(Icons.keyboard_arrow_down, color: Color(0x99EBFFEF), size: 18),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0x99EBFFEF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                ),
                                items: ['Tournament', 'Cash Game', 'Home Game', 'Online']
                                    .map((type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedType = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Event Name Field
                          TextField(
                            controller: titleController,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Event Name',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0x99EBFFEF),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              filled: true,
                              fillColor: Color(0x0AFFFFFF),
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Location/Venue Field
                          TextField(
                            controller: locationController,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Location/Venue',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0x99EBFFEF),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              filled: true,
                              fillColor: Color(0x0AFFFFFF),
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Buy-in Field
                          TextField(
                            controller: buyInController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0x99EBFFEF),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buy in amount',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0x99EBFFEF),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(58),
                                borderSide: BorderSide(color: Color(0xFF13321B)),
                              ),
                              filled: true,
                              fillColor: Color(0x0AFFFFFF),
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Date Picker
                          GestureDetector(
                            onTap: () async {
                              final date = await _showCustomDatePicker(
                                context,
                                dialogSelectedDate,
                              );
                              if (date != null) {
                                setDialogState(() {
                                  dialogSelectedDate = date;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: Color(0xFF181D1B),
                                border: Border.all(color: Colors.transparent),
                                borderRadius: BorderRadius.circular(58),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Color(0x99EBFFEF), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(dialogSelectedDate),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0x99EBFFEF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.keyboard_arrow_down, color: Color(0x99EBFFEF), size: 18),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Time Picker
                          GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (time != null) {
                                setDialogState(() {
                                  selectedTime = time;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: Color(0x0AFFFFFF),
                                border: Border.all(color: Color(0xFF13321B)),
                                borderRadius: BorderRadius.circular(58),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, color: Color(0x99EBFFEF), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    selectedTime.format(context),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0x99EBFFEF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(Icons.keyboard_arrow_down, color: Color(0x99EBFFEF), size: 18),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 32),

                          // Save Changes Button
                          GestureDetector(
                            onTap: () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) return;

                              final eventDateTime = DateTime(
                                dialogSelectedDate.year,
                                dialogSelectedDate.month,
                                dialogSelectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              try {
                                await CalendarEventService.updateEvent(
                                  eventId: event['id'],
                                  title: title,
                                  type: selectedType,
                                  location: locationController.text.trim(),
                                  date: eventDateTime,
                                  buyIn: double.tryParse(buyInController.text) ?? 0.0,
                                );

                                Navigator.pop(context);
                                _loadData();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update event: $e')),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(0xFFBAFF9A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              child: Center(
                                child: Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                  ),
                                ),
                              ),
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
        );
      },
    );
  }

  Future<DateTime?> _showCustomDatePicker(BuildContext context, DateTime initialDate) async {
    DateTime displayMonth = DateTime(initialDate.year, initialDate.month);
    DateTime? selectedDate = initialDate;

    return await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            // Calculate calendar data
            final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
            final firstDayOfMonth = DateTime(displayMonth.year, displayMonth.month, 1);
            final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

            return Stack(
              children: [
                // Blurred backdrop
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        color: Colors.black.withOpacity(0.0),
                      ),
                    ),
                  ),
                ),
                // Date picker content
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 312,
                      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF000300),
                        border: Border.all(color: Color(0x4CFFFFFF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text(
                                  'Select date:',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFFBDBDBD),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Spacer(),
                                // Clear button
                                GestureDetector(
                                  onTap: () {
                                    setPickerState(() {
                                      selectedDate = DateTime.now();
                                      displayMonth = DateTime(selectedDate!.year, selectedDate!.month);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close, color: Color(0xFFD55A41), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Clear',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFFD55A41),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Today button
                                GestureDetector(
                                  onTap: () {
                                    final today = DateTime.now();
                                    setPickerState(() {
                                      selectedDate = DateTime(today.year, today.month, today.day);
                                      displayMonth = DateTime(today.year, today.month);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Color(0xFFFFFFFF).withOpacity(0.3)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.today, color: Color(0xFFFAFAFA), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFFFAFAFA),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Close button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(Icons.close, color: Color(0xFFFAFAFA), size: 16),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 4),

                          // Calendar body
                          Container(
                            width: 296,
                            decoration: BoxDecoration(
                              color: Color(0xFF171C19),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Year/Month selector
                                SizedBox(
                                  width: 280,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                    // Year button
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${displayMonth.year}',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: Color(0xFFFAFAFA),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.keyboard_arrow_down, color: Color(0xFFFAFAFA), size: 16),
                                        ],
                                      ),
                                    ),
                                    // Month navigation
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.chevron_left, color: Color(0xFFFAFAFA), size: 16),
                                          onPressed: () {
                                            setPickerState(() {
                                              displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                                            });
                                          },
                                          padding: EdgeInsets.all(8),
                                          constraints: BoxConstraints(),
                                        ),
                                        Text(
                                          DateFormat('MMMM').format(displayMonth),
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFFFAFAFA),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.chevron_right, color: Color(0xFFFAFAFA), size: 16),
                                          onPressed: () {
                                            setPickerState(() {
                                              displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
                                            });
                                          },
                                          padding: EdgeInsets.all(8),
                                          constraints: BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                  ),
                                ),

                                SizedBox(height: 2),

                                // Week day labels
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF191F1B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                          .map((day) => Expanded(
                                                child: Container(
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Color(0x0DFFFFFF),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      day,
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        color: Color(0xFFBDBDBD),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 2),

                                // Calendar grid
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    childAspectRatio: 1.0,
                                    crossAxisSpacing: 0,
                                    mainAxisSpacing: 0,
                                  ),
                                  itemCount: 42,
                                  itemBuilder: (context, index) {
                                    // Show previous month days
                                    if (index < startingWeekday) {
                                      final prevMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                                      final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
                                      final prevMonthDay = daysInPrevMonth - (startingWeekday - index - 1);

                                      return Container(
                                        child: Center(
                                          child: Text(
                                            prevMonthDay.toString(),
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: Color(0x66FAFAFA), // Grayed out
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final dayNumber = index - startingWeekday + 1;
                                    if (dayNumber > daysInMonth) {
                                      return Container(); // Empty cell
                                    }

                                    final date = DateTime(displayMonth.year, displayMonth.month, dayNumber);
                                    final isSelected = selectedDate != null &&
                                        selectedDate!.year == date.year &&
                                        selectedDate!.month == date.month &&
                                        selectedDate!.day == date.day;
                                    final isToday = DateTime.now().year == date.year &&
                                        DateTime.now().month == date.month &&
                                        DateTime.now().day == date.day;

                                    return GestureDetector(
                                      onTap: () {
                                        setPickerState(() {
                                          selectedDate = date;
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Color(0xFF5AC95A)
                                              : (isToday ? Color(0xFF2A2A2E) : Colors.transparent),
                                          borderRadius: BorderRadius.circular(8),
                                          border: isToday && !isSelected
                                              ? Border.all(color: Color(0xFF5AC95A), width: 1)
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            dayNumber.toString(),
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: isSelected ? Colors.black : Color(0xFFFAFAFA),
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 8),

                          // Footer buttons
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: [
                                // Cancel button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 88,
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Color(0xFFFFFFFF).withOpacity(0.3)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: Color(0xFFFAFAFA),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Done button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context, selectedDate),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFBAFF9A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Done',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
            );
          },
        );
      },
    );
  }

  void _handleDeleteEvent(String eventId, String eventName) {
    _showDeleteConfirmationDialog(eventId, eventName);
  }

  void _showDeleteConfirmationDialog(String eventId, String eventName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Blurred backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: Colors.black.withOpacity(0.0),
                  ),
                ),
              ),
            ),

            // Dialog content
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              // Main dialog container
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF131613),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    // Title section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Delete $eventName?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Description section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Are you sure you want to delete "$eventName"?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.24,
                          height: 1.7,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),

                    SizedBox(height: 4),

                    // Delete button
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context); // Close dialog
                        await _performDeleteEvent(eventId);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Color(0xFFD55A41), // Red color
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            height: 1.2,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // Cancel button (separate container)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF131613),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  width: double.infinity,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: 16), // Bottom safe area padding
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteEvent(String eventId) async {
    try {
      // Delete the event
      await CalendarEventService.deleteEvent(eventId);

      // Reload data to show updated list
      await _loadData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event deleted successfully'),
          backgroundColor: Color(0xFF5AC95A),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting event: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            letterSpacing: -0.24,
          ),
        ),
      ],
    );
  }

  String _getPlayStyleName() {
    final vpip = (playerStats['vpip'] as num?)?.toDouble() ?? 0.0;
    final pfr = (playerStats['pfr'] as num?)?.toDouble() ?? 0.0;
    final threeBet = (playerStats['threeBet'] as num?)?.toDouble() ?? 0.0;
    final aggressionFactor = (playerStats['aggressionFactor'] as num?)?.toDouble() ?? 0.0;
    final wtsd = (playerStats['wtsd'] as num?)?.toDouble();
    final wsd = (playerStats['wsd'] as num?)?.toDouble();
    final handsPlayed = (playerStats['handsPlayed'] as num?)?.toInt();

    final result = PlayStyleDetector.detectPlayStyle(
      vpip: vpip,
      pfr: pfr,
      threeBet: threeBet,
      aggressionFactor: aggressionFactor,
      wtsd: wtsd,
      wsd: wsd,
      handsPlayed: handsPlayed,
    );

    return PlayStyleDetector.getStyleAbbreviation(result['style'] ?? 'Balanced');
  }

  String _getPlayStyleIcon() {
    final styleName = _getPlayStyleName().toLowerCase();

    // Map play style abbreviations to icon filenames
    switch (styleName) {
      case 'tag':
        return 'assets/play_style/tag.png';
      case 'lag':
        return 'assets/play_style/lag.png';
      case 'nit':
        return 'assets/play_style/nit.png';
      case 'maniac':
        return 'assets/play_style/maniac.png';
      case 'calling station':
        return 'assets/play_style/calling_station.png';
      case 'balanced':
        return 'assets/play_style/balanced.png';
      default:
        return 'assets/play_style/balanced.png'; // Default fallback
    }
  }
}

// Custom painter for earnings chart (bar chart)
class EarningsChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  EarningsChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;

    final chartArea = Rect.fromLTWH(50, 20, size.width - 70, size.height - 50);

    double maxValue = 0;
    double minValue = 0;
    for (var point in data) {
      final tournament = (point['tournament'] as num?)?.toDouble() ?? 0.0;
      final cash = (point['cash'] as num?)?.toDouble() ?? 0.0;
      maxValue = math.max(maxValue, math.max(tournament, cash));
      minValue = math.min(minValue, math.min(tournament, cash));
    }

    if (maxValue == 0 && minValue == 0) {
      maxValue = 100;
      minValue = -100;
    }

    maxValue = ((maxValue / 100).ceil() * 100).toDouble();
    minValue = ((minValue / 100).floor() * 100).toDouble();

    final valueRange = maxValue - minValue;

    final zeroY = chartArea.bottom - ((0 - minValue) / valueRange) * chartArea.height;

    final axisPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(chartArea.left, chartArea.top),
      Offset(chartArea.left, chartArea.bottom),
      axisPaint,
    );

    canvas.drawLine(
      Offset(chartArea.left, zeroY),
      Offset(chartArea.right, zeroY),
      axisPaint,
    );

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final value = minValue + (i * valueRange / 4);
      textPainter.text = TextSpan(
        text: '\$${value.toInt()}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
        ),
      );
      textPainter.layout();

      final y = chartArea.bottom - (i / 4) * chartArea.height;
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    final barGroupWidth = chartArea.width / data.length;
    final barWidth = (barGroupWidth - 16) / 2;
    final spacing = 4.0;

    for (int i = 0; i < data.length; i++) {
      final tournamentValue = (data[i]['tournament'] as num?)?.toDouble() ?? 0.0;
      final cashValue = (data[i]['cash'] as num?)?.toDouble() ?? 0.0;

      final groupX = chartArea.left + (i * barGroupWidth) + 8;

      final tournamentBarX = groupX;
      final tournamentHeight = ((tournamentValue - 0) / valueRange) * chartArea.height;
      final tournamentTop = tournamentValue >= 0
          ? zeroY - tournamentHeight.abs()
          : zeroY;
      final tournamentBarHeight = tournamentHeight.abs();

      if (tournamentBarHeight > 0) {
        paint.color = const Color(0xFF006AFF);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              tournamentBarX,
              tournamentTop,
              barWidth,
              tournamentBarHeight,
            ),
            Radius.circular(4),
          ),
          paint,
        );
      }

      final cashBarX = groupX + barWidth + spacing;
      final cashHeight = ((cashValue - 0) / valueRange) * chartArea.height;
      final cashTop = cashValue >= 0
          ? zeroY - cashHeight.abs()
          : zeroY;
      final cashBarHeight = cashHeight.abs();

      if (cashBarHeight > 0) {
        paint.color = const Color(0xFFA5EC44);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cashBarX,
              cashTop,
              barWidth,
              cashBarHeight,
            ),
            Radius.circular(4),
          ),
          paint,
        );
      }

      textPainter.text = TextSpan(
        text: data[i]['date'],
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w300,
        ),
      );
      textPainter.layout();

      final labelX = groupX + (barGroupWidth - 16) / 2 - textPainter.width / 2;
      textPainter.paint(canvas, Offset(labelX, chartArea.bottom + 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
