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
      print('❌ Error loading calendar events: $e');
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
                        leftIcon: Icons.bar_chart_rounded,
                        onLeftPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => StatisticsScreen()),
                          );
                        },
                        rightIcon: Icons.notifications,
                        onRightPressed: () {
                          // TODO: Navigate to notifications
                        },
                      ),

                      const SizedBox(height: 24),

                      // Goal Section
                      _buildGoalSection(),

                      const SizedBox(height: 24),

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
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: Colors.white,
                      size: 26,
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
                    child: Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 26,
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
          // 144deg in CSS = approx Alignment(0.6, -0.8) to Alignment(-0.6, 0.8)
          begin: Alignment(0.6, -0.8),
          end: Alignment(-0.6, 0.8),
          colors: [
            Color(0xFF022F00), // rgba(2, 47, 0, 1)
            Color(0xFF079500), // rgba(7, 149, 0, 1)
          ],
          stops: [0.0, 1.0],
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
        SizedBox(height: 12),
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
      margin: EdgeInsets.symmetric(vertical: 8),
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
                  color: Color(0xFFC9C9C9),
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Text(
                    'No sessions yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.40),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            : Column(
                children: recentSessions.map((session) => _buildSessionItem(session)).toList(),
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
                  color: Color(0xFFC9C9C9),
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
                decoration: BoxDecoration(
                  color: Color(0xFF3D3D3D).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 44),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 32,
                      color: Color(0xFFEBFFE4),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No upcoming events',
                      style: TextStyle(
                        color: Color(0xFFEBFFE4),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                children: upcomingEvents.take(3).map((event) => _buildEventItem(event)).toList(),
              ),
      ],
    );
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionHistoryScreen(targetSessionId: session['id']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF546165).withOpacity(0.74),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          sessionName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.5),
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.84),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          DateFormat('HH:mm').format(createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.84),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    String formattedDate = '';
    String formattedTime = '';
    try {
      final dateTime = DateTime.parse(event['date']);
      formattedDate = DateFormat('MMM dd, yyyy').format(dateTime);
      formattedTime = DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      formattedDate = event['date'] ?? '';
      formattedTime = '';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFF546165).withOpacity(0.74),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Event Name and Buy-in
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event['title'] ?? 'Event',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (buyIn.isNotEmpty)
                      Text(
                        buyIn,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom row: Date and Time pills
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.84),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (formattedTime.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.84),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
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
