import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_types.dart';
import '../models/poker_game_state.dart' show formatBlindValue;
import '../services/firebase_service.dart';
import '../design_system/components/form_drawer.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../onboarding/onboarding_state.dart';
import '../onboarding/onboarding_tour.dart' show buildTooltip, createOnboardingCoachMark;
import '../onboarding/onboarding_prefs.dart';
import '../onboarding/onboarding_progress_bar.dart';
import '../design_system/components/app_toggle.dart';
import '../models/hand_state_machine.dart';
import '../widgets/stack_growth_chart.dart';
import '../widgets/session_end_bankroll_sheet.dart';
import '../widgets/session_leak_chip.dart';
import '../widgets/session_summary_card.dart';
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/components/bodies/form_fields.dart';
import '../design_system/components/app_text_field.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/dialogs/dialog_action_bar.dart';
import '../design_system/components/buttons/primary_pill_button.dart';
import '../design_system/components/buttons/outlined_pill_button.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../design_system/components/tween_number.dart';
import 'poker_hand_screen.dart';
import 'home_screen.dart';
import '../widgets/main_shell.dart';
import '../utils/user_facing_error.dart';
import '../utils/decimal_input.dart';

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

  // Session start time for live timer display
  final DateTime? startTime;

  // Hub mode params (non-null = hub mode, null = legacy push-on-top mode)
  final PokerSessionManager? sessionManager;
  final int? heroSeat;
  final int? initialButtonPosition;
  final double? ante;

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
    this.startTime,
    this.liveStackHistory,
    this.completedHands,
    this.sessionManager,
    this.heroSeat,
    this.initialButtonPosition,
    this.ante,
  });

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  /// Hub mode: SessionDetailsScreen is the base screen, launched from setup.
  /// Legacy mode: pushed on top of PokerHandScreen via ⓘ button.
  bool get _isHubMode => widget.sessionManager != null;

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
  final GlobalKey _endSessionRowKey = GlobalKey(debugLabel: 'endSessionRow');
  final GlobalKey _backButtonKey = GlobalKey(debugLabel: 'backButton');

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

    // Use the passed-in start time so the timer shows correct elapsed
    // time immediately, without waiting for the Firebase fetch.
    _sessionStartTime = widget.startTime ?? widget.sessionManager?.sessionStartTime;
    if (_sessionStartTime != null) {
      _sessionDuration = DateTime.now().difference(_sessionStartTime!);
    }

    _resumeSession();
    _loadBBMode();
    _startTimer();

    if (_isHubMode) {
      _scheduleSessionDetailsHubTour();
    } else {
      _scheduleSessionDetailsTour();
    }

    // Stack chart return tour: triggered after hand 2 when user taps ⓘ.
    // This can land on a freshly-pushed (non-hub) SessionDetailsScreen,
    // so check here in initState — not only in the hub pop-back handler.
    if (OnboardingState.isOnboardingActive &&
        OnboardingState.stackChartReturnTourPending) {
      OnboardingState.stackChartReturnTourPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        _showStackChartReturnTour();
      });
    }
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

  void _scheduleSessionDetailsHubTour() {
    if (!OnboardingState.isOnboardingActive ||
        !OnboardingState.sessionDetailsHubTourPending) return;
    OnboardingState.sessionDetailsHubTourPending = false;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _showSessionDetailsHubTour();
    });
  }

  void _showSessionDetailsHubTour() {
    final l10n = AppLocalizations.of(context);

    final targets = <TargetFocus>[];

    // Step 1: Spotlight the stack card
    if (_currentStackCardKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'hub_stack_card',
          keyTarget: _currentStackCardKey,
          shape: ShapeLightFocus.RRect,
          radius: 18,
          paddingFocus: 6,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: l10n.onboardingSessionDetailsHubTitle,
                  body: l10n.onboardingSessionDetailsHubBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    // Step 2: Spotlight the 3-dot menu
    if (_dotsKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'hub_dots_menu',
          keyTarget: _dotsKey,
          shape: ShapeLightFocus.Circle,
          paddingFocus: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return buildTooltip(
                  title: l10n.onboardingHubMenuTitle,
                  body: l10n.onboardingHubMenuBody,
                  onNext: () => controller.next(),
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    }

    // Step 3: Spotlight the "Log a Hand" button
    targets.add(
      TargetFocus(
        identify: 'hub_log_hand',
        keyTarget: _logHandBtnKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        paddingFocus: 6,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return buildTooltip(
                title: l10n.onboardingHubLogHandTitle,
                body: l10n.onboardingHubLogHandBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    );

    final coach = createOnboardingCoachMark(
      targets: targets,
      onFinish: () {
        // Tour finished — advance to phase 4 when user taps "Log a Hand"
      },
      context: context,
    );
    coach.show(context: context);
  }

  void _showStackChartReturnTour() {
    final l10n = AppLocalizations.of(context);

    final targets = <TargetFocus>[];

    if (_stackChartKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: 'stack_chart_return',
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
                  title: l10n.guidedStackChartReturnTitle,
                  body: l10n.guidedStackChartReturnBody,
                  onNext: () => controller.next(),
                  context: context,
                  isLast: true,
                );
              },
            ),
          ],
        ),
      );
    }

    if (targets.isEmpty) {
      // No chart to spotlight — skip to stop session tour
      _showStopSessionTour();
      return;
    }

    final coach = createOnboardingCoachMark(
      targets: targets,
      onFinish: () {
        _showStopSessionTour();
      },
      context: context,
    );
    coach.show(context: context);
  }

  /// Spotlights the stop button and instructs the user to end the session
  /// directly from SessionDetailsScreen.
  void _showStopSessionTour() {
    if (!mounted) return;

    if (_backButtonKey.currentContext == null) return;

    final l10n = AppLocalizations.of(context);
    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'stop_session',
        keyTarget: _backButtonKey,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return buildTooltip(
                title: l10n.guidedStopSessionTitle,
                body: l10n.guidedStopSessionBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = createOnboardingCoachMark(
      targets: targets,
      onFinish: () {
        // User should now tap the stop button to end the session
      },
      context: context,
      hideSkip: true,
    );
    coach.show(context: context);
  }

  void _showEndSessionTour() {
    if (!mounted) return;

    if (_dotsKey.currentContext == null) {
      // Dots menu not visible — fall back to auto-end
      _endSessionFromHub();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final targets = <TargetFocus>[
      TargetFocus(
        identify: 'end_session_dots',
        keyTarget: _dotsKey,
        shape: ShapeLightFocus.Circle,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return buildTooltip(
                title: l10n.guidedEndSessionTitle,
                body: l10n.guidedEndSessionBody,
                onNext: () => controller.next(),
                context: context,
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];

    final coach = createOnboardingCoachMark(
      targets: targets,
      onFinish: () {
        // User dismissed the spotlight — they should now tap the dots menu
        // and select "End Session" themselves. The advanceTo(5) call happens
        // inside _endSessionFromHub() when they actually end the session.
      },
      context: context,
    );
    coach.show(context: context);
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

    final coach = createOnboardingCoachMark(
      targets: targets,
      onFinish: () {
        // Tour overlay dismissed
      },
      context: context,
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

    // Compute elapsed time immediately so the display doesn't flash 0:00
    // when navigating back to this screen mid-session.
    if (mounted) {
      setState(() {
        _sessionDuration = DateTime.now().difference(_sessionStartTime!);
      });
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
        final value = parseDecimal(newStackController.text);
        if (value != null) {
          result = {
            'stack': value,
            'note': noteController.text.trim(),
          };
          Navigator.pop(context);
        }
      },
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // Current Stack display
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
            Container(height: 1, color: AppColors.bgOverlay),
            // New Total field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: TextField(
                controller: newStackController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter()],
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
            Container(height: 1, color: AppColors.bgOverlay),
            // Note field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                    _MenuActionRow(
                      icon: Icons.add_circle_outline,
                      iconColor: AppColors.accentPrimary,
                      label: l10n.individualRebuy,
                      labelColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _showRebuyDialog();
                      },
                    ),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    _MenuActionRow(
                      icon: Icons.attach_money,
                      iconColor: AppColors.accentPrimary,
                      label: l10n.individualAddOn,
                      labelColor: Colors.white,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddOnDialog();
                      },
                    ),
                    if (_isHubMode) ...[
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      _MenuActionRow(
                        rowKey: _endSessionRowKey,
                        icon: Icons.stop_circle_outlined,
                        iconColor: AppColors.accentDanger,
                        label: l10n.sessionDetailsEndSession,
                        labelColor: AppColors.accentDanger,
                        destructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _endSessionFromHub();
                        },
                      ),
                    ],
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

    Widget buildBlindField(
      String label,
      TextEditingController ctrl, {
      bool autofocus = false,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            autofocus: autofocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            style: AppTypography.ibm(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(
                    color: AppColors.accentPrimary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ],
      );
    }

    final result = await AppDialog.show<Map<String, double>>(
      context,
      title: l10n.individualUpdateBlinds,
      subtitle: l10n.handTakesEffectNextHand,
      body: Row(
        children: [
          Expanded(
            child: buildBlindField(
              l10n.setupSmallBlind,
              smallBlindController,
              autofocus: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: buildBlindField(l10n.setupBigBlind, bigBlindController),
          ),
        ],
      ),
      actions: Builder(
        builder: (ctx) => Row(
          children: [
            Expanded(
              child: OutlinedPillButton(
                label: l10n.commonCancel,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryPillButton(
                label: l10n.commonApply,
                onTap: () {
                  final sb = parseDecimal(smallBlindController.text);
                  final bb = parseDecimal(bigBlindController.text);
                  if (sb != null && bb != null && sb > 0 && bb >= sb) {
                    Navigator.pop(ctx, {'smallBlind': sb, 'bigBlind': bb});
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentSmallBlind = result['smallBlind']!;
        _currentBigBlind = result['bigBlind']!;
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
    if (OnboardingState.isOnboardingActive && !_isHubMode) {
      // During tour, stop button ends session — pop with endSession flag
      // so PokerHandScreen handles the actual session end.
      final Map<String, dynamic> result = {
        'updatedStack': _currentStack,
        'totalBuyIn': _totalBuyIn,
        'stackHistory': _stackHistory,
        'endSession': true,
      };
      Navigator.pop(context, result);
      return;
    }

    if (_isHubMode) {
      _navigateToHandLogging();
    } else {
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
  }

  Future<void> _navigateToHandLogging() async {
    if (!_isHubMode) return;
    final sm = widget.sessionManager!;

    // Sync any blind changes made in session details back to session manager
    if (_blindsWereChanged) {
      sm.smallBlind = _currentSmallBlind;
      sm.bigBlind = _currentBigBlind;
    }

    // Advance onboarding to phase 4 (hand logging)
    if (OnboardingState.isOnboardingActive && OnboardingState.currentPhase < 4) {
      OnboardingState.advanceTo(4);
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PokerHandScreen(
          smallBlind: _currentSmallBlind,
          bigBlind: _currentBigBlind,
          numberOfPlayers: 9,
          gameType: widget.gameType,
          hasBBante: _currentHasBBante,
          ante: widget.ante ?? (_currentHasBBante ? _currentBigBlind : 0),
          sessionName: widget.sessionName,
          buyInAmount: widget.buyInAmount,
          startingStack: widget.startingStack,
          initialSeat: widget.heroSeat,
          initialButtonPosition: widget.initialButtonPosition,
          sessionManager: sm,
        ),
      ),
    );

    // Update state from hand logging results
    if (result != null && mounted) {
      setState(() {
        if (result['updatedStack'] != null) {
          _currentStack = (result['updatedStack'] as num).toDouble();
        }
        if (result['totalBuyIn'] != null) {
          _totalBuyIn = (result['totalBuyIn'] as num).toDouble();
        }
        if (result['stackHistory'] != null) {
          _stackHistory = List<Map<String, dynamic>>.from(result['stackHistory']);
        }
        if (result['smallBlind'] != null) {
          _currentSmallBlind = (result['smallBlind'] as num).toDouble();
        }
        if (result['bigBlind'] != null) {
          _currentBigBlind = (result['bigBlind'] as num).toDouble();
        }
        if (result['handsLogged'] != null) {
          _handsLogged = result['handsLogged'] as int;
        }
        if (result['biggestPot'] != null) {
          _biggestPot = (result['biggestPot'] as num).toDouble();
        }
        if (result['completedHands'] != null) {
          _completedHands = List<HandRecord>.from(result['completedHands']);
        }
      });
    }

    // If PokerHandScreen ended the session (e.g. via stop button), navigate home
    if (result != null && result['sessionEnded'] == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // After returning from hand logging during onboarding: show stack chart tour.
    // Use two post-frame callbacks to ensure the widget tree has fully rebuilt
    // with the updated _stackHistory before checking _stackChartKey.
    if (OnboardingState.isOnboardingActive &&
        OnboardingState.stackChartReturnTourPending &&
        mounted) {
      OnboardingState.stackChartReturnTourPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          _showStackChartReturnTour();
        });
      });
    }
  }

  Future<void> _handleHubBackButton() async {
    if (!_isHubMode) {
      _goBackToHand();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.confirm(
      context,
      title: l10n.sessionDetailsLeaveConfirmTitle,
      message: l10n.sessionDetailsLeaveConfirmBody,
      confirmLabel: l10n.sessionDetailsEndSession,
    );

    if (confirmed == true && mounted) {
      await _endSessionFromHub();
    }
  }

  Future<void> _endSessionFromHub() async {
    if (!_isHubMode) return;
    final sm = widget.sessionManager!;

    try {
      // Capture final stack
      final ourSeat = sm.ourSeatNumber ?? widget.heroSeat;
      if (ourSeat != null) {
        sm.addFinalStackEntry(_currentStack);
      }

      await sm.endSession();

      if (!mounted) return;

      // Show bankroll sheet (skip for tutorial)
      final isTourSession = OnboardingState.isOnboardingActive;
      final stackHistory = sm.stackHistory;
      Map<String, dynamic>? bankrollResult;

      if (stackHistory.isNotEmpty && !isTourSession) {
        final lastStack = (stackHistory.last['stackSize'] as num).toDouble();
        final profit = lastStack - sm.totalBuyIn;
        final sessionDuration = sm.sessionStartTime != null
            ? DateTime.now().difference(sm.sessionStartTime!).inMinutes
            : null;
        bankrollResult = await SessionEndBankrollSheet.show(
          context: context,
          gameType: sm.gameType,
          profitLoss: profit,
          totalBuyIn: sm.totalBuyIn,
          durationMinutes: sessionDuration,
        );

        // Save tournament finish data
        if (bankrollResult != null) {
          final fPlace = bankrollResult['finishedPlace'] as int?;
          final fSize = bankrollResult['fieldSize'] as int?;
          final fPrize = bankrollResult['prizeWon'] as double?;
          if (fPlace != null || fSize != null || fPrize != null) {
            try {
              await FirebaseService.updateIndividualSession(
                sessionId: sm.sessionId!,
                finishedPlace: fPlace,
                fieldSize: fSize,
                prizeWon: fPrize,
              );
            } catch (_) {}
          }
        }
      }

      if (!mounted) return;

      // Show session summary (skip for tutorial — no meaningful data)
      if (stackHistory.isNotEmpty && !isTourSession) {
        final double profitLoss;
        final int? finishedPlace;
        final int? fieldSize;
        final double? prizeWon;
        if (bankrollResult != null) {
          profitLoss = (bankrollResult['profitLoss'] as num?)?.toDouble() ?? 0.0;
          finishedPlace = bankrollResult['finishedPlace'] as int?;
          fieldSize = bankrollResult['fieldSize'] as int?;
          prizeWon = bankrollResult['prizeWon'] as double?;
        } else if (widget.gameType == GameType.cash) {
          final lastStack = (stackHistory.last['stackSize'] as num).toDouble();
          profitLoss = lastStack - sm.totalBuyIn;
          finishedPlace = null;
          fieldSize = null;
          prizeWon = null;
        } else {
          profitLoss = 0.0;
          finishedPlace = null;
          fieldSize = null;
          prizeWon = null;
        }

        final duration = sm.sessionStartTime != null
            ? DateTime.now().difference(sm.sessionStartTime!).inMinutes
            : 0;

        await SessionSummaryCard.show(
          context: context,
          // Per-session leak feedback (hidden for tutorial sessions; the
          // chip also self-gates on the leak_detector feature flag).
          footer: !sm.isTutorialSession && sm.sessionId != null
              ? SessionLeakChip(sessionId: sm.sessionId!)
              : null,
          data: SessionSummaryData(
            sessionName: widget.sessionName,
            gameType: widget.gameType,
            profitLoss: profitLoss,
            totalBuyIn: sm.totalBuyIn,
            handsPlayed: sm.completedHands.length,
            biggestPot: sm.biggestPot,
            biggestPotBB: sm.biggestPotBB,
            durationMinutes: duration,
            finishedPlace: finishedPlace,
            fieldSize: fieldSize,
            prizeWon: prizeWon,
            biggestPotWonCards: sm.biggestPotWonCards,
            biggestPotLostCards: sm.biggestPotLostCards,
          ),
        );
      }

      if (!mounted) return;

      // Navigate home
      if (OnboardingState.isOnboardingActive) {
        // Pop to existing MainShell — advanceTo(5) notifies HomeScreen's
        // listener which triggers the SessionResultTour immediately.
        OnboardingState.advanceTo(5);
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UserFacingError.message(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showRebuyConfirmationDialog() async {
    final l10n = AppLocalizations.of(context);
    return ConfirmDialog.confirm(
      context,
      title: l10n.individualConfirmRebuy,
      message:
          '${l10n.individualRebuyCurrentStack(_formatStackValue(_currentStack))}\n\n${l10n.individualRebuyReplaceMessage}',
      confirmLabel: l10n.individualProceedWithRebuy,
    );
  }

  Future<void> _showAddOnDialog() async {
    final l10n = AppLocalizations.of(context);
    final isTournament = widget.gameType == GameType.tournament;
    final priceController = TextEditingController();
    final chipsController = TextEditingController();

    final result = await AppDialog.show<Map<String, dynamic>>(
      context,
      title: l10n.individualAddOn,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTournament
                ? l10n.individualAddOnDescriptionTournament
                : l10n.individualAddOnDescription,
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          AppFormField(
            controller: priceController,
            label: isTournament
                ? l10n.individualAddOnPrice
                : l10n.individualAddOnAmount,
            prefixText: CurrencyService.prefixText,
            suffixText: CurrencyService.suffixText,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            autofocus: true,
          ),
          if (isTournament) ...[
            const SizedBox(height: 16),
            AppFormField(
              controller: chipsController,
              label: l10n.individualAddOnChips,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter()],
            ),
          ],
        ],
      ),
      actions: DialogActionBar(
        confirmLabel: l10n.individualAddOnConfirm,
        confirmColor: AppColors.accentPrimary,
        confirmTextColor: AppColors.textInverse,
        autoDismiss: false,
        onConfirm: () {
          final price = parseDecimal(priceController.text);
          if (price == null || price <= 0) return;
          if (isTournament) {
            final chips = parseDecimal(chipsController.text);
            if (chips == null || chips <= 0) return;
            Navigator.pop(context, {'price': price, 'chips': chips});
          } else {
            Navigator.pop(context, {'price': price, 'chips': price});
          }
        },
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

    final result = await AppDialog.show<Map<String, dynamic>>(
      context,
      title: l10n.individualRebuy,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.gameType == GameType.cash
                ? l10n.individualEnterRebuyAmount
                : l10n.individualEnterRebuyAmountAndStack,
            style: AppTypography.ibm(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          AppFormField(
            controller: rebuyAmountController,
            label: l10n.individualRebuyAmount,
            prefixText: CurrencyService.prefixText,
            suffixText: CurrencyService.suffixText,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            autofocus: true,
          ),
          if (widget.gameType == GameType.tournament) ...[
            const SizedBox(height: 16),
            AppFormField(
              controller: stackSizeController,
              label: l10n.individualNewStackSize,
              hintText: l10n.individualChipCountAfterRebuy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter()],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.individualSessionInfo,
                  style: AppTypography.ibm(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.individualTotalInvestedAmount(
                      _totalBuyIn.toStringAsFixed(2)),
                  style: AppTypography.ibm(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                Text(
                  l10n.individualCurrentStackAmount(
                      _formatStackValue(_currentStack)),
                  style: AppTypography.ibm(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                Text(
                  l10n.individualRebuysCount(_rebuys.length),
                  style: AppTypography.ibm(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: DialogActionBar(
        confirmLabel: l10n.individualRebuy,
        confirmColor: AppColors.accentPrimary,
        confirmTextColor: AppColors.textInverse,
        autoDismiss: false,
        onConfirm: () {
          final rebuyAmount = parseDecimal(rebuyAmountController.text);
          if (rebuyAmount == null || rebuyAmount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.individualPleaseEnterValidRebuy),
                backgroundColor: AppColors.accentDanger,
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
            final stackSize = parseDecimal(stackSizeController.text);
            if (stackSize == null || stackSize <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.individualPleaseEnterValidStack),
                  backgroundColor: AppColors.accentDanger,
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

    return PopScope(
      canPop: !_isHubMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isHubMode) {
          _handleHubBackButton();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Row(
                      children: [
                        // Stop / end-session button — self-contained 44px red
                        // stop badge (svg has its own red bg + white icon).
                        GestureDetector(
                          key: _backButtonKey,
                          onTap: _isHubMode ? _handleHubBackButton : _goBackToHand,
                          behavior: HitTestBehavior.opaque,
                          child: SvgPicture.asset(
                            'assets/icons/card icons/stop.svg',
                            width: 44,
                            height: 44,
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
                        // Menu button — 3-dot menu in hub mode / cash game shows add-on directly in legacy.
                        // Matches canonical top-nav circle style (44px, bgSurface).
                        GestureDetector(
                          key: _dotsKey,
                          onTap: _isHubMode
                              ? _showOptionsMenu
                              : (widget.gameType == GameType.cash
                                  ? _showAddOnDialog
                                  : _showOptionsMenu),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.bgSurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isHubMode ? Icons.more_vert : Icons.add,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BB Mode Toggle — flat inline row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
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
                      color: AppColors.bgSurface,
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
                          child: TweenNumber(
                            value: _currentStack,
                            format: _formatStackValue,
                            style: AppTypography.grotesk(
                              fontSize: 42,
                              color: stackColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Flat inline P/L — no nested container
                        Row(
                          children: [
                            Text(
                              widget.gameType == GameType.cash
                                  ? '${profitLoss >= 0 ? '+' : '-'}${CurrencyService.formatCash(profitLoss.abs())}'
                                  : '${profitLoss >= 0 ? '+' : ''}${profitLoss.toStringAsFixed(0)}',
                              style: AppTypography.ibm(
                                fontSize: 17,
                                color: isProfit ? AppColors.accentPrimary : (profitLoss < 0 ? Colors.red : Colors.white),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${stackGrowthPercentage >= 0 ? '+' : ''}${stackGrowthPercentage.toStringAsFixed(1)}%)',
                              style: AppTypography.ibm(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
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

                  // Session Info (collapsible) — flat, no card wrapper
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _statsExpanded = !_statsExpanded),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
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
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _statsExpanded
                              ? Column(
                                  children: [
                                    const SizedBox(height: 8),
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

                  // Log a Hand / Go Back to Hand Button
                  GestureDetector(
                    onTap: _goBackToHand,
                    child: Container(
                      key: _logHandBtnKey,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: (_isHubMode && _handsLogged == 0)
                            ? AppColors.accentPrimary
                            : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                        border: (_isHubMode && _handsLogged == 0)
                            ? null
                            : Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Hub-mode "Log a Hand" is a clean text-only
                          // primary CTA — resume mode keeps the back arrow
                          // to signal returning to an active hand.
                          if (!(_isHubMode && _handsLogged == 0)) ...[
                            const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            (_isHubMode && _handsLogged == 0)
                                ? l10n.sessionDetailsLogAHand
                                : l10n.individualGoBackToHand,
                            style: AppTypography.ibm(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: (_isHubMode && _handsLogged == 0)
                                  ? Colors.black
                                  : Colors.white,
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
        color: AppColors.bgSurface,
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

/// One tappable row inside the session-details options dropdown
/// (`_showOptionsMenu`). Adds three layers of selection feedback that
/// the drawer previously lacked:
///
/// 1. **Press-in tint** — the row background lights while the finger is
///    down: `bgSurface` (or `accentDanger` @ 12%) fades in over 80ms.
/// 2. **Confirmation flash** — after tap-up, the tint stays visible for
///    ~140ms before the row's action runs (which typically closes the
///    menu). This is the beat that lets the user *see* which row they
///    picked, iOS-context-menu style.
/// 3. **Haptic tick** — `selectionClick` for normal actions,
///    `mediumImpact` for destructive ones (End Session).
class _MenuActionRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final Key? rowKey;
  final bool destructive;

  const _MenuActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
    this.rowKey,
    this.destructive = false,
  });

  @override
  State<_MenuActionRow> createState() => _MenuActionRowState();
}

class _MenuActionRowState extends State<_MenuActionRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  Future<void> _handleTap() async {
    if (widget.destructive) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    _setPressed(true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final activeFill = widget.destructive
        ? AppColors.accentDanger.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.08);
    return GestureDetector(
      key: widget.rowKey,
      onTap: _handleTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _pressed ? activeFill : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            Icon(widget.icon, color: widget.iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  widget.label,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.labelColor,
                    height: 1.44,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
