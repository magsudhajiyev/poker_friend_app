import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/game_types.dart';
import 'individual_session_tracking_screen.dart';

class IndividualSessionSetupScreen extends StatefulWidget {
  const IndividualSessionSetupScreen({super.key});

  @override
  State<IndividualSessionSetupScreen> createState() => _IndividualSessionSetupScreenState();
}

class _IndividualSessionSetupScreenState extends State<IndividualSessionSetupScreen> {
  // Form controllers
  final TextEditingController _sessionNameController = TextEditingController();
  final TextEditingController _buyInController = TextEditingController();
  final TextEditingController _startingStackController = TextEditingController();
  final TextEditingController _smallBlindController = TextEditingController();
  final TextEditingController _bigBlindController = TextEditingController();

  // Game settings
  GameType gameType = GameType.cash;
  int smallBlind = 1;
  int bigBlind = 2;
  bool hasBBante = false;

  // Form validation
  bool get isFormValid {
    return _sessionNameController.text.isNotEmpty &&
           _buyInController.text.isNotEmpty &&
           _startingStackController.text.isNotEmpty &&
           double.tryParse(_buyInController.text) != null &&
           double.tryParse(_startingStackController.text) != null;
  }

  @override
  void initState() {
    super.initState();
    // Initialize blind controllers with default values
    _smallBlindController.text = smallBlind.toString();
    _bigBlindController.text = bigBlind.toString();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    _buyInController.dispose();
    _startingStackController.dispose();
    _smallBlindController.dispose();
    _bigBlindController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
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
                  padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Setup',
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Individual session tracking',
                            style: TextStyle(
                              fontSize: 16,
                              color: PokerFriendColors.dark9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: PokerFriendColors.dark3,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Session Name Input
                _buildInputCard(
                  title: 'Session Name',
                  icon: Icons.edit,
                  child: TextField(
                    controller: _sessionNameController,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'e.g., "Friday Night Poker"',
                      hintStyle: TextStyle(color: PokerFriendColors.dark9),
                      filled: true,
                      fillColor: PokerFriendColors.dark1,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),

                SizedBox(height: 24),

                // Buy-in Amount Input
                _buildInputCard(
                  title: 'Buy-in Amount',
                  icon: Icons.monetization_on,
                  child: TextField(
                    controller: _buyInController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter buy-in amount',
                      hintStyle: TextStyle(color: PokerFriendColors.dark9),
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(color: Colors.white, fontSize: 16),
                      filled: true,
                      fillColor: PokerFriendColors.dark1,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),

                SizedBox(height: 24),

                // Starting Stack Input
                _buildInputCard(
                  title: 'Starting Stack',
                  icon: Icons.casino,
                  child: TextField(
                    controller: _startingStackController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter starting stack',
                      hintStyle: TextStyle(color: PokerFriendColors.dark9),
                      prefixText: gameType == GameType.cash ? '\$ ' : '',
                      prefixStyle: TextStyle(color: Colors.white, fontSize: 16),
                      filled: true,
                      fillColor: PokerFriendColors.dark1,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),

                SizedBox(height: 24),

                // Game Type Selection
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PokerFriendColors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.casino,
                              color: PokerFriendColors.red,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Game Type',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _GameTypeButton(
                              gameType: GameType.cash,
                              selectedGameType: gameType,
                              onTap: () => setState(() => gameType = GameType.cash),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _GameTypeButton(
                              gameType: GameType.tournament,
                              selectedGameType: gameType,
                              onTap: () => setState(() => gameType = GameType.tournament),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Blinds Settings
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PokerFriendColors.dark3,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PokerFriendColors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.attach_money,
                              color: PokerFriendColors.red,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Blinds',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBlindSelector(
                              label: 'Small Blind',
                              value: smallBlind,
                              controller: _smallBlindController,
                              onIncrement: () => setState(() {
                                smallBlind++;
                                _smallBlindController.text = smallBlind.toString();
                                if (bigBlind <= smallBlind) {
                                  bigBlind = smallBlind * 2;
                                  _bigBlindController.text = bigBlind.toString();
                                }
                              }),
                              onDecrement: () => setState(() {
                                if (smallBlind > 1) {
                                  smallBlind--;
                                  _smallBlindController.text = smallBlind.toString();
                                  if (bigBlind <= smallBlind) {
                                    bigBlind = smallBlind + 1;
                                    _bigBlindController.text = bigBlind.toString();
                                  }
                                }
                              }),
                              onChanged: (value) {
                                final parsedValue = int.tryParse(value);
                                if (parsedValue != null && parsedValue > 0) {
                                  setState(() {
                                    smallBlind = parsedValue;
                                    if (bigBlind <= smallBlind) {
                                      bigBlind = smallBlind * 2;
                                      _bigBlindController.text = bigBlind.toString();
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildBlindSelector(
                              label: 'Big Blind',
                              value: bigBlind,
                              controller: _bigBlindController,
                              onIncrement: () => setState(() {
                                bigBlind++;
                                _bigBlindController.text = bigBlind.toString();
                              }),
                              onDecrement: () => setState(() {
                                if (bigBlind > smallBlind + 1) {
                                  bigBlind--;
                                  _bigBlindController.text = bigBlind.toString();
                                }
                              }),
                              onChanged: (value) {
                                final parsedValue = int.tryParse(value);
                                if (parsedValue != null && parsedValue > smallBlind) {
                                  setState(() {
                                    bigBlind = parsedValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Ante switch (only for tournaments)
                      if (gameType == GameType.tournament) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: PokerFriendColors.dark3,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'BB Ante',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Switch(
                                value: hasBBante,
                                onChanged: (value) => setState(() => hasBBante = value),
                                activeColor: PokerFriendColors.red,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // Start Button
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: isFormValid
                      ? LinearGradient(
                          colors: [PokerFriendColors.red, Color(0xFFb8442f)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                    color: isFormValid ? null : PokerFriendColors.dark4,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ElevatedButton(
                    onPressed: isFormValid ? _startSession : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: isFormValid ? Colors.white : PokerFriendColors.dark9,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'START SESSION',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isFormValid ? Colors.white : PokerFriendColors.dark9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PokerFriendColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: PokerFriendColors.red,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBlindSelector({
    required String label,
    required int value,
    required TextEditingController controller,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: PokerFriendColors.dark9,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: PokerFriendColors.dark1,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Icon(Icons.remove, color: Colors.white, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    prefixText: gameType == GameType.cash ? '\$' : '',
                    prefixStyle: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startSession() {
    final sessionName = _sessionNameController.text;
    final buyIn = double.parse(_buyInController.text);
    final startingStack = double.parse(_startingStackController.text);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualSessionTrackingScreen(
          sessionName: sessionName,
          buyInAmount: buyIn,
          startingStack: startingStack,
          gameType: gameType,
          smallBlind: smallBlind,
          bigBlind: bigBlind,
          hasBBante: hasBBante,
        ),
      ),
    );
  }
}

class _GameTypeButton extends StatelessWidget {
  final GameType gameType;
  final GameType selectedGameType;
  final VoidCallback onTap;

  const _GameTypeButton({
    required this.gameType,
    required this.selectedGameType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = gameType == selectedGameType;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? PokerFriendColors.red : PokerFriendColors.dark1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? PokerFriendColors.red : PokerFriendColors.dark4,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              gameType.displayName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              gameType == GameType.cash ? 'Ring Game' : 'Multi-Table',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white.withOpacity(0.8) : PokerFriendColors.dark9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}