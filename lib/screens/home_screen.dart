import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:intl/intl.dart';
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

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 2; // Start tab is selected by default
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
    
    // Initialize animation controller
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Initialize animation with curved animation for smooth progress
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

      // Run stats verification in background
      StatsVerificationService.verifyAllStats();

      final bankroll = await BankrollService.getCurrentBankroll();
      final goal = await BankrollService.getBankrollGoal();
      final progress = await BankrollService.getBankrollProgress();
      final stats = await BankrollService.getPlayerStatistics();
      final sessions = await _getRecentSessions();
      final earningsData = await _getEarningsData();
      final events = await _loadCalendarEvents();

      // Get user's display name
      final user = AuthService.currentUser;
      String displayName = 'User';
      if (user != null) {
        displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      }

      if (mounted) {
        print('🏠 DEBUG Home Screen - playerStats: $stats');
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

        // Reset and start animation from 0 to the new progress value
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
      
      
      // Sort by date and take the latest 3
      sessions.sort((a, b) {
        try {
          DateTime dateA = _parseSessionDate(a);
          DateTime dateB = _parseSessionDate(b);
          
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });
      
      List<Map<String, dynamic>> recent = sessions.take(3).toList();
      
      return recent;
    } catch (e) {
      print('Error loading recent sessions: $e');
      return [];
    }
  }

  DateTime _parseSessionDate(Map<String, dynamic> session) {
    try {
      // Handle Firebase Timestamp objects
      var createdAt = session['createdAt'];
      var timestamp = session['timestamp'];

      if (createdAt != null) {
        // If it's a Firebase Timestamp, convert it
        if (createdAt.runtimeType.toString().contains('Timestamp')) {
          return (createdAt as dynamic).toDate();
        }
        // If it's already a DateTime
        if (createdAt is DateTime) {
          return createdAt;
        }
        // If it's a String, parse it
        if (createdAt is String) {
          return DateTime.tryParse(createdAt) ?? DateTime(2000);
        }
      }

      if (timestamp != null) {
        // Handle timestamp field similarly
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
      // Get all session results
      final sessionResults = await SessionResultService.getAllSessionResults();

      // Calculate current week (Monday to Sunday)
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday

      // Get Monday of current week (weekday 1)
      final monday = now.subtract(Duration(days: currentWeekday - 1));
      // Get Sunday of current week
      final sunday = monday.add(Duration(days: 6));

      print('📅 Current Week: ${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(sunday)}');

      // Initialize data for all 7 days of current week with zeros
      Map<String, Map<String, double>> dailyData = {};
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateKey = DateFormat('MMM d').format(date);
        dailyData[dateKey] = {'tournament': 0.0, 'cash': 0.0, 'dateObj': date.millisecondsSinceEpoch.toDouble()};
      }

      // Fill in actual data for days that have session results
      for (var result in sessionResults) {
        DateTime date;
        if (result['timestamp'] != null) {
          date = (result['timestamp'] as Timestamp).toDate();
        } else if (result['createdAt'] != null) {
          date = DateTime.parse(result['createdAt']);
        } else {
          continue;
        }

        // Only include data from current week (Monday to Sunday)
        if (date.isBefore(monday) || date.isAfter(sunday.add(Duration(days: 1)))) continue;

        // Normalize to day (ignore time)
        final dateKey = DateFormat('MMM d').format(date);

        final gameType = result['gameType'] as String? ?? 'cash';
        final amount = (result['amount'] as num?)?.toDouble() ?? 0.0;

        if (dailyData.containsKey(dateKey)) {
          dailyData[dateKey]![gameType] = (dailyData[dateKey]![gameType] ?? 0.0) + amount;
        }
      }

      // Convert to list and sort chronologically
      List<Map<String, dynamic>> chartData = dailyData.entries.map((entry) {
        return {
          'date': entry.key,
          'tournament': entry.value['tournament']!,
          'cash': entry.value['cash']!,
          'dateObj': entry.value['dateObj']!,
        };
      }).toList();

      // Sort by actual date
      chartData.sort((a, b) => (a['dateObj'] as double).compareTo(b['dateObj'] as double));

      // Remove dateObj as it's only used for sorting
      for (var item in chartData) {
        item.remove('dateObj');
      }

      // Calculate average earnings: total / number of sessions (can be negative)
      double totalEarnings = sessionResults.fold(0.0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0));
      double avgEarnings = sessionResults.isNotEmpty ? totalEarnings / sessionResults.length : 0.0;

      print('📊 Earnings Data: ${chartData.length} days, Avg: \$${avgEarnings.toStringAsFixed(2)}');

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

  @override
  Widget build(BuildContext context) {
    // Show loading screen during initial data load
    if (isLoadingData && currentBankroll == 0.0 && recentSessions.isEmpty) {
      return LoadingScreen(message: 'Loading your poker data...');
    }
    
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(0xFF161618), // Health app dark background
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: Color(0xFF5AC95A),
              backgroundColor: Color(0xFF1F1F23),
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 375),
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // Header Section
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 32, 0, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, $userName!',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _getFormattedDate(),
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9A9A9A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(0xFF1F1F23),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: Colors.white.withOpacity(0.4),
                            size: 22,
                          ),
                          onPressed: null,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Goal Progress Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Goal',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '\$${currentBankroll.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: Color(0xFF5AC95A),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' of \$${bankrollGoal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        color: Color(0xFF9A9A9A),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '\$${(bankrollGoal - currentBankroll).toStringAsFixed(0)} left',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF9A9A9A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              ],
                            ),
                          ),
                          // Circular Progress with Animation
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              final animatedProgress = _progressAnimation.value * bankrollProgress;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: CircularProgressIndicator(
                                      value: animatedProgress,
                                      strokeWidth: 6,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: Color(0xFF2A2A2E),
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5AC95A)),
                                    ),
                                  ),
                                  Text(
                                    '${(animatedProgress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Metrics Grid (2x2)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildMetricCard(
                      title: 'Sessions',
                      value: '${playerStats['totalSessions'] ?? 0}',
                      unit: '',
                      iconColor: Color(0xFF5B9CDF),
                    ),
                    _buildMetricCard(
                      title: 'Win Rate',
                      value: '${(playerStats['winRate'] ?? 0.0).toStringAsFixed(0)}%',
                      unit: '',
                      iconColor: Color(0xFF9B59B6),
                    ),
                    _buildMetricCard(
                      title: 'Hours',
                      value: '${(playerStats['totalHours'] ?? 0.0).toStringAsFixed(1)}',
                      unit: '',
                      iconColor: Color(0xFF5B9CDF),
                    ),
                    _buildMetricCard(
                      title: 'Play Style',
                      value: _getPlayStyleName(),
                      unit: '',
                      iconColor: Color(0xFFE67E22),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                // Earnings Chart Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Earnings',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Avg ${avgEarnings >= 0 ? '\$' : '-\$'}${avgEarnings.abs().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: avgEarnings >= 0 ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          _buildLegendItem('Tournament', Color(0xFF5B9CDF)),
                          SizedBox(width: 20),
                          _buildLegendItem('Cash Game', Color(0xFF5AC95A)),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 200,
                        child: _buildEarningsChart(),
                      ),
                    ],
                  ),
                ),
                
                // Recent Sessions Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Sessions',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                                fontSize: 16,
                                color: Color(0xFF5AC95A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildRecentSessionsList(),
                    ],
                  ),
                ),
                
                // Calendar Widget
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  margin: EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Upcoming Events',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CalendarScreen()),
                              );
                              // Reload events after returning from calendar screen
                              _loadData();
                            },
                            child: Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF5AC95A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildUpcomingEvents(),
                    ],
                  ),
                ),
                
                      SizedBox(height: 100), // Space for bottom navigation
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Floating Bottom Navigation
          Positioned(
            bottom: 16,
            left: 24,
            right: 24,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomNavItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    index: 0,
                    onTap: () => _onNavItemTapped(0),
                  ),
                  _buildBottomNavItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Stats',
                    index: 1,
                    onTap: () => _onNavItemTapped(1),
                  ),
                  _buildBottomNavItem(
                    icon: Icons.add,
                    label: 'Start',
                    index: 2,
                    onTap: () => _onNavItemTapped(2),
                    isCenter: true,
                  ),
                  _buildBottomNavItem(
                    icon: Icons.people_outline,
                    label: 'Opponents',
                    index: 3,
                    onTap: () => _onNavItemTapped(3),
                  ),
                  _buildBottomNavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    index: 4,
                    onTap: () => _onNavItemTapped(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEE, d MMM').format(now);
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    switch (index) {
      case 0:
        // Home - already here
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StatisticsScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoggingModeSelectionScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MyOpponentsScreen()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        ).then((_) {
          // Reload data when returning from profile
          _loadData();
        });
        break;
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _getIconForTitle(title, iconColor),
            ],
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9A9A9A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIconForTitle(String title, Color iconColor) {
    switch (title) {
      case 'Sessions':
        return Image.asset(
          'assets/session.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        );
      case 'Win Rate':
        return Image.asset(
          'assets/trophy.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        );
      case 'Hours':
        return Image.asset(
          'assets/clock.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        );
      case 'Play Style':
        return Image.asset(
          'assets/play_style/${_getPlayStyleIcon()}',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        );
      default:
        return Icon(Icons.analytics, color: iconColor, size: 32);
    }
  }

  // Play style detection methods
  String _getPlayStyleName() {
    // Get stats from playerStats
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

    return PlayStyleDetector.getStyleAbbreviation(result['style']!);
  }

  String _getPlayStyleIcon() {
    // Get stats from playerStats
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

    return result['icon']!;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9A9A9A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsChart() {
    // Show empty state if no data
    if (earningsChartData.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'icons/stats.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 12),
              Text(
                'No earnings data yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Add session results to see your progress',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9A9A9A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CustomPaint(
      painter: EarningsChartPainter(earningsChartData),
      size: Size.infinite,
    );
  }

  Future<List<Map<String, dynamic>>> _loadCalendarEvents() async {
    try {
      print('🏠 Home screen: Loading calendar events...');
      // Load upcoming events from Firebase
      final events = await CalendarEventService.getUpcomingEvents();
      print('🏠 Home screen: Loaded ${events.length} events');
      for (final event in events) {
        print('  - ${event['title']} on ${event['date']}');
      }
      return events;
    } catch (e) {
      print('❌ Error loading calendar events: $e');
      return [];
    }
  }

  Widget _buildUpcomingEvents() {
    // Events are already filtered to future events in _loadCalendarEvents
    if (upcomingEvents.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'icons/calendar.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 8),
              Text(
                'No upcoming events',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show only the first 3 upcoming events
    final displayEvents = upcomingEvents.take(3).toList();

    return Column(
      children: displayEvents.map((event) => _buildEventItem(event)).toList(),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    // Format the date to be more readable
    String formattedDate = '';
    try {
      final dateTime = DateTime.parse(event['date']);
      final dateFormat = DateFormat('MMM dd, h:mm a'); // e.g., "Oct 27, 7:00 PM"
      formattedDate = dateFormat.format(dateTime);
    } catch (e) {
      formattedDate = event['date'] ?? '';
    }

    return InkWell(
      onTap: () => _showEventOptionsDialog(event),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
        children: [
          _getEventTypeImage(event['type']),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] ?? 'Poker Event',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9A9A9A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (event['buyIn'] != null && event['buyIn'] > 0)
            Text(
              '\$${event['buyIn'].toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF5AC95A),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
        ),
      ),
    );
  }

  void _showEventOptionsDialog(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F1F23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          event['title'] ?? 'Event Options',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit Event', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showEditEventDialog(event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Event', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteEventConfirmation(event);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditEventDialog(Map<String, dynamic> event) async {
    final titleController = TextEditingController(text: event['title']);
    final locationController = TextEditingController(text: event['location']);
    final buyInController = TextEditingController(text: event['buyIn'].toString());

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
                              final date = await showDatePicker(
                                context: context,
                                initialDate: dialogSelectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
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
                                color: Color(0xFF181D1B),
                                border: Border.all(color: Colors.transparent),
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
                                await _updateEvent(
                                  event['id'],
                                  title,
                                  selectedType,
                                  locationController.text.trim(),
                                  eventDateTime,
                                  double.tryParse(buyInController.text) ?? 0.0,
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

  void _showDeleteEventConfirmation(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F1F23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Event?',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${event['title']}"?',
          style: TextStyle(color: Color(0xFF9A9A9A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteEvent(event['id']);
              Navigator.pop(context);
              _loadData(); // Reload to remove deleted event
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEvent(
    String id,
    String title,
    String type,
    String location,
    DateTime date,
    double buyIn,
  ) async {
    try {
      await CalendarEventService.updateEvent(
        eventId: id,
        title: title,
        type: type,
        location: location,
        date: date,
        buyIn: buyIn,
      );
    } catch (e) {
      print('Error updating event: $e');
    }
  }

  Future<void> _deleteEvent(String id) async {
    try {
      await CalendarEventService.deleteEvent(id);
    } catch (e) {
      print('Error deleting event: $e');
    }
  }

  Color _getEventTypeColor(String? type) {
    switch (type) {
      case 'Tournament':
        return Color(0xFF5B9CDF);
      case 'Cash Game':
        return Color(0xFF5AC95A);
      case 'Home Game':
        return Color(0xFFE67E22);
      case 'Online':
        return Color(0xFF8B5CF6);
      default:
        return Color(0xFF9A9A9A);
    }
  }

  Widget _getEventTypeImage(String? type) {
    switch (type) {
      case 'Tournament':
        return Image.asset('icons/podium.png', width: 48, height: 48);
      case 'Cash Game':
        return Image.asset('icons/cash.png', width: 48, height: 48);
      case 'Home Game':
        return Icon(Icons.home, color: Color(0xFFE67E22), size: 48);
      case 'Online':
        return Icon(Icons.computer, color: Color(0xFF8B5CF6), size: 48);
      default:
        return Icon(Icons.event, color: Color(0xFF9A9A9A), size: 48);
    }
  }

  IconData _getEventTypeIcon(String? type) {
    switch (type) {
      case 'Tournament':
        return Icons.emoji_events;
      case 'Cash Game':
        return Icons.attach_money;
      case 'Home Game':
        return Icons.home;
      case 'Online':
        return Icons.computer;
      default:
        return Icons.event;
    }
  }

  Widget _buildRecentSessionsList() {
    if (recentSessions.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 44, horizontal: 8),
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
            SizedBox(height: 20),
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
                  SizedBox(height: 8),
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
      );
    }

    return Column(
      children: recentSessions.map((session) => _buildSessionItem(session)).toList(),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    String sessionName = session['sessionName'] ?? '';

    // If no sessionName, create a meaningful one based on available data
    if (sessionName.isEmpty) {
      final createdAt = _parseSessionDate(session);
      final gameType = session['gameType'] ?? 'Poker';
      final dateStr = DateFormat('MMM d').format(createdAt);
      sessionName = '$gameType Session - $dateStr';
    }
    
    final createdAt = _parseSessionDate(session);
    
    return GestureDetector(
      onTap: () {
        // Navigate to session history screen and scroll to this session
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionHistoryScreen(targetSessionId: session['id']),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
        children: [
          Image.asset(
            'assets/session.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9A9A9A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFF9A9A9A),
            size: 16,
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
    bool isCenter = false,
  }) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCenter ? 64 : 44,
        height: isCenter ? 64 : 44,
        decoration: BoxDecoration(
          gradient: isCenter && isSelected 
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFcb5242),
                  Color(0xFFb8442f),
                ],
              )
            : null,
          borderRadius: BorderRadius.circular(isCenter ? 18 : 14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isCenter && isSelected 
                ? Colors.white
                : (isSelected ? Color(0xFFcb5242) : Colors.white.withOpacity(0.7)),
              size: isCenter ? 26 : 20,
            ),
            if (isCenter) ...[
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

    // Chart area (leaving space for axes and labels)
    final chartArea = Rect.fromLTWH(50, 20, size.width - 70, size.height - 50);

    // Find max and min values for scaling (including negatives)
    double maxValue = 0;
    double minValue = 0;
    for (var point in data) {
      final tournament = (point['tournament'] as num?)?.toDouble() ?? 0.0;
      final cash = (point['cash'] as num?)?.toDouble() ?? 0.0;
      maxValue = math.max(maxValue, math.max(tournament, cash));
      minValue = math.min(minValue, math.min(tournament, cash));
    }

    // Ensure minimum scale
    if (maxValue == 0 && minValue == 0) {
      maxValue = 100;
      minValue = -100;
    }

    // Round to nearest 100
    maxValue = ((maxValue / 100).ceil() * 100).toDouble();
    minValue = ((minValue / 100).floor() * 100).toDouble();

    final valueRange = maxValue - minValue;

    // Calculate zero line position
    final zeroY = chartArea.bottom - ((0 - minValue) / valueRange) * chartArea.height;

    // Draw axes
    final axisPaint = Paint()
      ..color = Color(0xFF9A9A9A)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Y-axis
    canvas.drawLine(
      Offset(chartArea.left, chartArea.top),
      Offset(chartArea.left, chartArea.bottom),
      axisPaint,
    );

    // Zero line (X-axis)
    canvas.drawLine(
      Offset(chartArea.left, zeroY),
      Offset(chartArea.right, zeroY),
      axisPaint,
    );

    // Draw Y-axis labels
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    // Draw 5 labels from min to max
    for (int i = 0; i <= 4; i++) {
      final value = minValue + (i * valueRange / 4);
      textPainter.text = TextSpan(
        text: '\$${value.toInt()}',
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 10,
        ),
      );
      textPainter.layout();

      final y = chartArea.bottom - (i / 4) * chartArea.height;
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // Calculate bar width and spacing
    final barGroupWidth = chartArea.width / data.length;
    final barWidth = (barGroupWidth - 16) / 2; // 2 bars per group with spacing
    final spacing = 4.0; // Space between tournament and cash bars

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final tournamentValue = (data[i]['tournament'] as num?)?.toDouble() ?? 0.0;
      final cashValue = (data[i]['cash'] as num?)?.toDouble() ?? 0.0;

      // Calculate x position for this group
      final groupX = chartArea.left + (i * barGroupWidth) + 8;

      // Draw tournament bar (left bar in group)
      final tournamentBarX = groupX;
      final tournamentHeight = ((tournamentValue - 0) / valueRange) * chartArea.height;
      final tournamentTop = tournamentValue >= 0
          ? zeroY - tournamentHeight.abs()
          : zeroY;
      final tournamentBarHeight = tournamentHeight.abs();

      if (tournamentBarHeight > 0) {
        paint.color = Color(0xFF5B9CDF);
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

      // Draw cash bar (right bar in group)
      final cashBarX = groupX + barWidth + spacing;
      final cashHeight = ((cashValue - 0) / valueRange) * chartArea.height;
      final cashTop = cashValue >= 0
          ? zeroY - cashHeight.abs()
          : zeroY;
      final cashBarHeight = cashHeight.abs();

      if (cashBarHeight > 0) {
        paint.color = Color(0xFF5AC95A);
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

      // Draw X-axis label (date) centered under the bar group
      textPainter.text = TextSpan(
        text: data[i]['date'],
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 10,
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