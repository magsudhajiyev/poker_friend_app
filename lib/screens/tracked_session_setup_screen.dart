import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/components/app_text_field.dart';
import '../design_system/components/buttons/app_button.dart';
import '../design_system/components/tabs/animated_segmented_tabs.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../models/game_types.dart';
import '../services/analytics_service.dart';
import '../services/logger_service.dart';
import '../services/session_start_gate.dart';
import '../services/tracked_session_service.dart';
import '../utils/decimal_input.dart';
import '../utils/user_facing_error.dart';
import '../widgets/running_session_guard.dart';
import 'tracked_session_hub.dart';

/// "Track a session" setup: a name, Cash or Tournament, the buy-in (required)
/// and, for tournaments, an optional starting stack in chips. No blinds, seats
/// or players. Start = now (D21).
class TrackedSessionSetupScreen extends StatefulWidget {
  const TrackedSessionSetupScreen({super.key});

  @override
  State<TrackedSessionSetupScreen> createState() =>
      _TrackedSessionSetupScreenState();
}

class _TrackedSessionSetupScreenState extends State<TrackedSessionSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtl = TextEditingController();
  final _buyInCtl = TextEditingController();
  final _stackCtl = TextEditingController();
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  bool _starting = false;

  GameType get _gameType =>
      _tabs.index == 0 ? GameType.cash : GameType.tournament;

  double? get _buyIn {
    final v = parseDecimal(_buyInCtl.text);
    return (v != null && v > 0) ? v : null;
  }

  bool get _ready => _buyIn != null && !_starting;

  @override
  void dispose() {
    _nameCtl.dispose();
    _buyInCtl.dispose();
    _stackCtl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  String _defaultName(AppLocalizations l10n) {
    final kind =
        _gameType == GameType.cash ? l10n.setupCashGame : l10n.setupTournament;
    return '$kind · ${DateFormat.MMMd(l10n.localeName).format(DateTime.now())}';
  }

  Future<void> _start() async {
    if (!_ready) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _starting = true);
    try {
      if (!await RunningSessionGuard.ensureFree(context)) return;
      final name = _nameCtl.text.trim().isEmpty
          ? _defaultName(l10n)
          : _nameCtl.text.trim();
      final stack = _gameType == GameType.tournament
          ? parseDecimal(_stackCtl.text)
          : null;
      final session = await TrackedSessionService.start(
        name: name,
        gameType: _gameType,
        buyIn: _buyIn!,
        startingStack: (stack != null && stack > 0) ? stack : null,
      );
      AnalyticsService.capture('tracked_session_started',
          {'game_type': _gameType.value});
      if (!mounted) return;
      TrackedSessionHub.replaceWithHub(Navigator.of(context), session);
    } on SessionAlreadyRunning catch (e) {
      // Another session started meanwhile: the service created nothing.
      if (mounted) await RunningSessionGuard.showBlocked(context, e.running);
    } catch (e) {
      LoggerService.log('Tracked session start failed: $e',
          level: LogLevel.WARNING);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(UserFacingError.message(e)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cash = _gameType == GameType.cash;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(l10n.trackedSetupTitle,
            style: AppTypography.ibm(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.setupSessionName,
                hint: _defaultName(l10n),
                controller: _nameCtl,
                showClearButton: false,
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSegmentedTabs(
                controller: _tabs,
                labels: [l10n.setupCashGame, l10n.setupTournament],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: l10n.setupBuyInAmount,
                hint: l10n.setupEnterAmount,
                controller: _buyInCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter()],
                showClearButton: false,
                onChanged: (_) => setState(() {}),
              ),
              if (!cash) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: '${l10n.setupStartingStack} (${l10n.trackedOptional})',
                  hint: l10n.setupEnterChipStack,
                  controller: _stackCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  showClearButton: false,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: l10n.setupStartSession,
                fullWidth: true,
                onTap: _ready ? _start : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
