import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../services/currency_service.dart';
import 'individual_session_tracking_screen.dart';

class IndividualHandSetupScreen extends StatefulWidget {
  const IndividualHandSetupScreen({super.key});

  @override
  State<IndividualHandSetupScreen> createState() => _IndividualHandSetupScreenState();
}

class _IndividualHandSetupScreenState extends State<IndividualHandSetupScreen> {
  int smallBlind = 1;
  int bigBlind = 2;
  int numberOfPlayers = 6;
  GameType gameType = GameType.cash;
  String handName = '';

  final TextEditingController _handNameController = TextEditingController();

  @override
  void dispose() {
    _handNameController.dispose();
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
                            AppLocalizations.of(context).individualHandSetupTitle,
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).individualHandSetupSubtitle,
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

                // Hand Name Input
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
                              Icons.edit,
                              color: PokerFriendColors.red,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            AppLocalizations.of(context).individualHandSetupHandNameLabel,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _handNameController,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).individualHandSetupNameHint,
                          hintStyle: TextStyle(color: PokerFriendColors.dark9),
                          filled: true,
                          fillColor: PokerFriendColors.dark1,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {
                            handName = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Game Settings in Grid Layout
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                    _buildSettingCard(
                      title: AppLocalizations.of(context).individualHandSetupSmallBlind,
                      value: gameType == GameType.cash ? CurrencyService.formatCash(smallBlind.toDouble()) : '$smallBlind',
                      icon: Icons.monetization_on,
                      onDecrement: () {
                        if (smallBlind > 1) {
                          setState(() => smallBlind--);
                          if (bigBlind < smallBlind) {
                            setState(() => bigBlind = smallBlind);
                          }
                        }
                      },
                      onIncrement: () {
                        setState(() => smallBlind++);
                        if (bigBlind < smallBlind) {
                          setState(() => bigBlind = smallBlind);
                        }
                      },
                    ),
                    _buildSettingCard(
                      title: AppLocalizations.of(context).individualHandSetupBigBlind,
                      value: gameType == GameType.cash ? CurrencyService.formatCash(bigBlind.toDouble()) : '$bigBlind',
                      icon: Icons.monetization_on_outlined,
                      onDecrement: () {
                        if (bigBlind > smallBlind) {
                          setState(() => bigBlind--);
                        }
                      },
                      onIncrement: () => setState(() => bigBlind++),
                    ),
                    _buildSettingCard(
                      title: AppLocalizations.of(context).individualHandSetupPlayers,
                      value: '$numberOfPlayers',
                      icon: Icons.people,
                      onDecrement: () {
                        if (numberOfPlayers > 2) setState(() => numberOfPlayers--);
                      },
                      onIncrement: () {
                        if (numberOfPlayers < 10) setState(() => numberOfPlayers++);
                      },
                    ),
                    _buildSettingCard(
                      title: AppLocalizations.of(context).individualHandSetupGameType,
                      value: gameType.displayName,
                      icon: gameType == GameType.cash ? Icons.attach_money : Icons.emoji_events,
                      onDecrement: () {
                        setState(() {
                          gameType = gameType == GameType.cash ? GameType.tournament : GameType.cash;
                        });
                      },
                      onIncrement: () {
                        setState(() {
                          gameType = gameType == GameType.cash ? GameType.tournament : GameType.cash;
                        });
                      },
                    ),
                  ],
                ),

                SizedBox(height: 32),

                // Start Button
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [PokerFriendColors.red, Color(0xFFb8442f)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IndividualSessionTrackingScreen(
                            sessionName: handName.isEmpty ? 'Individual Hand' : handName,
                            buyInAmount: 0.0, // Default for individual hand
                            startingStack: gameType == GameType.cash ? 100.0 : 1500.0, // Default starting stack
                            gameType: gameType,
                            smallBlind: smallBlind,
                            bigBlind: bigBlind,
                            hasBBante: false,
                          ),
                        ),
                      );
                    },
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
                          Icons.casino,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'LOG HAND',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildSettingCard({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PokerFriendColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: PokerFriendColors.red,
                  size: 20,
                ),
              ),
            ],
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
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
}