import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_types.dart';
import 'individual_session_tracking_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'seat_setup_screen.dart';
import '../models/hand_state_machine.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart';
import '../onboarding/onboarding_progress_bar.dart';

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
    _scheduleOnboardingTour();
  }

  void _scheduleOnboardingTour() {
    if (!OnboardingState.isOnboardingActive ||
        OnboardingState.currentPhase != 2) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SessionSetupTour().show(context);
    });
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
      body: Stack(
        children: [
          // Teal gradient background (consistent with other screens)
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
              children: [
                const OnboardingProgressBar(),
                // Header with X, title, and checkmark
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // X button (close)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/close.svg',
                              16,
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'Session Setup',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.43,
                          height: 1.3,
                        ),
                      ),
                      // Checkmark button (confirm/start)
                      GestureDetector(
                        onTap: isFormValid ? _startSession : null,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isFormValid
                              ? Color(0xFF62E3BC)
                              : Color(0xFF3C3C43).withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _buildIcon(
                              'icons/figma_icons/check.svg',
                              16,
                              isFormValid ? Colors.black : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Session Name Card
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Color(0xFF131616),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session Name',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: Color(0xFF62E3BC),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.43,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 12),
                                TextField(
                                  controller: _sessionNameController,
                                  style: GoogleFonts.ibmPlexSans(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                    height: 1.44,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., "Friday Night Poker"',
                                    hintStyle: GoogleFonts.ibmPlexSans(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      height: 1.44,
                                    ),
                                    filled: true,
                                    fillColor: Color(0xFF1C1C1E),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF1B262D).withOpacity(0.6),
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF1B262D).withOpacity(0.6),
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF89F1EC),
                                        width: 1,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // Game Type Card
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Color(0xFF131616),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game Type',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: Color(0xFF62E3BC),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.43,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildGameTypeToggle(
                                        title: 'Cash Game',
                                        isSelected: gameType == GameType.cash,
                                        onTap: () => setState(() {
                                          gameType = GameType.cash;
                                          _updateStackForGameType();
                                        }),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildGameTypeToggle(
                                        title: 'Tournament',
                                        isSelected: gameType == GameType.tournament,
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
                          ),

                          SizedBox(height: 16),

                          // Buy-in Amount Card
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Color(0xFF131616),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Buy-in Amount',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: Color(0xFF62E3BC),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.43,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 12),
                                TextField(
                                  controller: _buyInController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.ibmPlexSans(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w400,
                                    height: 1.44,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter amount',
                                    hintStyle: GoogleFonts.ibmPlexSans(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      height: 1.44,
                                    ),
                                    prefixText: '\$ ',
                                    prefixStyle: GoogleFonts.ibmPlexSans(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      height: 1.44,
                                    ),
                                    filled: true,
                                    fillColor: Color(0xFF1C1C1E),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF1B262D).withOpacity(0.6),
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF1B262D).withOpacity(0.6),
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF89F1EC),
                                        width: 1,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                    _updateStackForGameType();
                                  },
                                ),
                                // Cash game explanation
                                if (gameType == GameType.cash) ...[
                                  SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildIcon(
                                        'icons/figma_icons/info.svg',
                                        18,
                                        Color(0xFF89F1EC),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'In cash games your starting stack equals your buy-in amount.',
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            height: 1.44,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Starting Stack Card - only show for MTT
                          if (gameType == GameType.tournament) ...[
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Color(0xFF131616),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Starting Stack',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 17,
                                      color: Color(0xFF62E3BC),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.43,
                                      height: 1.3,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  TextField(
                                    controller: _startingStackController,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    style: GoogleFonts.ibmPlexSans(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      height: 1.44,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter chip stack',
                                      hintStyle: GoogleFonts.ibmPlexSans(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        height: 1.44,
                                      ),
                                      filled: true,
                                      fillColor: Color(0xFF1C1C1E),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Color(0xFF1B262D).withOpacity(0.6),
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Color(0xFF1B262D).withOpacity(0.6),
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Color(0xFF89F1EC),
                                          width: 1,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    onChanged: (value) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 16),

                          // Blinds Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildBlindCard(
                                  title: 'Small Blind',
                                  value: gameType == GameType.cash ? '\$$smallBlind' : '$smallBlind',
                                  onTap: () => _showBlindInputDialog('Small Blind', smallBlind, (value) {
                                    setState(() {
                                      smallBlind = value;
                                      _smallBlindController.text = smallBlind.toString();
                                    });
                                  }),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildBlindCard(
                                  title: 'Big Blind',
                                  value: gameType == GameType.cash ? '\$$bigBlind' : '$bigBlind',
                                  onTap: () => _showBlindInputDialog('Big Blind', bigBlind, (value) {
                                    setState(() {
                                      bigBlind = value;
                                      _bigBlindController.text = bigBlind.toString();
                                    });
                                  }),
                                ),
                              ),
                            ],
                          ),

                          // BB Ante Section (only for tournaments)
                          if (gameType == GameType.tournament) ...[
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Color(0xFF131616),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'BB Ante',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 17,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      height: 1.44,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => hasBBante = !hasBBante),
                                    child: Container(
                                      width: 51,
                                      height: 31,
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: hasBBante ? Color(0xFF62E3BC) : Color(0xFF1C1C1E),
                                        borderRadius: BorderRadius.circular(16),
                                        border: hasBBante ? null : Border.all(
                                          color: Color(0xFF1B262D).withOpacity(0.6),
                                          width: 1,
                                        ),
                                      ),
                                      child: AnimatedAlign(
                                        duration: Duration(milliseconds: 200),
                                        alignment: hasBBante ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          width: 27,
                                          height: 27,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.15),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
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
                                color: isFormValid ? Color(0xFF62E3BC) : Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(110),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Start Session',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 17,
                                    color: isFormValid ? Colors.black : Colors.white.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.43,
                                    height: 1.3,
                                  ),
                                ),
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

  Widget _buildGameTypeToggle({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF89F1EC) : Color(0xFF1B262D).withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: isSelected ? Color(0xFF89F1EC) : Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlindCard({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color(0xFF131616),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.44,
            ),
          ),
          SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(80),
                border: Border.all(
                  color: Color(0xFF1B262D).withOpacity(0.6),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  value,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
              ),
            ),
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
          backgroundColor: Color(0xFF131616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              color: Color(0xFF62E3BC),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: 'Enter value',
              hintStyle: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.4),
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF1B262D).withOpacity(0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF1B262D).withOpacity(0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF89F1EC)),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white.withOpacity(0.6),
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
                style: GoogleFonts.ibmPlexSans(
                  color: Color(0xFF62E3BC),
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
      // Set default cash game blinds
      smallBlind = 1;
      bigBlind = 2;
      _smallBlindController.text = smallBlind.toString();
      _bigBlindController.text = bigBlind.toString();
    } else {
      // For MTT, set default tournament blinds
      smallBlind = 100;
      bigBlind = 200;
      _smallBlindController.text = smallBlind.toString();
      _bigBlindController.text = bigBlind.toString();
    }
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
