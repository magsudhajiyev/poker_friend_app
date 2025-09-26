import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/bankroll_service.dart';
import '../widgets/loading_screen.dart';

class BankrollScreen extends StatefulWidget {
  @override
  _BankrollScreenState createState() => _BankrollScreenState();
}

class _BankrollScreenState extends State<BankrollScreen> with TickerProviderStateMixin {
  double currentBankroll = 0.0;
  double bankrollGoal = 20000.0;
  double startingBankroll = 5000.0;
  double todayChange = 0.0;
  double weekChange = 0.0;
  double monthChange = 0.0;
  bool isLoading = true;

  List<Map<String, dynamic>> recentTransactions = [];
  List<Map<String, dynamic>> monthlyData = [];

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _adjustmentController = TextEditingController();

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

    _loadBankrollData();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _goalController.dispose();
    _adjustmentController.dispose();
    super.dispose();
  }

  Future<void> _loadBankrollData() async {
    setState(() => isLoading = true);

    try {
      // Load current data
      currentBankroll = await BankrollService.getCurrentBankroll();
      bankrollGoal = await BankrollService.getBankrollGoal();

      // Generate mock data for now (replace with real data later)
      _generateMockData();

      _progressAnimationController.forward();
    } catch (e) {
      print('Error loading bankroll data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _generateMockData() {
    // Generate recent transactions
    recentTransactions = [
      {'date': DateTime.now().subtract(Duration(hours: 2)), 'amount': 350.0, 'type': 'Session Win', 'location': 'Home Game'},
      {'date': DateTime.now().subtract(Duration(days: 1)), 'amount': -125.0, 'type': 'Session Loss', 'location': 'Casino'},
      {'date': DateTime.now().subtract(Duration(days: 2)), 'amount': 280.0, 'type': 'Session Win', 'location': 'Online'},
      {'date': DateTime.now().subtract(Duration(days: 3)), 'amount': -200.0, 'type': 'Session Loss', 'location': 'Casino'},
      {'date': DateTime.now().subtract(Duration(days: 5)), 'amount': 150.0, 'type': 'Deposit', 'location': 'Bank Transfer'},
    ];

    // Calculate changes
    todayChange = 350.0;
    weekChange = 255.0;
    monthChange = 1200.0;

    // Generate monthly data for chart
    monthlyData = List.generate(6, (index) {
      return {
        'month': DateFormat('MMM').format(DateTime.now().subtract(Duration(days: 30 * (5 - index)))),
        'profit': (500 + (index * 200) + (index * 50 * (index.isEven ? 1 : -1))).toDouble(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return LoadingScreen();
    }

    final progress = bankrollGoal > 0 ? (currentBankroll / bankrollGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Color(0xFF1F1F23),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bankroll Management',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Track your poker finances',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _showSettingsDialog,
                      icon: Icon(Icons.settings, color: Color(0xFF9A9A9A), size: 20),
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
                    // Current Bankroll Card
                    _buildBankrollCard(),

                    SizedBox(height: 24),

                    // Goal Progress Card
                    _buildGoalCard(progress),

                    SizedBox(height: 24),

                    // Performance Cards
                    _buildPerformanceCards(),

                    SizedBox(height: 24),

                    // Monthly Chart
                    _buildMonthlyChart(),

                    SizedBox(height: 24),

                    // Recent Transactions
                    _buildRecentTransactions(),

                    SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankrollCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5AC95A),
            Color(0xFF4A9F4A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Bankroll',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '\$${currentBankroll.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      todayChange >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '\$${todayChange.abs().toStringAsFixed(0)} today',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(double progress) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
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
                'Bankroll Goal',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _showGoalDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5AC95A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
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
                              fontSize: 24,
                              color: Color(0xFF5AC95A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' / \$${bankrollGoal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24,
                              color: Color(0xFF9A9A9A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\$${(bankrollGoal - currentBankroll).toStringAsFixed(0)} remaining',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF9A9A9A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  final animatedProgress = _progressAnimation.value * progress;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
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
                          fontSize: 16,
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
    );
  }

  Widget _buildPerformanceCards() {
    return Row(
      children: [
        Expanded(
          child: _buildPerformanceCard('Week', weekChange, Icons.calendar_view_week),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildPerformanceCard('Month', monthChange, Icons.calendar_month),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(String period, double amount, IconData icon) {
    final isPositive = amount >= 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFF9A9A9A), size: 20),
              SizedBox(width: 8),
              Text(
                period,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '${isPositive ? '+' : ''}\$${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              color: isPositive ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Performance',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Container(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthlyData.map((data) {
                final maxValue = monthlyData.map((d) => d['profit'] as double).reduce((a, b) => a > b ? a : b);
                final height = ((data['profit'] as double) / maxValue * 80).clamp(20.0, 80.0);
                final isPositive = (data['profit'] as double) >= 0;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: height,
                        decoration: BoxDecoration(
                          color: isPositive ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        data['month'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A9A9A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
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
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to full transaction history
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5AC95A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...recentTransactions.take(5).map((transaction) {
            final isPositive = (transaction['amount'] as double) >= 0;
            final date = transaction['date'] as DateTime;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF2A2A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPositive ? Color(0xFF5AC95A).withOpacity(0.2) : Color(0xFFFF6B6B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPositive ? Icons.add : Icons.remove,
                      color: isPositive ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction['type'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${transaction['location']} • ${DateFormat('MMM d, h:mm a').format(date)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}\$${(transaction['amount'] as double).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isPositive ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Add Funds',
                  Icons.add,
                  Color(0xFF5AC95A),
                  () => _showAdjustmentDialog(true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Withdraw',
                  Icons.remove,
                  Color(0xFFFF6B6B),
                  () => _showAdjustmentDialog(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalDialog() {
    _goalController.text = bankrollGoal.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F1F23),
        title: Text('Set Bankroll Goal', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _goalController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter goal amount',
            hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
            prefixText: '\$',
            prefixStyle: TextStyle(color: Colors.white),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2A2A2E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2A2A2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF5AC95A)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF9A9A9A))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newGoal = double.tryParse(_goalController.text);
              if (newGoal != null && newGoal > 0) {
                await BankrollService.setBankrollGoal(newGoal);
                setState(() {
                  bankrollGoal = newGoal;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5AC95A),
            ),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDialog(bool isDeposit) {
    _adjustmentController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F1F23),
        title: Text(
          isDeposit ? 'Add Funds' : 'Withdraw Funds',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _adjustmentController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixText: '\$',
                prefixStyle: TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5AC95A)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF9A9A9A))),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_adjustmentController.text);
              if (amount != null && amount > 0) {
                final adjustmentAmount = isDeposit ? amount : -amount;
                // For now, just update locally (implement proper backend later)
                setState(() {
                  currentBankroll += adjustmentAmount;
                  recentTransactions.insert(0, {
                    'date': DateTime.now(),
                    'amount': adjustmentAmount,
                    'type': isDeposit ? 'Deposit' : 'Withdrawal',
                    'location': 'Manual Adjustment',
                  });
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeposit ? Color(0xFF5AC95A) : Color(0xFFFF6B6B),
            ),
            child: Text(
              isDeposit ? 'Add' : 'Withdraw',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1F1F23),
        title: Text('Bankroll Settings', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.flag, color: Color(0xFF5AC95A)),
              title: Text('Change Goal', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showGoalDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: Color(0xFF9A9A9A)),
              title: Text('Reset Data', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Implement reset functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: Color(0xFF9A9A9A)),
              title: Text('Export Data', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Implement export functionality
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Color(0xFF9A9A9A))),
          ),
        ],
      ),
    );
  }
}