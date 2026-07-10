import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart' show formatBlindValue;
import '../services/firebase_service.dart';
import '../design_system/components/form_drawer.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart' show buildTooltip;
import '../onboarding/onboarding_prefs.dart';
import '../onboarding/onboarding_progress_bar.dart';
import '../design_system/components/app_toggle.dart';
import '../models/hand_state_machine.dart';
import '../widgets/stack_growth_chart.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionName;
  final double buyInAmount;
  final double startingStack;
  final GameType gameType;
  final double smallBlind;
  final double bigBlind;
  final bool hasBBante;

  // Parameters from active session
  final double? currentStack;
  final String? sessionId;

  // Stack chart data (passed from active session)
  final List<Map<String, dynamic>>? liveStackHistory;
  final List<HandRecord>? completedHands;

  const SessionDetailsScreen({
    super.key,
    required this.sessionName,
    required this.buyInAmount,
    required this.startingStack,
    required this.gameType,
    required this.smallBlind,
    required this.bigBlind,
    required this.hasBBante,
    this.currentStack,
    this.sessionId,
    this.liveStackHistory,
    this.completedHands,
  });

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  // Stack management
  late double _currentStack;
  late double _initialStack;

  // Timer management
  Timer? _timer;
  Duration _sessionDuration = Duration.zero;
  DateTime? _sessionStartTime;

  // Stats
  int _handsLogged = 0;
  double _biggestPot = 0.0;

  // Rebuy tracking
  List<Map<String, dynamic>> _rebuys = [];
  double _totalBuyIn = 0.0;
  List<Map<String, dynamic>> _stackHistory = [];

  // Average growth tracking (for tournaments)
  double _averageGrowth = 0.0;

  // Current blinds (can be updated during session)
  double _currentSmallBlind = 0.0;
  double _currentBigBlind = 0.0;
  bool _currentHasBBante = false;

  // Track if blinds were explicitly changed by user
  bool _blindsWereChanged = false;

  // Display mode (persisted via SharedPreferences)
  bool _showBBMode = false;
  static const _bbModeKey = 'session_bb_mode';

  // Completed hands (for chart tooltips with hole cards, position)
  List<HandRecord> _completedHands = [];

  // Chart state
  bool _statsExpanded = false;
  int? _selectedHandIndex;

  // Menu key
  final GlobalKey _dotsKey = GlobalKey();

  // Onboarding GlobalKeys
  final GlobalKey _currentStackCardKey = GlobalKey(debugLabel: 'currentStackCard');
  final GlobalKey _updateStackBtnKey = GlobalKey(debugLabel: 'updateStackBtn');
  final GlobalKey _logHandBtnKey = GlobalKey(debugLabel: 'logHandBtn');
  final GlobalKey _stackChartKey = GlobalKey(debugLabel: 'stackChart');

  @override
  void initState() {
    super.initState();
    _currentStack = widget.currentStack ?? widget.startingStack;
    _initialStack = widget.startingStack;
    _totalBuyIn = widget.buyInAmount;

    // Use live stack history from active session
    if (widget.liveStackHistory != null && widget.liveStackHistory!.isNotEmpty) {
      _stackHistory = List<Map<String, dynamic>>.from(widget.liveStackHistory!);
    } else {
      _stackHistory.add({
        'timestamp': DateTime.now().toIso8601String(),
        'stackSize': _currentStack,
        'changeType': 'initial',
        'changeAmount': widget.buyInAmount,
      });
    }

    _currentSmallBlind = widget.smallBlind;
    _currentBigBlind = widget.bigBlind;
    _currentHasBBante = widget.hasBBante;

    // Initialize completed hands from passed-in data (active session)
    if (widget.completedHands != null && widget.completedHands!.isNotEmpty) {
      _completedHands = List<HandRecord>.from(widget.completedHands!);
    }

    _resumeSession();
    _loadBBMode();
    _startTimer();
    _scheduleSessionDetailsTour();
  }

  Future<void> _loadBBMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _showBBMode = prefs.getBool(_bbModeKey) ?? false);
    }
  }

  Future<void> _saveBBMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bbModeKey, value);
  }

  void _scheduleSessionDetailsTour() {
    if (!OnboardingState.isOnboardingActive ||
        !OnboardingState.sessionDetailsTourPending) return;
    OnboardingState.sessionDetailsTourPending = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _showSessionDetailsTour();
    });
  }

  void _showSessionDetailsTour() {
    final l10n = AppLocalizations.of(context);

    final targets = <TargetFocus>[];

    if (_currentStackCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'current_stack_card',
          keyTarget: _currentStackCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: l10n.guidedCurrentStackTitle,
                  body: l10n.guidedCurrentStackBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }
    targets.add(
      TargetFocus(
        identify: 'update_stack_button',
        keyTarget: _updateStackBtnKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return buildTooltip(
                title: l10n.guidedUpdateStackTitle,
                body: l10n.guidedUpdateStackBody,
                onNext: () => controller.next(),
                context: context,
              );
            },
          ),
        ],
      ),
    );
    if (_stackChartKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'stack_chart',
          keyTarget: _stackChartKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.custom,
              customPosition: CustomTargetContentPosition(
                top: MediaQueryData.fromView(
                  WidgetsBinding.instance.platformDispatcher.views.first,
                ).size.height *
                    0.12,
              ),
              builder: (context, controller) {
                return buildTooltip(
                  title: l10n.guidedStackChartTitle,
                  body: l10n.guidedStackChartBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }
    targets.add(
      TargetFocus(
        identify: 'go_back_to_hand',
        keyTarget: _logHandBtnKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return buildTooltip(
                title: l10n.guidedDetailsBackTitle,
                body: l10n.guidedDetailsBackBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    );

    final coach = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 12,
      hideSkip: false,
      alignSkip: Alignment.topLeft,
      skipWidget: Padding(
        padding: EdgeInsets.only(
            left: 16, top: MediaQuery.of(context).padding.top + 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            l10n.onboardingSkipTour,
            style: AppTypography.ibm(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ),
      ),
      onFinish: () {
        // Tour overlay dismissed
      },
      onSkip: () {
        final wasReplay = OnboardingState.isReplay;
        OnboardingState.cancel();
        OnboardingPrefs.markOnboardingSeen();
        if (!wasReplay) {
          OnboardingPrefs.setPostTourPaywallPending();
        }
        return true;
      },
    );
    coach.show(context: context);
  }

  Future<void> _resumeSession() async {
    if (widget.sessionId != null) {
      try {
        Map<String, dynamic>? sessionData;
        try {
          sessionData = await FirebaseService.getSession(widget.sessionId!);
        } catch (e) {
          // Fallback handled elsewhere
        }

        if (sessionData != null) {
          setState(() {
            _totalBuyIn = sessionData!['totalBuyIn']?.toDouble() ?? _totalBuyIn;
            _handsLogged = sessionData['handsLogged'] ?? 0;
            _biggestPot = sessionData['biggestPot']?.toDouble() ?? 0.0;

            if (widget.gameType == GameType.tournament) {
              _averageGrowth = sessionData['averageGrowth']?.toDouble() ?? 0.0;
            }

            if (sessionData['rebuys'] != null) {
              _rebuys = List<Map<String, dynamic>>.from(sessionData['rebuys']);
            }

            if (sessionData['startTime'] != null) {
              try {
                if (sessionData['startTime'] is DateTime) {
                  _sessionStartTime = sessionData['startTime'] as DateTime;
                } else if (sessionData['startTime'] is String) {
                  _sessionStartTime = DateTime.parse(sessionData['startTime']);
                }
              } catch (e) {
                debugPrint('Error parsing session start time: $e');
              }
            }
          });
        }
      } catch (e) {}
    }

    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_sessionStartTime != null) {
          _sessionDuration = DateTime.now().difference(_sessionStartTime!);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get stackGrowthPercentage {
    if (_initialStack == 0) return 0;
    return ((_currentStack - _initialStack) / _initialStack) * 100;
  }

  Color get stackColor {
    if (_currentStack == _initialStack) {
      return Colors.white;
    } else if (_currentStack > _initialStack) {
      return AppColors.accentPrimary;
    } else {
      return Colors.red;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _formatStackValue(double value) {
    if (_showBBMode && _currentBigBlind > 0) {
      final bbValue = value / _currentBigBlind;
      return '${bbValue.toStringAsFixed(1)} BB';
    } else {
      return widget.gameType == GameType.cash
          ? CurrencyService.formatCash(value)
          : value.toStringAsFixed(0);
    }
  }

  // ─── Dialogs ───

  Future<void> _showUpdateStackDialog() async {
    final l10n = AppLocalizations.of(context);
    final newStackController = TextEditingController(text: _currentStack.toString());
    final noteController = TextEditingController();
    Map<String, dynamic>? result;

    await FormDrawer.show(
      context: context,
      title: l10n.individualUpdateCurrentStack,
      heightFraction: 0.62,
      onSave: () {
        final value = double.tryParse(newStackController.text);
        if (value != null) {
          result = {
            'stack': value,
            'note': noteController.text.trim(),
          };
          Navigator.pop(context);
        }
      },
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.infoCardBg,
            borderRadius: BorderRadius.circular(AppDecorations.radius18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              // Current Stack display
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.individualCurrentStack,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                        height: 1.44,
                      ),
                    ),
                    Text(
                      widget.gameType == GameType.cash
                          ? CurrencyService.formatCash(_currentStack)
                          : _currentStack.toStringAsFixed(0),
                      style: AppTypography.ibm(
                        color: AppColors.accentPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Separator
              Container(
                height: 21,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Container(height: 1, color: AppColors.bgOverlay),
              ),
              // New Total field
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                child: TextField(
                  controller: newStackController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.ibm(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.individualEnterNewTotalStack,
                    hintStyle: AppTypography.ibm(
                      fontSize: 17,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                      height: 1.44,
                    ),
                    prefixText: widget.gameType == GameType.cash ? CurrencyService.prefixText : '',
                    suffixText: widget.gameType == GameType.cash ? CurrencyService.suffixText : null,
                    prefixStyle: AppTypography.ibm(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              // Separator
              Container(
                height: 21,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Container(height: 1, color: AppColors.bgOverlay),
              ),
              // Note field
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: noteController,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.individualNoteHint,
                    hintStyle: AppTypography.ibm(
                      fontSize: 17,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                      height: 1.44,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 100,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      final newStack = result!['stack'] as double;
      final note = result!['note'] as String;
      if (newStack >= 0) {
        final previousStack = _currentStack;
        final stackChange = newStack - previousStack;

        setState(() {
          _currentStack = newStack;
          final entry = <String, dynamic>{
            'timestamp': DateTime.now().toIso8601String(),
            'stackSize': newStack,
            'changeType': stackChange >= 0 ? 'manual_increase' : 'manual_decrease',
            'changeAmount': stackChange.abs(),
          };
          if (note.isNotEmpty) {
            entry['note'] = note;
          }
          _stackHistory.add(entry);
        });

        if (widget.sessionId != null) {
          FirebaseService.updateIndividualSession(
            sessionId: widget.sessionId!,
            currentStack: _currentStack,
            stackHistory: _stackHistory,
          ).catchError((e) {});
        }
      }
    }
  }

  void _showOptionsMenu() {
    final l10n = AppLocalizations.of(context);
    final RenderBox renderBox = _dotsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            right: 16,
            top: offset.dy + size.height + 4,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 184,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppDecorations.radius18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 34,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rebuy row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showRebuyDialog();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, color: AppColors.accentPrimary, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                l10n.individualRebuy,
                                style: AppTypography.ibm(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    // Add-on row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showAddOnDialog();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, color: AppColors.accentPrimary, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                l10n.individualAddOn,
                                style: AppTypography.ibm(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.44,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateBlindsDialog() async {
    final l10n = AppLocalizations.of(context);
    final smallBlindController = TextEditingController(text: formatBlindValue(_currentSmallBlind));
    final bigBlindController = TextEditingController(text: formatBlindValue(_currentBigBlind));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.infoCardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.radius18),
          ),
          title: Text(
            l10n.individualUpdateBlinds,
            style: AppTypography.ibm(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: smallBlindController,
                keyboardType: TextInputType.number,
                style: AppTypography.ibm(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: l10n.individualSmallBlind,
                  labelStyle: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bigBlindController,
                keyboardType: TextInputType.number,
                style: AppTypography.ibm(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  labelText: l10n.individualBigBlind,
                  labelStyle: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.commonCancel,
                style: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () {
                final smallBlind = double.tryParse(smallBlindController.text);
                final bigBlind = double.tryParse(bigBlindController.text);

                if (smallBlind != null && bigBlind != null &&
                    smallBlind > 0 && bigBlind > smallBlind) {
                  Navigator.pop(context, {
                    'smallBlind': smallBlind,
                    'bigBlind': bigBlind,
                  });
                }
              },
              child: Text(
                l10n.commonUpdate,
                style: AppTypography.ibm(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentSmallBlind = (result['smallBlind'] as num).toDouble();
        _currentBigBlind = (result['bigBlind'] as num).toDouble();
        _blindsWereChanged = true;
      });

      if (widget.sessionId != null) {
        FirebaseService.updateIndividualSession(
          sessionId: widget.sessionId!,
          smallBlind: _currentSmallBlind,
          bigBlind: _currentBigBlind,
          hasBBante: _currentHasBBante,
        ).catchError((e) {});
      }
    }
  }

  void _goBackToHand() {
    final Map<String, dynamic> result = {
      'updatedStack': _currentStack,
      'totalBuyIn': _totalBuyIn,
      'stackHistory': _stackHistory,
    };

    if (_blindsWereChanged) {
      result['smallBlind'] = _currentSmallBlind;
      result['bigBlind'] = _currentBigBlind;
      result['hasBBante'] = _currentHasBBante;
    }

    Navigator.pop(context, result);
  }

  Future<bool?> _showRebuyConfirmationDialog() async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.infoCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.individualConfirmRebuy,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.individualRebuyCurrentStack(_formatStackValue(_currentStack)),
              style: AppTypography.ibm(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.individualRebuyReplaceMessage,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.commonCancel,
              style: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
              ),
              child: Text(
                l10n.individualProceedWithRebuy,
                style: AppTypography.ibm(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddOnDialog() async {
    final l10n = AppLocalizations.of(context);
    final isTournament = widget.gameType == GameType.tournament;
    final priceController = TextEditingController();
    final chipsController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.infoCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        title: Row(
          children: [
            const Icon(Icons.attach_money, color: AppColors.accentPrimary, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.individualAddOn,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTournament
                    ? l10n.individualAddOnDescriptionTournament
                    : l10n.individualAddOnDescription,
                style: AppTypography.ibm(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: AppTypography.ibm(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: isTournament ? l10n.individualAddOnPrice : l10n.individualAddOnAmount,
                  labelStyle: AppTypography.ibm(color: Colors.white.withValues(alpha: 0.5)),
                  prefixText: CurrencyService.prefixText,
                  suffixText: CurrencyService.suffixText,
                  prefixStyle: AppTypography.ibm(color: Colors.white, fontSize: 16),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (isTournament) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: chipsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.ibm(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: l10n.individualAddOnChips,
                    labelStyle: AppTypography.ibm(color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: AppTypography.ibm(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          GestureDetector(
            onTap: () {
              final price = double.tryParse(priceController.text);
              if (price == null || price <= 0) return;
              if (isTournament) {
                final chips = double.tryParse(chipsController.text);
                if (chips == null || chips <= 0) return;
                Navigator.pop(context, {'price': price, 'chips': chips});
              } else {
                Navigator.pop(context, {'price': price, 'chips': price});
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              child: Text(
                l10n.individualAddOnConfirm,
                style: AppTypography.ibm(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final price = result['price'] as double;
      final chips = result['chips'] as double;
      final noteText = widget.gameType == GameType.tournament
          ? 'Add-on: ${chips.toInt()} chips (${CurrencyService.formatCash(price)})'
          : 'Add-on: ${CurrencyService.formatCash(price)}';

      setState(() {
        _totalBuyIn += price;
        _currentStack += chips;
        _stackHistory.add({
          'timestamp': DateTime.now().toIso8601String(),
          'stackSize': _currentStack,
          'changeType': 'manual_increase',
          'changeAmount': chips,
          'note': noteText,
        });
      });

      if (widget.sessionId != null) {
        FirebaseService.updateIndividualSession(
          sessionId: widget.sessionId!,
          currentStack: _currentStack,
          totalBuyIn: _totalBuyIn,
          stackHistory: _stackHistory,
        ).catchError((e) {});
      }
    }
  }

  Future<void> _showRebuyDialog() async {
    final l10n = AppLocalizations.of(context);
    if (_currentStack > 0) {
      final confirmed = await _showRebuyConfirmationDialog();
      if (confirmed != true) return;
    }
    final rebuyAmountController = TextEditingController();
    final stackSizeController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.infoCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: AppColors.accentPrimary, size: 24),
            const SizedBox(width: 12),
            Text(
              l10n.individualRebuy,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.gameType == GameType.cash
                    ? l10n.individualEnterRebuyAmount
                    : l10n.individualEnterRebuyAmountAndStack,
                style: AppTypography.ibm(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: rebuyAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: AppTypography.ibm(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: l10n.individualRebuyAmount,
                  labelStyle: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
                  prefixText: CurrencyService.prefixText,
                  suffixText: CurrencyService.suffixText,
                  prefixStyle: AppTypography.ibm(color: Colors.white, fontSize: 16),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              if (widget.gameType == GameType.tournament) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: stackSizeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.ibm(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: l10n.individualNewStackSize,
                    labelStyle: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
                    hintText: l10n.individualChipCountAfterRebuy,
                    hintStyle: AppTypography.ibm(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Current session info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.individualSessionInfo,
                      style: AppTypography.ibm(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.individualTotalInvestedAmount(_totalBuyIn.toStringAsFixed(2)),
                      style: AppTypography.ibm(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    Text(
                      l10n.individualCurrentStackAmount(_formatStackValue(_currentStack)),
                      style: AppTypography.ibm(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                    Text(
                      l10n.individualRebuysCount(_rebuys.length),
                      style: AppTypography.ibm(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: AppTypography.ibm(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          GestureDetector(
            onTap: () {
              final rebuyAmount = double.tryParse(rebuyAmountController.text);

              if (rebuyAmount == null || rebuyAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.individualPleaseEnterValidRebuy),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (widget.gameType == GameType.cash) {
                Navigator.pop(context, {
                  'rebuyAmount': rebuyAmount,
                  'newStack': rebuyAmount,
                });
              } else {
                final stackSize = double.tryParse(stackSizeController.text);
                if (stackSize == null || stackSize <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.individualPleaseEnterValidStack),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'rebuyAmount': rebuyAmount,
                  'newStack': stackSize,
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
              ),
              child: Text(
                l10n.individualAddRebuy,
                style: AppTypography.ibm(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final rebuyAmount = result['rebuyAmount'] as double;
      final newStack = result['newStack'] as double;

      setState(() {
        _currentStack = newStack;
        _initialStack = newStack;
        _totalBuyIn += rebuyAmount;

        _rebuys.add({
          'timestamp': DateTime.now().toIso8601String(),
          'amount': rebuyAmount,
          'stackSize': newStack,
        });

        _stackHistory.add({
          'timestamp': DateTime.now().toIso8601String(),
          'stackSize': newStack,
          'changeType': 'rebuy',
          'changeAmount': rebuyAmount,
        });
      });

      if (widget.sessionId != null) {
        try {
          await FirebaseService.addRebuyToSession(
            sessionId: widget.sessionId!,
            rebuyAmount: rebuyAmount,
            newStackSize: newStack,
            newTotalBuyIn: _totalBuyIn,
          );
        } catch (e) {
          debugPrint('Error saving rebuy: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.gameType == GameType.cash
                ? l10n.individualRebuyAddedSimple(rebuyAmount.toStringAsFixed(2))
                : l10n.individualRebuyAddedWithStack(rebuyAmount.toStringAsFixed(2), newStack.toStringAsFixed(0)),
          ),
          backgroundColor: AppColors.accentPrimary,
        ),
      );
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final profitLoss = _currentStack - _initialStack;
    final isProfit = _currentStack > _initialStack;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Teal radial gradient at top
          Positioned(
            top: -screenWidth * 0.5,
            right: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 1.2,
              height: screenWidth * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A4A4A).withOpacity(0.6),
                    AppColors.accentPrimary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OnboardingProgressBar(),
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Row(
                      children: [
                        // Back arrow
                        GestureDetector(
                          onTap: _goBackToHand,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Session name + timer
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.sessionName,
                                style: AppTypography.ibm(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDuration(_sessionDuration),
                                style: AppTypography.ibm(
                                  fontSize: 14,
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add menu button
                        GestureDetector(
                          key: _dotsKey,
                          onTap: () => widget.gameType == GameType.cash
                              ? _showAddOnDialog()
                              : _showOptionsMenu(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BB Mode Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.infoCardBg,
                      borderRadius: BorderRadius.circular(AppDecorations.radius18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.individualBbMode,
                          style: AppTypography.ibm(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AppToggle(
                          value: _showBBMode,
                          onChanged: (value) {
                            setState(() => _showBBMode = value);
                            _saveBBMode(value);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Main Stack Card
                  Container(
                    key: _currentStackCardKey,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.infoCardBg,
                      borderRadius: BorderRadius.circular(AppDecorations.radius18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.individualCurrentStackLabel,
                              style: AppTypography.ibm(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showUpdateStackDialog,
                              child: Container(
                                key: _updateStackBtnKey,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accentPrimary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                                  border: Border.all(
                                    color: AppColors.accentPrimary.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit, color: AppColors.accentPrimary, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.commonUpdate,
                                      style: AppTypography.ibm(
                                        color: AppColors.accentPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatStackValue(_currentStack),
                            style: AppTypography.grotesk(
                              fontSize: 42,
                              color: stackColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                          ),
                          child: Row(
                            children: [
                              Text(
                                widget.gameType == GameType.cash
                                    ? '${profitLoss >= 0 ? '+' : '-'}${CurrencyService.formatCash(profitLoss.abs())}'
                                    : '${profitLoss >= 0 ? '+' : ''}${profitLoss.toStringAsFixed(0)}',
                                style: AppTypography.ibm(
                                  fontSize: 18,
                                  color: isProfit ? AppColors.accentPrimary : (profitLoss < 0 ? Colors.red : Colors.white),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${stackGrowthPercentage >= 0 ? '+' : ''}${stackGrowthPercentage.toStringAsFixed(1)}%)',
                                style: AppTypography.ibm(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),

                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stack Chart
                  if (_stackHistory.length > 1)
                    _buildStackChartCard(),

                  if (_stackHistory.length > 1)
                    const SizedBox(height: 16),

                  // Session Info (collapsible)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.infoCardBg,
                      borderRadius: BorderRadius.circular(AppDecorations.radius18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _statsExpanded = !_statsExpanded),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.individualSessionInfo,
                                style: AppTypography.ibm(
                                  fontSize: 17,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              AnimatedRotation(
                                turns: _statsExpanded ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _statsExpanded
                              ? Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildStatRow(l10n.individualStartingStack, widget.gameType == GameType.cash
                                        ? CurrencyService.formatCash(widget.startingStack)
                                        : widget.startingStack.toStringAsFixed(0)),
                                    _buildDivider(),
                                    _buildStatRow(l10n.individualInitialBuyIn, CurrencyService.formatCash(widget.buyInAmount)),
                                    _buildDivider(),
                                    _buildStatRow(l10n.individualRebuys, '${_rebuys.length}'),
                                    _buildDivider(),
                                    _buildStatRow(l10n.individualTotalInvested, CurrencyService.formatCash(_totalBuyIn)),
                                    _buildDivider(),
                                    _buildClickableStatRow(l10n.individualBlindsLabel, '${formatBlindValue(_currentSmallBlind)}/${formatBlindValue(_currentBigBlind)}', _showUpdateBlindsDialog),
                                    _buildDivider(),
                                    _buildStatRow(l10n.individualHandsLogged, '$_handsLogged'),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Go Back to Hand Button
                  GestureDetector(
                    onTap: _goBackToHand,
                    child: Container(
                      key: _logHandBtnKey,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.infoCardBg,
                        borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.individualGoBackToHand,
                            style: AppTypography.ibm(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  String _chartFormatValue(double value) {
    if (widget.gameType == GameType.cash) {
      return CurrencyService.formatCash(value);
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildStackChartCard() {
    final l10n = AppLocalizations.of(context);
    final history = _stackHistory;
    final hasData = history.length >= 2;

    return Container(
      key: _stackChartKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoCardBg,
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.individualStackChart,
                style: AppTypography.ibm(
                  fontSize: 17,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasData)
                GestureDetector(
                  onTap: () {
                    StackGrowthChartFullScreen.show(
                      context: context,
                      stackHistory: history,
                      completedHands: _completedHands,
                      startingStack: widget.startingStack,
                      formatValue: _chartFormatValue,
                      profitLoss: _currentStack - _initialStack,
                      sessionName: widget.sessionName,
                      sessionDuration: _sessionDuration,
                      isCashGame: widget.gameType == GameType.cash,
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          if (hasData)
            StackGrowthChart(
              stackHistory: history,
              completedHands: _completedHands,
              startingStack: widget.startingStack,
              formatValue: _chartFormatValue,
              height: 200,
              selectedIndex: _selectedHandIndex,
              onDotTapped: (index) => setState(() => _selectedHandIndex = index),
            )
          else
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  l10n.individualCompleteHandToSee,
                  style: AppTypography.ibm(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 15,
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStatRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.ibm(
                fontSize: 15,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w400,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit,
                  color: AppColors.accentPrimary,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
