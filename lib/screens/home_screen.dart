import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:intl/intl.dart';
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
import '../screens/auth_screen.dart';
import '../screens/bankroll_screen.dart';
import '../widgets/loading_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 2; // Start tab is selected by default
  
  // Data variables
  double currentBankroll = 0.0;
  double bankrollGoal = 0.0;
  double bankrollProgress = 0.0;
  
  // Animation variables
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  Map<String, dynamic> playerStats = {};
  List<Map<String, dynamic>> recentSessions = [];
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
      
      final bankroll = await BankrollService.getCurrentBankroll();
      final goal = await BankrollService.getBankrollGoal();
      final progress = await BankrollService.getBankrollProgress();
      final stats = await BankrollService.getPlayerStatistics();
      final sessions = await _getRecentSessions();

      if (mounted) {
        setState(() {
          currentBankroll = bankroll;
          bankrollGoal = goal;
          bankrollProgress = progress;
          playerStats = stats;
          recentSessions = sessions;
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
        print('📱 DEBUG: Loaded ${sessions.length} sessions from Firebase');
      } catch (e) {
        sessions = await LocalStorageService.getUserSessions();
        print('📱 DEBUG: Loaded ${sessions.length} sessions from LocalStorage');
      }
      
      print('📱 DEBUG: All sessions: ${sessions.map((s) => s['createdAt']).toList()}');
      
      // Sort by date and take the latest 3
      sessions.sort((a, b) {
        try {
          DateTime dateA = _parseSessionDate(a);
          DateTime dateB = _parseSessionDate(b);
          
          return dateB.compareTo(dateA);
        } catch (e) {
          print('📱 DEBUG: Error parsing dates: $e');
          return 0;
        }
      });
      
      List<Map<String, dynamic>> recent = sessions.take(3).toList();
      print('📱 DEBUG: Recent 3 sessions: ${recent.map((s) => s['sessionName'] ?? s['id']).toList()}');
      
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
      print('📱 DEBUG: Error parsing session date: $e');
      return DateTime(2000);
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
                            'Hi, Mike!',
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BankrollScreen(),
                      ),
                    );
                  },
                  child: Container(
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
                            'Avg this week \$582',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9A9A9A),
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CalendarScreen()),
                              );
                            },
                            child: Text(
                              'View Calendar',
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
    // For now, return TAG as demonstration
    // In future, this will be calculated based on user's session data
    return 'TAG';
  }

  String _getPlayStyleIcon() {
    // This method will dynamically determine which icon to show
    // based on the detected play style
    final playStyle = _detectPlayStyle();
    return '${playStyle.toLowerCase()}.png';
  }

  String _detectPlayStyle() {
    // Placeholder algorithm - for now returns TAG for demonstration
    // In the future, this will analyze user's session data and calculate:
    // - VPIP (Voluntarily Put money In Pot percentage)
    // - PFR (Pre-Flop Raise percentage) 
    // - Aggression factor
    // - Number of hands played
    // 
    // Play style classifications:
    // - TAG (Tight Aggressive): Low VPIP (15-25%), High PFR (12-20%), High aggression
    // - LAG (Loose Aggressive): High VPIP (25-35%), High PFR (18-25%), High aggression  
    // - Nit: Very low VPIP (<15%), Low PFR (<10%), Low aggression
    // - Maniac: Very high VPIP (>40%), Very high PFR (>30%), Very high aggression
    // - Fish: High VPIP (>30%), Low PFR (<15%), Low aggression
    
    return 'tag'; // For demonstration, always return TAG
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
    // Dummy data for the chart
    final List<Map<String, dynamic>> chartData = [
      {'date': 'Sep 1', 'tournament': 150, 'cash': 200},
      {'date': 'Sep 3', 'tournament': 300, 'cash': 150},
      {'date': 'Sep 5', 'tournament': 100, 'cash': 350},
      {'date': 'Sep 7', 'tournament': 450, 'cash': 100},
      {'date': 'Sep 9', 'tournament': 200, 'cash': 400},
      {'date': 'Sep 11', 'tournament': 350, 'cash': 250},
    ];

    return CustomPaint(
      painter: EarningsChartPainter(chartData),
      size: Size.infinite,
    );
  }

  Widget _buildUpcomingEvents() {
    // Mock upcoming events - replace with real data later
    final upcomingEvents = [
      {
        'title': 'Friday Night Tournament',
        'date': 'Sep 15, 7:00 PM',
        'type': 'Tournament',
        'buyIn': 50.0,
      },
      {
        'title': 'Weekend Cash Game',
        'date': 'Sep 16, 2:00 PM', 
        'type': 'Cash Game',
        'buyIn': 100.0,
      },
    ];

    if (upcomingEvents.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_outlined,
                size: 32,
                color: Color(0xFF9A9A9A),
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

    return Column(
      children: upcomingEvents.map((event) => _buildEventItem(event)).toList(),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    return Container(
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
                  event['date'] ?? '',
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
    );
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
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/session.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 8),
              Text(
                'No sessions yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Start your first poker session!',
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

// Custom painter for earnings chart
class EarningsChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  EarningsChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Chart area (leaving space for axes)
    final chartArea = Rect.fromLTWH(40, 20, size.width - 60, size.height - 60);
    
    // Draw axes
    paint.color = Color(0xFF9A9A9A);
    paint.strokeWidth = 1;
    
    // Y-axis
    canvas.drawLine(
      Offset(chartArea.left, chartArea.top),
      Offset(chartArea.left, chartArea.bottom),
      paint,
    );
    
    // X-axis
    canvas.drawLine(
      Offset(chartArea.left, chartArea.bottom),
      Offset(chartArea.right, chartArea.bottom),
      paint,
    );

    // Draw Y-axis labels
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );
    
    for (int i = 0; i <= 4; i++) {
      final value = (i * 100).toString();
      textPainter.text = TextSpan(
        text: '\$${value}',
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      
      final y = chartArea.bottom - (i / 4) * chartArea.height;
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // Draw X-axis labels
    for (int i = 0; i < data.length; i++) {
      textPainter.text = TextSpan(
        text: data[i]['date'],
        style: TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      
      final x = chartArea.left + (i / (data.length - 1)) * chartArea.width;
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, chartArea.bottom + 5));
    }

    // Draw data lines
    paint.strokeWidth = 3;
    
    // Helper function to create smooth cubic bezier curves
    List<Offset> _createSmoothCurvePoints(List<double> values, Rect chartArea) {
      List<Offset> points = [];
      for (int i = 0; i < values.length; i++) {
        final x = chartArea.left + (i / (values.length - 1)) * chartArea.width;
        final y = chartArea.bottom - (values[i] / 500.0) * chartArea.height;
        points.add(Offset(x, y));
      }
      return points;
    }

    // Helper function to draw smooth curve with cubic bezier
    void _drawSmoothCurve(Path path, List<Offset> points) {
      if (points.isEmpty) return;

      path.moveTo(points[0].dx, points[0].dy);

      if (points.length == 2) {
        path.lineTo(points[1].dx, points[1].dy);
        return;
      }

      // Calculate control points for smooth cubic bezier curves
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i < points.length - 2 ? points[i + 2] : p2;

        // Calculate tension for smoother curves
        const tension = 0.3;

        // Calculate control points
        final cp1x = p1.dx + (p2.dx - p0.dx) * tension;
        final cp1y = p1.dy + (p2.dy - p0.dy) * tension;
        final cp2x = p2.dx - (p3.dx - p1.dx) * tension;
        final cp2y = p2.dy - (p3.dy - p1.dy) * tension;

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }
    }

    // Tournament line (blue) - smooth curves
    paint.color = Color(0xFF5B9CDF);
    final tournamentPath = Path();
    final tournamentValues = data.map<double>((d) => d['tournament'].toDouble()).toList();
    final tournamentPoints = _createSmoothCurvePoints(tournamentValues, chartArea);
    _drawSmoothCurve(tournamentPath, tournamentPoints);
    canvas.drawPath(tournamentPath, paint);

    // Cash game line (green) - smooth curves
    paint.color = Color(0xFF5AC95A);
    final cashPath = Path();
    final cashValues = data.map<double>((d) => d['cash'].toDouble()).toList();
    final cashPoints = _createSmoothCurvePoints(cashValues, chartArea);
    _drawSmoothCurve(cashPath, cashPoints);
    canvas.drawPath(cashPath, paint);

    // Draw data points
    paint.style = PaintingStyle.fill;
    
    for (int i = 0; i < data.length; i++) {
      final x = chartArea.left + (i / (data.length - 1)) * chartArea.width;
      
      // Tournament points
      final tournamentY = chartArea.bottom - (data[i]['tournament'] / 500.0) * chartArea.height;
      paint.color = Color(0xFF5B9CDF);
      canvas.drawCircle(Offset(x, tournamentY), 4, paint);
      
      // Cash game points
      final cashY = chartArea.bottom - (data[i]['cash'] / 500.0) * chartArea.height;
      paint.color = Color(0xFF5AC95A);
      canvas.drawCircle(Offset(x, cashY), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}