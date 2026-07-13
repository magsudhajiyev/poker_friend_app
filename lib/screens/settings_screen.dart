import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../design_system/components/buttons/close_circle_button.dart';
import '../design_system/components/dialogs/app_dialog.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/sheets/app_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system/constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../services/locale_service.dart';
import '../services/currency_service.dart';
import '../services/skip_hand_scouting_service.dart';
import '../services/username_service.dart';
import '../services/club_service.dart';
import '../services/session_result_service.dart';
import '../services/club_request_service.dart';
import '../services/support_request_service.dart';
import '../models/currency.dart';
import '../models/club.dart';
import '../onboarding/onboarding_state.dart';
import 'intro_screen.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';
import 'earnings_chart_screen.dart';
import 'knowledge_base_screen.dart';
import 'help_support_screen.dart';
import 'logging_mode_selection_screen.dart';
import 'club/club_dashboard_screen.dart';
import 'admin/club_requests_screen.dart';
import 'admin/support_requests_screen.dart';
import 'admin/notification_tester_screen.dart';
import '../widgets/register_club_dialog.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _username;
  bool _isAppAdmin = false;
  int _pendingRequestCount = 0;
  int _pendingSupportCount = 0;
  List<Club> _clubs = [];
  bool _scoutingEnabled = false;

  static const _bg = AppColors.bgPrimary;
  static const _surface = AppColors.bgSurface;
  static const _sectionLabel = AppColors.bgOverlay;
  static const _secondary = AppColors.contentInactive;
  static const _danger = AppColors.accentDanger;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await UsernameService.getUsername();
    if (mounted) setState(() => _username = username);

    try {
      final isAdmin = await ClubRequestService.isAppAdmin();
      if (isAdmin) {
        final count = await ClubRequestService.getPendingCount();
        final supportCount = await SupportRequestService.getPendingCount();
        if (mounted) {
          setState(() {
            _isAppAdmin = true;
            _pendingRequestCount = count;
            _pendingSupportCount = supportCount;
          });
        }
      }
    } catch (_) {}

    try {
      final clubs = await ClubService.getClubs();
      if (mounted) setState(() => _clubs = clubs);
    } catch (_) {}

    if (mounted) {
      setState(() => _scoutingEnabled = SkipHandScoutingService.isEnabled);
    }
  }

  String _currentLocaleName() {
    final l10n = AppLocalizations.of(context);
    final code = LocaleService.currentLocaleCode;
    if (code == null) return l10n.settingsLanguageSystem;
    switch (code) {
      case 'de': return 'Deutsch';
      case 'en': return 'English';
      case 'es': return 'Español';
      case 'fr': return 'Français';
      case 'pl': return 'Polski';
      case 'pt': return 'Português';
      case 'ru': return 'Русский';
      default: return code;
    }
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Widget _buildAvatar(double size) {
    final photoURL = AuthService.userPhotoURL;
    if (photoURL != null && photoURL.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: photoURL,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildInitialsAvatar(size),
          errorWidget: (_, __, ___) => _buildInitialsAvatar(size),
        ),
      );
    }
    return _buildInitialsAvatar(size);
  }

  Widget _buildInitialsAvatar(double size) {
    final name = AuthService.userDisplayName;
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A5A30), Color(0xFF1A3A20)],
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTypography.ibm(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: AppColors.accentPrimary,
          ),
        ),
      ),
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  static const _languageOptions = [
    (code: null,  label: 'System Default', flagAsset: null),
    (code: 'en',  label: 'English',        flagAsset: 'assets/icons/Property 1=United States of America (US).svg'),
    (code: 'de',  label: 'Deutsch',        flagAsset: 'assets/icons/Property 1=Germany (DE).svg'),
    (code: 'es',  label: 'Español',        flagAsset: 'assets/icons/Property 1=Spain (ES).svg'),
    (code: 'fr',  label: 'Français',       flagAsset: 'assets/icons/Property 1=France (FR).svg'),
    (code: 'pl',  label: 'Polski',         flagAsset: 'assets/icons/Property 1=Poland (PL).svg'),
    (code: 'pt',  label: 'Português',      flagAsset: 'assets/icons/Property 1=Portugal (PT).svg'),
    (code: 'ru',  label: 'Русский',        flagAsset: 'assets/icons/Property 1=Russia (RU).svg'),
  ];

  void _showLanguagePicker() {
    final l10n = AppLocalizations.of(context);
    String? selectedCode = LocaleService.currentLocaleCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final maxHeight = MediaQuery.of(context).size.height * 0.85;
            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
                border: Border.all(color: AppColors.borderStrong),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.settingsChooseLanguage,
                            style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 20 / 15,
                            ),
                          ),
                          CloseCircleButton(onTap: () => Navigator.pop(context)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Bordered language list
                      Column(
                        children: _languageOptions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final opt = entry.value;
                            final isSelected = opt.code == selectedCode;
                            return Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setSheetState(() => selectedCode = opt.code),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.bgElevated : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                    ),
                                    child: Row(
                                      children: [
                                        // Icon: globe for system default, flag for others
                                        if (opt.flagAsset == null)
                                          const Icon(Icons.public, size: 24, color: AppColors.textPrimary)
                                        else
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: SvgPicture.asset(
                                              opt.flagAsset!,
                                              width: 24,
                                              height: 18,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            opt.label,
                                            style: AppTypography.ibm(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textPrimary,
                                              height: 22 / 15,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check, size: 18, color: AppColors.contentInactive),
                                      ],
                                    ),
                                  ),
                                ),
                                if (idx < _languageOptions.length - 1)
                                  const SizedBox(height: 16),
                              ],
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      // Info row
                      Row(
                        children: [
                          const Icon(Icons.public, size: 13, color: AppColors.contentInactive),
                          const SizedBox(width: 4),
                          Text(
                            l10n.settingsMoreLanguagesLater,
                            style: AppTypography.ibm(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 16 / 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Cancel + Choose buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                                  border: Border.all(color: AppColors.borderStrong),
                                ),
                                child: Text(
                                  l10n.commonCancel,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.ibm(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 20 / 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                LocaleService.setLocale(
                                  selectedCode != null ? Locale(selectedCode!) : null,
                                );
                                Navigator.pop(context);
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.bgInverse,
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                                ),
                                child: Text(
                                  l10n.settingsChoose,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.ibm(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textInverse,
                                    height: 20 / 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const _currencyFlagAssets = {
    'USD': 'assets/icons/Property 1=United States of America (US).svg',
    'EUR': 'assets/icons/Property 1=Europe.svg',
    'GBP': 'assets/icons/Property 1=United Kingdom.svg',
    'CAD': 'assets/icons/Property 1=Canada.svg',
    'AUD': 'assets/icons/Property 1=Australia.svg',
    'BRL': 'assets/icons/Property 1=Brasil.svg',
    'PLN': 'assets/icons/Property 1=Poland (PL).svg',
    'RUB': 'assets/icons/Property 1=Russia (RU).svg',
    'INR': 'assets/icons/Property 1=India.svg',
    'JPY': 'assets/icons/Property 1=Japan.svg',
    'CNY': 'assets/icons/Property 1=China.svg',
    'KRW': 'assets/icons/Property 1=Korea.svg',
    'SEK': 'assets/icons/Property 1=Sweden.svg',
    'MXN': 'assets/icons/Property 1=Mexico.svg',
    'TRY': 'assets/icons/Property 1=Turkey.svg',
    'CZK': 'assets/icons/Property 1=Czech Republic.svg',
    'NOK': 'assets/icons/Property 1=Norway.svg',
    'DKK': 'assets/icons/Property 1=Denmark.svg',
    'CHF': 'assets/icons/Property 1=Switzerland.svg',
    'ILS': 'assets/icons/Property 1=Israli.svg',
    'UAH': 'assets/icons/Property 1=ukraine.svg',
    'ARS': 'assets/icons/Property 1=Argentina.svg',
  };

  void _showCurrencyPicker() {
    final l10n = AppLocalizations.of(context);
    String selectedCode = CurrencyService.code;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final maxHeight = MediaQuery.of(context).size.height * 0.78;
            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDecorations.radiusXl),
                  topRight: Radius.circular(AppDecorations.radiusXl),
                ),
                border: Border.all(color: AppColors.borderStrong),
              ),
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsChooseCurrency,
                          style: AppTypography.ibm(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 20 / 15,
                          ),
                        ),
                        CloseCircleButton(onTap: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Scrollable currency list — no dividers, 4px gap, selected = grey pill
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: Currency.all.length,
                        itemBuilder: (context, index) {
                          final currency = Currency.all[index];
                          final isSelected = currency.code == selectedCode;
                          final flagPath = _currencyFlagAssets[currency.code];
                          const noCodeSet = {'EUR', 'GBP', 'CAD', 'AUD'};
                          final displayName = noCodeSet.contains(currency.code)
                              ? currency.name
                              : '${currency.name} (${currency.code})';
                          return Padding(
                            padding: EdgeInsets.only(bottom: index < Currency.all.length - 1 ? 4 : 0),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setSheetState(() => selectedCode = currency.code),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.bgElevated : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        currency.symbol,
                                        style: AppTypography.ibm(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: AppTypography.ibm(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          color: isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (flagPath != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: SvgPicture.asset(flagPath, width: 24, height: 18, fit: BoxFit.cover),
                                      )
                                    else
                                      Text(currency.flag, style: const TextStyle(fontSize: 18)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                            const SizedBox(height: 8),
                            // Info row
                            Row(
                              children: [
                                const Icon(Icons.public, size: 13, color: AppColors.contentInactive),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.settingsMoreCurrenciesLater,
                                  style: AppTypography.ibm(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 16 / 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Cancel + Choose buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                                        border: Border.all(color: AppColors.borderStrong),
                                      ),
                                      child: Text(
                                        l10n.commonCancel,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.ibm(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          height: 20 / 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      CurrencyService.setCurrency(selectedCode);
                                      Navigator.pop(context);
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgInverse,
                                        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                                      ),
                                      child: Text(
                                        l10n.settingsChoose,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.ibm(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textInverse,
                                          height: 20 / 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }

  // ── Bankroll navigation ────────────────────────────────────────────────────

  Future<void> _navigateToBankroll() async {
    try {
      final results = await SessionResultService.getAllSessionResults();
      if (!mounted) return;
      if (results.isEmpty) {
        _showNoEarningsDataDialog();
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsChartScreen()));
      }
    } catch (_) {
      if (mounted) _showNoEarningsDataDialog();
    }
  }

  void _showNoEarningsDataDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppDecorations.radiusXl))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.accentPrimary, size: 48),
            const SizedBox(height: 16),
            Text(l10n.navDrawerNoEarningsTitle,
                style: AppTypography.ibm(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.navDrawerNoEarningsBody,
                style: AppTypography.ibm(fontSize: 14, color: _secondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.separatorDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.buttonRadius)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(l10n.drillGotIt,
                    style: AppTypography.ibm(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Clubs ──────────────────────────────────────────────────────────────────

  /// Club registration is a Club-tier feature — non-Club users get the
  /// paywall pre-scrolled to the Club card (same gate as the nav drawer).
  void _openRegisterClub() {
    if (SubscriptionService.isClub) {
      showRegisterClubDialog(context);
    } else {
      PaywallScreen.show(
        context,
        featureName: AppLocalizations.of(context).settingsRegisterClub,
        preselectedTier: 2,
      );
    }
  }

  void _showClubs() {
    final l10n = AppLocalizations.of(context);
    if (_clubs.isEmpty) {
      AppDialog.show<void>(
        context,
        title: l10n.settingsNoClubsYet,
        showCloseButton: true,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/Club.svg',
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.settingsNoClubsHint,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 22 / 15,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _openRegisterClub();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgInverse,
                  borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                ),
                child: Text(
                  l10n.settingsRegisterAClub,
                  textAlign: TextAlign.center,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textInverse,
                    height: 20 / 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppDecorations.radiusXl))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsYourClubs,
                  style: AppTypography.ibm(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 16),
              ..._clubs.map((club) => _buildClubRow(club)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubRow(Club club) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClubDashboardScreen(club: club)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2A5A30),
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              child: Center(
                child: Text(
                  club.name.length >= 2 ? club.name.substring(0, 2).toUpperCase() : club.name.toUpperCase(),
                  style: AppTypography.ibm(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentPrimary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(club.name,
                  style: AppTypography.ibm(fontSize: 17, color: Colors.white)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.contentInactive, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Guided tour ────────────────────────────────────────────────────────────

  void _showGuidedTourSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppDecorations.radiusXl))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsGuidedTour,
                  style: AppTypography.ibm(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Text(l10n.settingsChooseTour, style: AppTypography.ibm(fontSize: 14, color: _secondary)),
              const SizedBox(height: 20),
              _buildTourOption(
                icon: Icons.style_rounded,
                title: l10n.settingsFullLoggingTour,
                subtitle: l10n.settingsFullLoggingTourSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  OnboardingState.startFromPhase(1);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoggingModeSelectionScreen()))
                      .then((_) { if (OnboardingState.isReplay) OnboardingState.completeReplay(); });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.accentPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(AppDecorations.radius10)),
              child: Icon(icon, color: AppColors.accentPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.ibm(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: AppTypography.ibm(fontSize: 13, color: _secondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.contentInactive, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  void _showSignOutConfirmation() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
        title: Text(l10n.navDrawerSignOutTitle,
            style: AppTypography.ibm(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(l10n.navDrawerSignOutMessage,
            style: AppTypography.ibm(color: Colors.white, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel,
                style: AppTypography.ibm(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Navigate to Intro FIRST so the logout registers on the first tap
              // (see profile_screen.dart) — awaiting signOut() first can trip
              // AuthWrapper's recovery loading. Sign out in the background.
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => IntroScreen()), (route) => false);
              try {
                await AuthService.signOut();
              } catch (_) {}
            },
            child: Text(l10n.navDrawerSignOut,
                style: AppTypography.ibm(color: _danger, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth * 0.044; // ≈16px at 375pt
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          TopNavBar(
            title: l10n.settingsTitle,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubscriptionBanner(),
                  const SizedBox(height: 24),
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildSection(
                    label: l10n.settingsGeneral,
                    children: [
                      _buildRow(
                        icon: _svgIcon('assets/icons/Club.svg'),
                        title: l10n.settingsClubs,
                        onTap: _showClubs,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.contentInactive, size: 24),
                        title: l10n.settingsBankroll,
                        onTap: _navigateToBankroll,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.contentInactive, size: 24),
                        title: l10n.settingsRegisterClub,
                        onTap: _openRegisterClub,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.translate_rounded, color: AppColors.contentInactive, size: 24),
                        title: l10n.settingsLanguage,
                        subtitle: _currentLocaleName(),
                        onTap: _showLanguagePicker,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.monetization_on_outlined, color: AppColors.contentInactive, size: 24),
                        title: l10n.settingsCurrency,
                        subtitle: '${CurrencyService.current.name} (${CurrencyService.symbol})',
                        onTap: _showCurrencyPicker,
                      ),
                      _buildToggleRow(
                        icon: const Icon(Icons.visibility_outlined, color: AppColors.contentInactive, size: 24),
                        title: l10n.settingsSkipHandScouting,
                        subtitle: l10n.settingsSkipHandScoutingDesc,
                        value: _scoutingEnabled,
                        onChanged: (v) async {
                          await SkipHandScoutingService.setEnabled(v);
                          setState(() => _scoutingEnabled = v);
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    label: l10n.settingsKnowledgeBase,
                    children: [
                      _buildRow(
                        icon: const Icon(Icons.school_outlined, color: AppColors.contentInactive, size: 24),
                        title: l10n.settingsGuidedTour,
                        subtitle: l10n.settingsGuidedTourSubtitle,
                        onTap: _showGuidedTourSheet,
                      ),
                      _buildRow(
                        icon: _svgIcon('assets/icons/ChartBar.svg'),
                        title: l10n.settingsUnderstandingStats,
                        subtitle: l10n.settingsUnderstandingStatsSubtitle,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const KnowledgeBaseScreen(section: KnowledgeBaseSection.stats))),
                      ),
                      _buildRow(
                        icon: _svgIcon('assets/icons/Club.svg'),
                        title: l10n.settingsClubsEvents,
                        subtitle: l10n.settingsClubsEventsSubtitle,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const KnowledgeBaseScreen(section: KnowledgeBaseSection.clubs))),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    label: l10n.settingsAbout,
                    children: [
                      _buildRow(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.contentInactive, size: 24),
                        title: l10n.profileContactSupport,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                      ),
                      _buildRow(
                        icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.contentInactive, size: 24),
                        title: l10n.profileShareFeedback,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                      ),
                      _buildRow(
                        icon: const Icon(Icons.logout_rounded, color: _danger, size: 24),
                        title: l10n.profileSignOut,
                        titleColor: _danger,
                        onTap: _showSignOutConfirmation,
                        isLast: true,
                      ),
                    ],
                  ),

                  // Admin section
                  if (_isAppAdmin) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      label: l10n.settingsAdmin,
                      children: [
                        _buildRow(
                          icon: const Icon(Icons.business_center_rounded, color: Color(0xFFE8B55A), size: 24),
                          title: l10n.settingsClubRequests,
                          subtitle: _pendingRequestCount > 0 ? l10n.settingsPending(_pendingRequestCount) : null,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClubRequestsScreen()));
                            _loadData();
                          },
                        ),
                        _buildRow(
                          icon: const Icon(Icons.support_agent_rounded, color: Color(0xFFE8B55A), size: 24),
                          title: l10n.settingsSupportRequests,
                          subtitle: _pendingSupportCount > 0 ? l10n.settingsPending(_pendingSupportCount) : null,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportRequestsScreen()));
                            _loadData();
                          },
                        ),
                        _buildRow(
                          icon: const Icon(Icons.notifications_active_rounded, color: AppColors.accentPrimary, size: 24),
                          title: l10n.settingsNotificationTester,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationTesterScreen())),
                          isLast: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _buildSubscriptionBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(AppDecorations.radiusLg)),
        child: Row(
          children: [
            // Logo placeholder
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.separatorDark,
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
                border: Border.all(color: AppColors.borderStrong, width: 1),
              ),
              child: Center(
                child: Text('FT',
                    style: AppTypography.ibm(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentPrimary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).settingsGetPlus,
                      style: AppTypography.ibm(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0)),
                  Text(AppLocalizations.of(context).settingsGetPlusSubtitle,
                      style: AppTypography.ibm(fontSize: 15, fontWeight: FontWeight.w500, color: _secondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.contentInactive, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final displayName = AuthService.userDisplayName;
    final email = AuthService.currentUser?.email ?? '';
    final handle = _username != null && _username!.isNotEmpty ? '@$_username' : '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(AppDecorations.radiusLg)),
        child: Row(
          children: [
            _buildAvatar(64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(displayName,
                            style: AppTypography.ibm(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (handle.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(handle,
                            style: AppTypography.ibm(fontSize: 15, fontWeight: FontWeight.w500, color: _secondary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(email,
                      style: AppTypography.ibm(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.contentInactive, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String label, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(label,
              style: AppTypography.ibm(fontSize: 15, fontWeight: FontWeight.w500, color: _sectionLabel)),
        ),
        ...children,
      ],
    );
  }

  Widget _buildRow({
    required Widget icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppTypography.ibm(
                          fontSize: 17, fontWeight: FontWeight.w400,
                          color: titleColor ?? Colors.white, height: 26 / 17)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: AppTypography.ibm(fontSize: 11, color: _secondary, height: 16 / 11)),
                ],
              ),
            ),
            SvgPicture.asset('assets/icons/CaretRight.svg',
                width: 16, height: 16,
                colorFilter: const ColorFilter.mode(AppColors.contentInactive, BlendMode.srcIn)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required Widget icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: AppTypography.ibm(
                        fontSize: 17, fontWeight: FontWeight.w400,
                        color: Colors.white, height: 26 / 17)),
                if (subtitle != null)
                  Text(subtitle,
                      style: AppTypography.ibm(fontSize: 11, color: _secondary, height: 16 / 11)),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _svgIcon(String path) {
    return SvgPicture.asset(path, width: 24, height: 24,
        colorFilter: const ColorFilter.mode(AppColors.contentInactive, BlendMode.srcIn));
  }
}
