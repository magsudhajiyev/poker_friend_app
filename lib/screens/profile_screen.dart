import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/bankroll_service.dart';
import '../services/session_result_service.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_debug_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _goalController = TextEditingController();
  final _bankrollController = TextEditingController();
  final _sessionResultController = TextEditingController();

  double currentBankroll = 0.0;
  double bankrollGoal = 0.0;
  bool isLoading = true;
  String _selectedGameType = 'cash'; // Default to cash

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _bankrollController.dispose();
    _sessionResultController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final bankroll = await BankrollService.getCurrentBankroll();
      final goal = await BankrollService.getBankrollGoal();

      if (mounted) {
        setState(() {
          currentBankroll = bankroll;
          bankrollGoal = goal;
          _goalController.text = goal.toStringAsFixed(0);
          _bankrollController.text = bankroll.toStringAsFixed(0);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateGoal() async {
    try {
      final newGoal = double.tryParse(_goalController.text) ?? 0.0;
      if (newGoal > 0) {
        await BankrollService.setBankrollGoal(newGoal);
        setState(() {
          bankrollGoal = newGoal;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal updated successfully!'),
            backgroundColor: Color(0xFF5AC95A),
          ),
        );
      }
    } catch (e) {
      print('Error updating goal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating goal'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateBankroll() async {
    try {
      final newBankroll = double.tryParse(_bankrollController.text) ?? 0.0;
      if (newBankroll >= 0) {
        await BankrollService.setCurrentBankroll(newBankroll);
        setState(() {
          currentBankroll = newBankroll;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bankroll updated successfully!'),
            backgroundColor: Color(0xFF5AC95A),
          ),
        );
      }
    } catch (e) {
      print('Error updating bankroll: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bankroll'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addSessionResult() async {
    try {
      final result = double.tryParse(_sessionResultController.text) ?? 0.0;

      if (result == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid amount'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add to bankroll
      await BankrollService.addToBankroll(result);

      // Save session result with game type
      await SessionResultService.addSessionResult(
        amount: result,
        gameType: _selectedGameType,
      );

      // Reload data
      await _loadData();

      _sessionResultController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session result added!'),
          backgroundColor: Color(0xFF5AC95A),
        ),
      );
    } catch (e) {
      print('Error adding session result: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding session result'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF161618),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5AC95A)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF161618),
      body: SafeArea(
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
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // User Info Card
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
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AuthService.userDisplayName,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                AuthService.currentUser?.email ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF9A9A9A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bankroll Goal Card
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
                        'Bankroll Goal',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _goalController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Enter your goal amount',
                          hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: Color(0xFF5AC95A), fontSize: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF5AC95A)),
                          ),
                          filled: true,
                          fillColor: Color(0xFF2A2A2E),
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateGoal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5AC95A),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Update Goal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Current Bankroll Card
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
                        'Current Bankroll',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _bankrollController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Enter current amount',
                          hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: Color(0xFF5AC95A), fontSize: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF5AC95A)),
                          ),
                          filled: true,
                          fillColor: Color(0xFF2A2A2E),
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateBankroll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5B9CDF),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Update Bankroll',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Add Session Result Card
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
                        'Add Session Result',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Enter positive for wins, negative for losses',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9A9A9A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 16),
                      // Game Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedGameType = 'cash'),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedGameType == 'cash' ? Color(0xFF5AC95A) : Color(0xFF2A2A2E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedGameType == 'cash' ? Color(0xFF5AC95A) : Color(0xFF3A3A3E),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Cash Game',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedGameType = 'tournament'),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedGameType == 'tournament' ? Color(0xFF5B9CDF) : Color(0xFF2A2A2E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedGameType == 'tournament' ? Color(0xFF5B9CDF) : Color(0xFF3A3A3E),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Tournament',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _sessionResultController,
                        keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'e.g., +250 or -150',
                          hintStyle: TextStyle(color: Color(0xFF9A9A9A)),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: Color(0xFF5AC95A), fontSize: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Color(0xFF5AC95A)),
                          ),
                          filled: true,
                          fillColor: Color(0xFF2A2A2E),
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addSessionResult,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF8B5CF6),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Add Result',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Subscription Debug Card (DEV ONLY - Remove in production)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 24),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionDebugScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1F1F23),
                      padding: EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: Color(0xFFE67E22).withOpacity(0.3)),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(0xFFE67E22).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.bug_report,
                            color: Color(0xFFE67E22),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subscription Debug',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'DEV ONLY',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE67E22),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFFE67E22),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

                // Settings Card
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 24),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1F1F23),
                      padding: EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(0xFF2A2A2E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.settings_outlined,
                            color: Color(0xFF9A9A9A),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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
                ),

                // Log Out Button
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 24),
                  child: ElevatedButton(
                    onPressed: () async {
                      // Show confirmation dialog
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Color(0xFF1F1F23),
                          title: Text(
                            'Log Out',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Text(
                            'Are you sure you want to log out?',
                            style: TextStyle(color: Color(0xFF9A9A9A)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Color(0xFF9A9A9A)),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: Text(
                                'Log Out',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await AuthService.signOut();
                        if (mounted) {
                          // Navigate to AuthScreen and remove all routes
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1F1F23),
                      padding: EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.logout,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.red,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
        ),
      ),
    );
  }
}