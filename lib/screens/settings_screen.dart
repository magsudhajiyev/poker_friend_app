import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system/constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../services/currency_service.dart';
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

  static const _bg = Color(0xFF0C0C0C);
  static const _surface = Color(0xFF161719);
  static const _sectionLabel = Color(0xFF3A3A3C);
  static const _secondary = Color(0xFFB9B9B9);
  static const _danger = Color(0xFFFF3B30);

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
          style: GoogleFonts.ibmPlexSans(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF87ED81),
          ),
        ),
      ),
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  void _showLanguagePicker() {
    final l10n = AppLocalizations.of(context);
    final currentCode = LocaleService.currentLocaleCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101115),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsLanguage,
                  style: GoogleFonts.ibmPlexSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 20),
              _buildLanguageOption(l10n.settingsLanguageSystem, null, currentCode, flag: '🌐'),
              _buildLanguageOption('English', 'en', currentCode, flag: '🇺🇸'),
              _buildLanguageOption('Deutsch', 'de', currentCode, flag: '🇩🇪'),
              _buildLanguageOption('Español', 'es', currentCode, flag: '🇪🇸'),
              _buildLanguageOption('Français', 'fr', currentCode, flag: '🇫🇷'),
              _buildLanguageOption('Polski', 'pl', currentCode, flag: '🇵🇱'),
              _buildLanguageOption('Português', 'pt', currentCode, flag: '🇧🇷'),
              _buildLanguageOption('Русский', 'ru', currentCode, flag: '🇷🇺'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String label, String? code, String? currentCode, {String? flag}) {
    final isSelected = code == currentCode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        LocaleService.setLocale(code != null ? Locale(code) : null);
        Navigator.pop(context);
        setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            if (flag != null) ...[Text(flag, style: const TextStyle(fontSize: 22)), const SizedBox(width: 12)],
            Expanded(
              child: Text(label,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF89F1EC) : Colors.white,
                  )),
            ),
            if (isSelected) const Icon(Icons.check_rounded, color: Color(0xFF89F1EC), size: 22),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    final l10n = AppLocalizations.of(context);
    final currentCode = CurrencyService.code;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101115),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.settingsCurrency,
                      style: GoogleFonts.ibmPlexSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 20),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: Currency.all.map((c) => _buildCurrencyOption(c, currentCode)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrencyOption(Currency currency, String currentCode) {
    final isSelected = currency.code == currentCode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        CurrencyService.setCurrency(currency.code);
        Navigator.pop(context);
        setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(currency.symbol,
                  style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? const Color(0xFF89F1EC) : Colors.white.withOpacity(0.6),
                  )),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${currency.name} (${currency.code})',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF89F1EC) : Colors.white,
                  )),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_rounded, color: Color(0xFF89F1EC), size: 22),
              ),
            Text(currency.flag, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
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
      backgroundColor: const Color(0xFF161719),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded, color: Color(0xFF89F1EC), size: 48),
            const SizedBox(height: 16),
            Text(l10n.navDrawerNoEarningsTitle,
                style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.navDrawerNoEarningsBody,
                style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _secondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1F21),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Got it',
                    style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Clubs ──────────────────────────────────────────────────────────────────

  void _showClubs() {
    if (_clubs.isEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF161719),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/icons/Club.svg', width: 48, height: 48, colorFilter: const ColorFilter.mode(Color(0xFF89F1EC), BlendMode.srcIn)),
              const SizedBox(height: 16),
              Text('No Clubs Yet',
                  style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Register or join a club to see them here.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _secondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showRegisterClubDialog(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1F21),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Register a Club',
                      style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161719),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Clubs',
                  style: GoogleFonts.ibmPlexSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  club.name.length >= 2 ? club.name.substring(0, 2).toUpperCase() : club.name.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF87ED81)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(club.name,
                  style: GoogleFonts.ibmPlexSans(fontSize: 17, color: Colors.white)),
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
      backgroundColor: const Color(0xFF161719),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsGuidedTour,
                  style: GoogleFonts.ibmPlexSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Choose which tour to replay', style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _secondary)),
              const SizedBox(height: 20),
              _buildTourOption(
                icon: Icons.style_rounded,
                title: l10n.settingsFullLoggingTour,
                subtitle: l10n.settingsFullLoggingTourSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  OnboardingState.startFromPhase(1, individualMode: false);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoggingModeSelectionScreen()))
                      .then((_) { if (OnboardingState.isReplay) OnboardingState.completeReplay(); });
                },
              ),
              _buildTourOption(
                icon: Icons.touch_app_rounded,
                title: l10n.settingsIndividualLoggingTour,
                subtitle: l10n.settingsIndividualLoggingTourSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  OnboardingState.startFromPhase(1, individualMode: true);
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
              decoration: BoxDecoration(color: const Color(0xFF89F1EC).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF89F1EC), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.ibmPlexSans(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
                  Text(subtitle, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: _secondary)),
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
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.navDrawerSignOutTitle,
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(l10n.navDrawerSignOutMessage,
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel,
                style: GoogleFonts.ibmPlexSans(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                    context, MaterialPageRoute(builder: (_) => IntroScreen()), (route) => false);
              }
            },
            child: Text(l10n.navDrawerSignOut,
                style: GoogleFonts.ibmPlexSans(color: _danger, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth * 0.044; // ≈16px at 375pt

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          SizedBox(height: safeTop),
          _buildTopNav(hPad),
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
                    label: 'General',
                    children: [
                      _buildRow(
                        icon: _svgIcon('assets/icons/Club.svg'),
                        title: 'Clubs',
                        onTap: _showClubs,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.contentInactive, size: 24),
                        title: 'Bankroll',
                        onTap: _navigateToBankroll,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.contentInactive, size: 24),
                        title: 'Register Club',
                        onTap: () => showRegisterClubDialog(context),
                      ),
                      _buildRow(
                        icon: const Icon(Icons.translate_rounded, color: AppColors.contentInactive, size: 24),
                        title: 'Language',
                        subtitle: _currentLocaleName(),
                        onTap: _showLanguagePicker,
                      ),
                      _buildRow(
                        icon: const Icon(Icons.monetization_on_outlined, color: AppColors.contentInactive, size: 24),
                        title: 'Currency',
                        subtitle: '${CurrencyService.current.name} (${CurrencyService.symbol})',
                        onTap: _showCurrencyPicker,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    label: 'Knowledge Base',
                    children: [
                      _buildRow(
                        icon: const Icon(Icons.school_outlined, color: AppColors.contentInactive, size: 24),
                        title: 'Guided Tour',
                        subtitle: 'Replay onboarding tours',
                        onTap: _showGuidedTourSheet,
                      ),
                      _buildRow(
                        icon: _svgIcon('assets/icons/ChartBar.svg'),
                        title: 'Understanding Your Stats',
                        subtitle: 'Learn what each metric means',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const KnowledgeBaseScreen(section: KnowledgeBaseSection.stats))),
                      ),
                      _buildRow(
                        icon: _svgIcon('assets/icons/Club.svg'),
                        title: 'Clubs & Events',
                        subtitle: 'How club play works',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const KnowledgeBaseScreen(section: KnowledgeBaseSection.clubs))),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    label: 'About',
                    children: [
                      _buildRow(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.contentInactive, size: 24),
                        title: 'Contact support',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                      ),
                      _buildRow(
                        icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.contentInactive, size: 24),
                        title: 'Share your feedback',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                      ),
                      _buildRow(
                        icon: _svgIcon('assets/icons/X.svg'),
                        title: 'Follow @finaltable',
                        onTap: () => launchUrl(Uri.parse('https://x.com/finaltable'), mode: LaunchMode.externalApplication),
                      ),
                      _buildRow(
                        icon: const Icon(Icons.logout_rounded, color: _danger, size: 24),
                        title: 'Sign out',
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
                      label: 'Admin',
                      children: [
                        _buildRow(
                          icon: const Icon(Icons.business_center_rounded, color: Color(0xFFE8B55A), size: 24),
                          title: 'Club Requests',
                          subtitle: _pendingRequestCount > 0 ? '$_pendingRequestCount pending' : null,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClubRequestsScreen()));
                            _loadData();
                          },
                        ),
                        _buildRow(
                          icon: const Icon(Icons.support_agent_rounded, color: Color(0xFFE8B55A), size: 24),
                          title: 'Support Requests',
                          subtitle: _pendingSupportCount > 0 ? '$_pendingSupportCount pending' : null,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportRequestsScreen()));
                            _loadData();
                          },
                        ),
                        _buildRow(
                          icon: const Icon(Icons.notifications_active_rounded, color: Color(0xFF89F1EC), size: 24),
                          title: 'Notification Tester',
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

  Widget _buildTopNav(double hPad) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
                ),
              ),
            ),
            Text('Settings',
                style: GoogleFonts.ibmPlexSans(
                    fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            // Logo placeholder
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F21),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
              ),
              child: Center(
                child: Text('FT',
                    style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF89F1EC))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get Final Table Plus',
                      style: GoogleFonts.ibmPlexSans(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0)),
                  Text('Log more hands and AI analysis',
                      style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w500, color: _secondary)),
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
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
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
                            style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (handle.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(handle,
                            style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w500, color: _secondary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(email,
                      style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
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
              style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w500, color: _sectionLabel)),
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
                      style: GoogleFonts.ibmPlexSans(
                          fontSize: 17, fontWeight: FontWeight.w400,
                          color: titleColor ?? Colors.white, height: 26 / 17)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: GoogleFonts.ibmPlexSans(fontSize: 11, color: _secondary, height: 16 / 11)),
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

  Widget _svgIcon(String path) {
    return SvgPicture.asset(path, width: 24, height: 24,
        colorFilter: const ColorFilter.mode(AppColors.contentInactive, BlendMode.srcIn));
  }
}
