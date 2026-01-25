import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/game_types.dart';
import 'individual_session_tracking_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'seat_setup_screen.dart';
import '../models/hand_state_machine.dart';
import '../design_system/design_system.dart';

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
    bool basicValid = _sessionNameController.text.isNotEmpty &&
                     _buyInController.text.isNotEmpty &&
                     double.tryParse(_buyInController.text) != null;

    if (gameType == GameType.tournament) {
      return basicValid &&
             _startingStackController.text.isNotEmpty &&
             double.tryParse(_startingStackController.text) != null;
    }

    return basicValid;
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                MainScreenHeader(
                  title: 'Session Setup',
                  subtitle: widget.loggingMode == LoggingMode.full
                      ? 'Full session tracking'
                      : 'Individual session tracking',
                  rightIcon: Icons.close_rounded,
                  onRightPressed: () => Navigator.pop(context),
                  showLeftIcon: false,
                  padding: const EdgeInsets.all(16),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Session Name Input
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Name',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    color: Color(0xFFF7FFF7),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextField(
                                  controller: _sessionNameController,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                    height: 1.2,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., "Friday Night Poker"',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0x99EBFFEF), // #ebffef99
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      height: 1.2,
                                    ),
                                    filled: true,
                                    fillColor: Color(0x0AFFFFFF), // #ffffff0a
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(58),
                                      borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(58),
                                      borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(58),
                                      borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                    ),
                                    contentPadding: EdgeInsets.fromLTRB(20, 14, 14, 14),
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ],
                            ),
                          ),

                          // Section Divider
                          Container(
                            height: 1,
                            color: Color(0xFF214027), // #214027
                          ),

                          SizedBox(height: 32),

                          // Game Type Selection
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose Game Type',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  color: Color(0xFFF7FFF7),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _GameTypeButton(
                                      gameType: GameType.cash,
                                      selectedGameType: gameType,
                                      onTap: () => setState(() {
                                        gameType = GameType.cash;
                                        _updateStackForGameType();
                                      }),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _GameTypeButton(
                                      gameType: GameType.tournament,
                                      selectedGameType: gameType,
                                      onTap: () => setState(() {
                                        gameType = GameType.tournament;
                                        _updateStackForGameType();
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: 32),

                          // Section Divider
                          Container(
                            height: 1,
                            color: Color(0xFF214028), // #214028
                          ),

                          // Buy-in Amount Section with padding
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Buy-in Amount',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    color: Color(0xFFF7FFF7),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                    height: 1.0,
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextField(
                                  controller: _buyInController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                    height: 1.2,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter buy-in amount',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0x99EBFFF0), // #ebfff099
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      height: 1.2,
                                    ),
                                    prefixText: '\$ ',
                                    prefixStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      height: 1.2,
                                    ),
                                    filled: true,
                                    fillColor: Color(0x0AFFFFFF), // #ffffff0a
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(58),
                                      borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(58),
                                      borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(58),
                                      borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                    ),
                                    contentPadding: EdgeInsets.fromLTRB(20, 14, 14, 14),
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                    _updateStackForGameType();
                                  },
                                ),
                                // Cash game explanation - 24px gap after input
                                if (gameType == GameType.cash) ...[
                                  SizedBox(height: 24),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: Color(0xFFB9FF99), size: 24),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'In cash games your starting stack equals your buy-in amount.',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFFC2C8C2), // #c2c8c2
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 0,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Starting Stack Input - only show for MTT
                          if (gameType == GameType.tournament) ...[
                            // Section Divider
                            Container(
                              height: 1,
                              color: Color(0xFF214028), // #214028
                            ),

                            // Starting Stack with padding
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Starting Stack',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      color: Color(0xFFF7FFF7),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      height: 1.0,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller: _startingStackController,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      height: 1.2,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter chip stack',
                                      hintStyle: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Color(0x99EBFFF0), // #ebfff099
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0,
                                        height: 1.2,
                                      ),
                                      filled: true,
                                      fillColor: Color(0x0AFFFFFF), // #ffffff0a
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(58),
                                        borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(58),
                                        borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(58),
                                        borderSide: BorderSide(color: Color(0xFF13321B), width: 1),
                                      ),
                                      contentPadding: EdgeInsets.fromLTRB(20, 14, 14, 14),
                                    ),
                                    onChanged: (value) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Section Divider
                          Container(
                            height: 1,
                            color: Color(0xFF214028), // #214028
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

                          // BB Ante Section (only for tournaments)
                          if (gameType == GameType.tournament) ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFF214028), width: 1),
                                  bottom: BorderSide(color: Color(0xFF214028), width: 1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'BB Ante',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      color: Color(0xFFF7FFF7), // #f7fff7
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      height: 1.0,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => hasBBante = !hasBBante),
                                    child: Container(
                                      width: 48,
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Color(0x0AFFFFFF), // #ffffff0a
                                        border: Border.all(color: Color(0xFF13321B), width: 1),
                                        borderRadius: BorderRadius.circular(58),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.4),
                                            offset: Offset(0, 1),
                                            blurRadius: 0,
                                            spreadRadius: 0,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.32),
                                            offset: Offset(1, 0),
                                            blurRadius: 0,
                                            spreadRadius: 0,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.13),
                                            offset: Offset(0, -1),
                                            blurRadius: 1,
                                            spreadRadius: 0,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.11),
                                            offset: Offset(-1, 0),
                                            blurRadius: 1,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: AnimatedAlign(
                                        duration: Duration(milliseconds: 200),
                                        alignment: hasBBante ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: Color(0xFFBAFF9A), // #baff9a
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 32),

                          // Start Button
                          GestureDetector(
                            onTap: isFormValid ? _startSession : null,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isFormValid ? Color(0xFFB9FF99) : Color(0x1AFFFFFF),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Start Session',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      color: isFormValid ? Colors.black : Color(0xFF9A9A9A),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                      height: 27 / 18, // line-height: 27px
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: isFormValid ? Colors.black : Color(0xFF9A9A9A),
                                    size: 24,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlindCard({
    required String title,
    required String value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    VoidCallback? onValueTap,
  }) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(0x4C2B3E2E), // #2b3e2e4c
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          GestureDetector(
            onTap: onValueTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0x1AFFFFFF), width: 1), // #ffffff1a
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0x1400FF66), // #00ff6614
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        offset: Offset(0, 1),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.32),
                        offset: Offset(1, 0),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        offset: Offset(0, -1),
                        blurRadius: 1,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.11),
                        offset: Offset(-1, 0),
                        blurRadius: 1,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0x1400FF66), // #00ff6614
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        offset: Offset(0, 1),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.32),
                        offset: Offset(1, 0),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        offset: Offset(0, -1),
                        blurRadius: 1,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.11),
                        offset: Offset(-1, 0),
                        blurRadius: 1,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
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
          backgroundColor: Color(0xFF1F1F23),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter value',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF9A9A9A),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Color(0x0AFFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF13321B)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF13321B)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFFB9FF99)),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w500,
                ),
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFB9FF99),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateStackForGameType() {
    if (gameType == GameType.cash) {
      // For cash games, starting stack equals buy-in amount
      final buyInText = _buyInController.text;
      if (buyInText.isNotEmpty && double.tryParse(buyInText) != null) {
        _startingStackController.text = buyInText;
      }
    }
    // For MTT, user enters starting stack manually
  }

  void _startSession() {
    final sessionName = _sessionNameController.text;
    final buyIn = double.parse(_buyInController.text);
    final startingStack = gameType == GameType.cash
        ? buyIn  // For cash games, starting stack = buy-in
        : double.parse(_startingStackController.text);  // For MTT, use entered value


    if (widget.loggingMode == LoggingMode.full) {
      // For Full mode, go directly to Seat Setup screen
      // Create session manager
      final sessionManager = PokerSessionManager(
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        playerCount: 9, // Support all 9 seats
        gameType: gameType,
        sessionName: sessionName,
        initialBuyIn: buyIn,
        startingStack: startingStack, // Pass starting stack for P/L calculations
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeatSetupScreen(
            playerCount: 9, // Support all 9 seats
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
    final isCash = gameType == GameType.cash;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? Color(0x4C6DE17F) : Color(0x4C2B3E2E), // #6de17f4c selected, #2b3e2e4c unselected
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isCash ? 'Cash Game\n ' : 'MTT\n(Tournament)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: isCash ? Color(0xFFCDE63B) : Color(0xFF76C527), // #cde63b for cash, #76c527 for MTT
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isCash ? 'Ring Game' : 'Multi-table',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: Color(0xFFE4FFE3), // #e4ffe3
                fontWeight: FontWeight.w400,
                letterSpacing: -1.0,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}