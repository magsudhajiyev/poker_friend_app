import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool useButtonMode = false;
  bool autoAdvanceStreets = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useButtonMode = prefs.getBool('use_button_mode') ?? false;
      autoAdvanceStreets = prefs.getBool('auto_advance_streets') ?? false;
    });
  }

  Future<void> _saveButtonMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_button_mode', value);
    setState(() {
      useButtonMode = value;
    });
  }

  Future<void> _saveAutoAdvanceStreets(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_advance_streets', value);
    setState(() {
      autoAdvanceStreets = value;
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Input Method',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Choose how you want to input poker actions during gameplay',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Use Action Buttons'),
                    subtitle: Text(
                      useButtonMode 
                        ? 'Use buttons for Fold, Call, Bet, Raise actions'
                        : 'Use drawing gestures on touchpad',
                    ),
                    value: useButtonMode,
                    onChanged: _saveButtonMode,
                    secondary: Icon(
                      useButtonMode ? Icons.smart_button : Icons.touch_app,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              useButtonMode ? 'Button Mode' : 'Gesture Mode',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (useButtonMode) ...[
                          Text('• Tap action buttons to play hands', style: theme.textTheme.bodySmall),
                          Text('• Clear visual feedback for each action', style: theme.textTheme.bodySmall),
                          Text('• Perfect for new users', style: theme.textTheme.bodySmall),
                        ] else ...[
                          Text('• Draw gestures on the screen', style: theme.textTheme.bodySmall),
                          Text('• Tap = Bet/Raise, Circle = Call, X = Fold', style: theme.textTheme.bodySmall),
                          Text('• Faster input for experienced users', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Game Flow',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Configure how the game advances through betting rounds',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Auto-Advance Streets'),
                    subtitle: Text(
                      autoAdvanceStreets
                        ? 'Automatically move to next street when betting round completes'
                        : 'Manually press "Next Street" button to continue',
                    ),
                    value: autoAdvanceStreets,
                    onChanged: _saveAutoAdvanceStreets,
                    secondary: Icon(
                      autoAdvanceStreets ? Icons.fast_forward : Icons.pause,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              autoAdvanceStreets ? 'Auto-Advance Mode' : 'Manual Mode',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (autoAdvanceStreets) ...[
                          Text('• Game automatically moves from Preflop → Flop → Turn → River', style: theme.textTheme.bodySmall),
                          Text('• Saves time during rapid gameplay', style: theme.textTheme.bodySmall),
                          Text('• Perfect for experienced players', style: theme.textTheme.bodySmall),
                        ] else ...[
                          Text('• Full control over game progression', style: theme.textTheme.bodySmall),
                          Text('• Take time to analyze each street', style: theme.textTheme.bodySmall),
                          Text('• Ideal for learning and review', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Settings',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You can change these settings at any time. Your preferences will be saved and applied to future poker sessions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}