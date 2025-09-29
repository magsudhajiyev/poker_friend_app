import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/game_types.dart';
import 'individual_session_tracking_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'seat_setup_screen.dart';
import '../models/hand_state_machine.dart';

class IndividualSessionSetupScreen extends StatefulWidget {
  final LoggingMode? loggingMode;

  const IndividualSessionSetupScreen({super.key, this.loggingMode});

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
                            widget.loggingMode == LoggingMode.full
                              ? 'Full session tracking'
                              : 'Individual session tracking',
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
                  iconPath: 'icons/pencil.png',
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
                  iconPath: 'icons/cash.png',
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
                  iconPath: 'icons/ante.png',
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
                            child: Image.asset(
                              'icons/game_type.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
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

                // Blinds Settings - Grid Layout
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                    _buildBlindCard(
                      title: 'Small Blind',
                      value: gameType == GameType.cash ? '\$$smallBlind' : '$smallBlind',
                      iconPath: 'icons/small_blind.png',
                      onDecrement: () => setState(() {
                        if (smallBlind > 1) {
                          smallBlind--;
                          _smallBlindController.text = smallBlind.toString();
                        }
                      }),
                      onIncrement: () => setState(() {
                        smallBlind++;
                        _smallBlindController.text = smallBlind.toString();
                      }),
                      onValueTap: () => _showBlindInputDialog('Small Blind', smallBlind, (value) {
                        setState(() {
                          smallBlind = value;
                          _smallBlindController.text = smallBlind.toString();
                        });
                      }),
                    ),
                    _buildBlindCard(
                      title: 'Big Blind',
                      value: gameType == GameType.cash ? '\$$bigBlind' : '$bigBlind',
                      iconPath: 'icons/big_blind.png',
                      onDecrement: () => setState(() {
                        if (bigBlind > 1) {
                          bigBlind--;
                          _bigBlindController.text = bigBlind.toString();
                        }
                      }),
                      onIncrement: () => setState(() {
                        bigBlind++;
                        _bigBlindController.text = bigBlind.toString();
                      }),
                      onValueTap: () => _showBlindInputDialog('Big Blind', bigBlind, (value) {
                        setState(() {
                          bigBlind = value;
                          _bigBlindController.text = bigBlind.toString();
                        });
                      }),
                    ),
                  ],
                ),

                // Ante Card (only for tournaments)
                if (gameType == GameType.tournament) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PokerFriendColors.dark3,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'icons/ante.png',
                                  width: 32,
                                  height: 32,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'BB Ante',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: hasBBante,
                              onChanged: (value) => setState(() => hasBBante = value),
                              activeColor: PokerFriendColors.red,
                              trackColor: MaterialStateProperty.all(
                                hasBBante ? PokerFriendColors.red.withOpacity(0.3) : PokerFriendColors.dark4,
                              ),
                            ),
                          ],
                        ),
                        if (hasBBante) ...[
                          SizedBox(height: 8),
                          Text(
                            'Big blind posts ante for all players',
                            style: TextStyle(
                              fontSize: 12,
                              color: PokerFriendColors.dark9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

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
    required String iconPath,
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
                child: Image.asset(
                  iconPath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
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

  Widget _buildBlindCard({
    required String title,
    required String value,
    required String iconPath,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    VoidCallback? onValueTap,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
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
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Image.asset(
                iconPath,
                width: 32,
                height: 32,
              ),
            ],
          ),
          Spacer(),
          GestureDetector(
            onTap: onValueTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: onValueTap != null ? BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PokerFriendColors.red.withOpacity(0.3)),
              ) : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDecrement,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: PokerFriendColors.dark1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.remove,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onIncrement,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: PokerFriendColors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
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

  void _showBlindInputDialog(String title, int currentValue, Function(int) onConfirm) {
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: PokerFriendColors.dark3,
          title: Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter value',
              hintStyle: TextStyle(color: PokerFriendColors.dark9),
              filled: true,
              fillColor: PokerFriendColors.dark1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: PokerFriendColors.dark9),
              ),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null && value > 0) {
                  onConfirm(value);
                  Navigator.pop(context);
                }
              },
              child: Text(
                'OK',
                style: TextStyle(color: PokerFriendColors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startSession() {
    final sessionName = _sessionNameController.text;
    final buyIn = double.parse(_buyInController.text);
    final startingStack = double.parse(_startingStackController.text);

    if (widget.loggingMode == LoggingMode.full) {
      // For Full mode, go directly to Seat Setup screen
      // Create session manager
      final sessionManager = PokerSessionManager(
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        playerCount: 6,
        gameType: gameType,
        sessionName: sessionName,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeatSetupScreen(
            playerCount: 6,
            buttonPosition: 1,
            sessionManager: sessionManager,
            isInitialSetup: true,
            isCashGame: gameType == GameType.cash,
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
    } else {
      // For Individual mode, go to Individual Session Tracking
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