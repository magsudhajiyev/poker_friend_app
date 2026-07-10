import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../widgets/modern_setting_row.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart' show formatBlindValue;
import 'poker_hand_screen.dart';
import '../widgets/loading_screen.dart';
import 'logging_mode_selection_screen.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';

class IntroductionScreen extends StatefulWidget {
  const IntroductionScreen({super.key});

  @override
  State<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends State<IntroductionScreen> {
  double smallBlind = 1.0;
  double bigBlind = 2.0;
  int numberOfPlayers = 6;
  GameType gameType = GameType.cash;
  bool bbAnteEnabled = false;
  bool isStartingGame = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Show loading screen when starting game
    if (isStartingGame) {
      return LoadingScreen(message: l10n.introStartingSession);
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant1,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: 375),
            margin: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section - matching home screen style
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 32, 0, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.introGameSetup,
                            style: TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            l10n.introConfigureSession,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant2,
                          borderRadius: BorderRadius.circular(AppDecorations.radius14),
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
                
                // Settings Cards in Grid Layout
                GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: [
                    _buildSettingCard(
                      title: l10n.introSmallBlind,
                      value: gameType == GameType.cash ? CurrencyService.formatCash(smallBlind) : formatBlindValue(smallBlind),
                      iconPath: 'icons/small_blind.png',
                      onDecrement: () {
                        if (smallBlind > 1) {
                          setState(() => smallBlind--);
                        }
                      },
                      onIncrement: () {
                        setState(() => smallBlind++);
                      },
                      onValueTap: () => _showBlindInputDialog(l10n.introSmallBlind, smallBlind, (value) {
                        setState(() {
                          smallBlind = value;
                        });
                      }),
                    ),
                    _buildSettingCard(
                      title: l10n.introBigBlind,
                      value: gameType == GameType.cash ? CurrencyService.formatCash(bigBlind) : formatBlindValue(bigBlind),
                      iconPath: 'icons/big_blind.png',
                      onDecrement: () {
                        if (bigBlind > 1) {
                          setState(() => bigBlind--);
                        }
                      },
                      onIncrement: () => setState(() => bigBlind++),
                      onValueTap: () => _showBlindInputDialog(l10n.introBigBlind, bigBlind, (value) {
                        setState(() {
                          bigBlind = value;
                        });
                      }),
                    ),
                    _buildSettingCard(
                      title: l10n.introPlayers,
                      value: '$numberOfPlayers',
                      iconPath: 'icons/players.png',
                      onDecrement: () {
                        if (numberOfPlayers > 2) setState(() => numberOfPlayers--);
                      },
                      onIncrement: () {
                        if (numberOfPlayers < 10) setState(() => numberOfPlayers++);
                      },
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                // Game Type Card
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant2,
                    borderRadius: BorderRadius.circular(AppDecorations.radius20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'icons/game_type.png',
                            width: 32,
                            height: 32,
                          ),
                          SizedBox(width: 16),
                          Text(
                            l10n.introGameType,
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
                
                // BB Ante Switch (Tournament only)
                if (gameType == GameType.tournament) ...[
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant2,
                      borderRadius: BorderRadius.circular(AppDecorations.radius20),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'icons/ante.png',
                          width: 32,
                          height: 32,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.introBbAnte,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                l10n.introBbAnteDescription,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: bbAnteEnabled,
                          onChanged: (value) {
                            setState(() {
                              bbAnteEnabled = value;
                            });
                          },
                          activeColor: AppColors.errorRedVariant,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AppColors.surfaceVariant3,
                        ),
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
                    gradient: LinearGradient(
                      colors: [AppColors.errorRedVariant, Color(0xFFb8442f)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppDecorations.radius20),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        isStartingGame = true;
                      });
                      
                      // Small delay to show loading screen
                      await Future.delayed(Duration(milliseconds: 800));
                      
                      if (mounted) {
                        setState(() {
                          isStartingGame = false;
                        });
                        
                        // Navigate based on logging mode
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PokerHandScreen(
                              smallBlind: smallBlind,
                              bigBlind: bigBlind,
                              numberOfPlayers: numberOfPlayers,
                              gameType: gameType,
                              hasBBante: bbAnteEnabled,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDecorations.radius20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          l10n.introStartGame,
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
                
                SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBlindInputDialog(String title, double currentValue, Function(double) onChanged) async {
    final l10n = AppLocalizations.of(context);
    final TextEditingController controller = TextEditingController(text: formatBlindValue(currentValue));

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceVariant2,
          title: Text(
            l10n.introEnterField(title),
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: l10n.introEnterAmount,
              hintStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.errorRedVariant),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.errorRedVariant, width: 2),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel, style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                if (value != null && value > 0) {
                  onChanged(value);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.introPleaseEnterValidNumber),
                      backgroundColor: AppColors.errorRedVariant,
                    ),
                  );
                }
              },
              child: Text(l10n.commonOk, style: TextStyle(color: AppColors.errorRedVariant)),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildSettingCard({
    required String title,
    required String value,
    IconData? icon,
    String? iconPath,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    VoidCallback? onValueTap,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant2,
        borderRadius: BorderRadius.circular(AppDecorations.radius20),
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
              iconPath != null
                  ? Image.asset(
                      iconPath,
                      width: 32,
                      height: 32,
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.profitGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDecorations.radius10),
                      ),
                      child: Icon(
                        icon ?? Icons.help_outline,
                        color: AppColors.profitGreen,
                        size: 20,
                      ),
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
                border: Border.all(color: AppColors.errorRedVariant.withOpacity(0.3)),
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
                      color: AppColors.surfaceVariant1,
                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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
                      color: AppColors.errorRedVariant,
                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
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
    final l10n = AppLocalizations.of(context);
    final isSelected = gameType == selectedGameType;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.errorRedVariant : AppColors.surfaceVariant1,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.errorRedVariant : AppColors.surfaceVariant3,
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
              gameType == GameType.cash ? l10n.introRingGame : l10n.introMultiTable,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white.withOpacity(0.8) : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}