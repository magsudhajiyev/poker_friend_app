import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../services/auth_service.dart';
import '../services/username_service.dart';
import '../services/display_identity_service.dart';
import '../services/subscription_service.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import 'intro_screen.dart';
import 'help_support_screen.dart';
import 'username_setup_screen.dart';
import 'poker_hand_screen.dart';
import 'session_analytics_screen.dart';
import '../widgets/session_summary_card.dart';
import 'onboarding/onboarding_flow.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAdmin = false;

  // Editable fields
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _usernameCtrl;
  late FocusNode _nameFocus;
  late FocusNode _usernameFocus;
  bool _useNicknameInGame = false;
  bool _emailUpdates = false;

  // Username availability
  String? _usernameError;
  bool _isCheckingUsername = false;
  Timer? _usernameDebounce;
  String? _originalUsername;

  static const _bg = Color(0xFF0C0C0C);
  static const _surface = Color(0xFF161719);
  static const _elevated = Color(0xFF2C2C2E);
  static const _secondary = Color(0xFFB9B9B9);
  static const _saveGreen = Color(0xFFA3FF78);
  static const _danger = Color(0xFFFF3B30);
  static const _grey = Color(0xFF3A3A3C);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _nameFocus = FocusNode()..addListener(() => setState(() {}));
    _usernameFocus = FocusNode()..addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final username = await UsernameService.getUsername();
    final useNickname = await UsernameService.getUseNicknameInGame();

    bool isAdmin = false;
    final uid = AuthService.userId;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        isAdmin = doc.data()?['role'] == 'admin';
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _nameCtrl.text = AuthService.userDisplayName;
        _emailCtrl.text = AuthService.currentUser?.email ?? '';
        _usernameCtrl.text = username ?? '';
        _originalUsername = username;
        _useNicknameInGame = useNickname;
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    }
  }

  // ── Username availability ──────────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final cleaned = value.replaceAll('@', '').trim();
    if (cleaned == (_originalUsername ?? '')) {
      setState(() { _usernameError = null; _isCheckingUsername = false; });
      return;
    }
    if (cleaned.isEmpty) {
      setState(() { _usernameError = null; _isCheckingUsername = false; });
      return;
    }
    final validationError = UsernameService.validateUsername(cleaned);
    if (validationError != null) {
      setState(() { _usernameError = validationError; _isCheckingUsername = false; });
      return;
    }
    setState(() { _isCheckingUsername = true; _usernameError = null; });
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      final available = await UsernameService.isUsernameAvailable(cleaned,
          currentUserEmail: AuthService.currentUser?.email);
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError = available ? null : 'Username already taken';
        });
      }
    });
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving) return;
    final newName = _nameCtrl.text.trim();
    final newUsername = _usernameCtrl.text.replaceAll('@', '').trim();

    if (_usernameError != null) {
      _showSnack('Fix username error before saving');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Save display name
      if (newName.isNotEmpty && newName != AuthService.userDisplayName) {
        await AuthService.updateProfile(displayName: newName);
        final uid = AuthService.userId;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid)
              .update({'displayName': newName, 'displayNameLower': newName.toLowerCase()});
        }
      }

      // Save nickname toggle
      await UsernameService.setUseNicknameInGame(_useNicknameInGame);
      DisplayIdentityService.clearCache();

      // Save username if changed
      if (newUsername.isNotEmpty && newUsername != _originalUsername) {
        final claimed = await UsernameService.claimUsername(newUsername);
        if (!claimed) {
          if (mounted) _showSnack('Username no longer available');
          setState(() => _isSaving = false);
          return;
        }
        setState(() => _originalUsername = newUsername);
      }

      if (mounted) {
        _showSnack('Saved successfully', isSuccess: true);
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to save: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.ibmPlexSans(color: Colors.white)),
      backgroundColor: isSuccess ? const Color(0xFF2C2C2E) : const Color(0xFF3A3A3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Sign out / Delete ──────────────────────────────────────────────────────

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out', style: GoogleFonts.ibmPlexSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: _secondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                    context, MaterialPageRoute(builder: (_) => IntroScreen()), (_) => false);
              }
            },
            child: Text('Sign Out', style: GoogleFonts.ibmPlexSans(color: _danger, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account', style: GoogleFonts.ibmPlexSans(color: _danger, fontWeight: FontWeight.w600)),
        content: Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.\n\nIf you have an active subscription, please cancel it first in your device settings.',
          style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.ibmPlexSans(color: _secondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount();
            },
            child: Text('Delete', style: GoogleFonts.ibmPlexSans(color: _danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final uid = AuthService.userId;
    if (uid == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).delete();
      await firestore.collection('user_stats').doc(uid).delete();
      for (final coll in ['session_results', 'poker_sessions', 'opponents']) {
        final snap = await firestore.collection(coll).where('userId', isEqualTo: uid).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }
      final opponents = await firestore.collection('opponents').where('userId', isEqualTo: uid).get();
      for (final doc in opponents.docs) {
        await firestore.collection('opponent_stats').doc(doc.id).delete();
      }
      await AuthService.deleteAccount();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context, MaterialPageRoute(builder: (_) => IntroScreen()), (_) => false);
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to delete account: $e');
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
          width: size, height: size, fit: BoxFit.cover,
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
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2A5A30), Color(0xFF1A3A20)],
        ),
      ),
      child: Center(
        child: Text(initials,
            style: GoogleFonts.ibmPlexSans(
                fontSize: size * 0.35, fontWeight: FontWeight.w600, color: const Color(0xFF87ED81))),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF89F1EC)))),
      );
    }

    final hPad = MediaQuery.of(context).size.width * 0.044;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          TopNavBar(
            title: 'Settings',
            onBack: () => Navigator.pop(context),
            backgroundColor: _surface,
            rightAction: GestureDetector(
              onTap: _isSaving ? null : _save,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                height: 44,
                child: _isSaving
                    ? Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(_saveGreen),
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Save',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _saveGreen,
                            height: 20 / 17,
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 40),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar ──────────────────────────────────────────────
                  Center(
                    child: SizedBox(
                      width: 74,
                      height: 74 + 14.0, // avatar + button overlap
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildAvatar(74),
                          Positioned(
                            bottom: 0,
                            left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _elevated,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('Edit',
                                    style: GoogleFonts.ibmPlexSans(
                                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Nickname toggle card ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Use nickname in games',
                                  style: GoogleFonts.ibmPlexSans(
                                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                'Show @${_usernameCtrl.text.replaceAll('@', '').isNotEmpty ? _usernameCtrl.text.replaceAll('@', '') : 'username'} instead of your name in events and hand logging',
                                style: GoogleFonts.ibmPlexSans(fontSize: 13, color: _secondary, height: 20 / 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildToggle(_useNicknameInGame, (v) => setState(() => _useNicknameInGame = v)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Inputs ──────────────────────────────────────────────
                  _buildInputField(
                    label: 'Edit Name',
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    placeholder: 'Your name',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Edit email',
                    controller: _emailCtrl,
                    placeholder: 'your@email.com',
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    onTap: () => _showSnack('Email changes require account re-authentication. Contact support to change your email.'),
                  ),
                  const SizedBox(height: 16),
                  _buildUsernameField(),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'Change password',
                    controller: TextEditingController(text: '***********'),
                    placeholder: '***********',
                    readOnly: true,
                    onTap: _showChangePasswordSheet,
                  ),

                  const SizedBox(height: 32),

                  // ── List rows ───────────────────────────────────────────
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
                    icon: const Icon(Icons.email_outlined, color: AppColors.contentInactive, size: 24),
                    title: 'Email updates',
                    trailing: _buildToggle(_emailUpdates, (v) => setState(() => _emailUpdates = v)),
                  ),
                  _buildRow(
                    icon: _svgIcon('assets/icons/X.svg'),
                    title: 'Follow @finaltable',
                    onTap: () => launchUrl(Uri.parse('https://x.com/finaltable'), mode: LaunchMode.externalApplication),
                  ),
                  _buildRow(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.contentInactive, size: 24),
                    title: 'Sign out',
                    onTap: _showSignOutConfirmation,
                  ),
                  _buildRow(
                    icon: const SizedBox(width: 24),
                    title: 'Delete Account',
                    titleColor: _grey,
                    onTap: _showDeleteConfirmation,
                    showCaret: true,
                  ),

                  // ── Admin dev tools ─────────────────────────────────────
                  if (_isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildDevTools(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input helpers ──────────────────────────────────────────────────────────

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    FocusNode? focusNode,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    final isFocused = focusNode?.hasFocus ?? false;
    final isFilled = controller.text.isNotEmpty;
    final borderColor = isFocused
        ? const Color(0xFF4CDE78)
        : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w500, color: _secondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: readOnly ? _secondary : Colors.white,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.ibmPlexSans(fontSize: 15, color: _secondary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: isFilled && !readOnly
                  ? GestureDetector(
                      onTap: () => setState(() => controller.clear()),
                      child: const Icon(Icons.cancel_rounded, color: AppColors.contentInactive, size: 18),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    final value = _usernameCtrl.text.replaceAll('@', '');
    final isFilled = value.isNotEmpty;
    final isFocused = _usernameFocus.hasFocus;
    final hasError = _usernameError != null;
    final borderColor = hasError
        ? _danger
        : isFocused
            ? const Color(0xFF4CDE78)
            : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit username',
            style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w500, color: _secondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            style: GoogleFonts.ibmPlexSans(fontSize: 15, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'username',
              hintStyle: GoogleFonts.ibmPlexSans(fontSize: 15, color: _secondary),
              prefixText: '@',
              prefixStyle: GoogleFonts.ibmPlexSans(fontSize: 15, color: Colors.white),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: _isCheckingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.contentInactive),
                        ),
                      ),
                    )
                  : isFilled
                      ? GestureDetector(
                          onTap: () { setState(() => _usernameCtrl.clear()); _onUsernameChanged(''); },
                          child: const Icon(Icons.cancel_rounded, color: AppColors.contentInactive, size: 18),
                        )
                      : null,
            ),
            onChanged: _onUsernameChanged,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(_usernameError!,
                style: GoogleFonts.ibmPlexSans(fontSize: 11, color: _danger)),
          ),
      ],
    );
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38, height: 24,
        decoration: BoxDecoration(
          color: value ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(74),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: value ? 18 : 2, top: 3,
              child: Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0C0C),
                  borderRadius: BorderRadius.circular(42),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required Widget icon,
    required String title,
    Color? titleColor,
    VoidCallback? onTap,
    Widget? trailing,
    bool showCaret = false,
  }) {
    final hasAction = onTap != null || trailing != null;
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
              child: Text(title,
                  style: GoogleFonts.ibmPlexSans(
                      fontSize: 17, fontWeight: FontWeight.w400,
                      color: titleColor ?? Colors.white, height: 26 / 17)),
            ),
            if (trailing != null) trailing
            else if (hasAction || showCaret)
              SvgPicture.asset('assets/icons/CaretRight.svg',
                  width: 14, height: 14,
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

  // ── Change password sheet ──────────────────────────────────────────────────

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Change Password',
                  style: GoogleFonts.ibmPlexSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Text('We\'ll send a password reset link to your email address.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 14, color: _secondary), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final email = AuthService.currentUser?.email;
                    if (email != null) {
                      try {
                        await AuthService.sendPasswordReset(email);
                        if (mounted) _showSnack('Password reset email sent to $email', isSuccess: true);
                      } catch (e) {
                        if (mounted) _showSnack('Failed to send reset email');
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: _elevated, borderRadius: BorderRadius.circular(60)),
                    child: Text('Send Reset Email',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSans(
                            fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Admin dev tools ────────────────────────────────────────────────────────

  Widget _buildDevTools() {
    final override = SubscriptionService.debugPremiumOverride;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bug_report, color: Color(0xFFFF6B6B), size: 20),
            const SizedBox(width: 8),
            Text('Dev Tools', style: GoogleFonts.ibmPlexSans(
                fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B6B))),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Premium Override', style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                Text(
                  override == null
                      ? 'Real: ${SubscriptionService.isPremium ? 'Premium' : 'Free'}'
                      : 'Overridden: ${override ? 'Premium' : 'Free'}',
                  style: GoogleFonts.ibmPlexSans(fontSize: 12, color: _secondary),
                ),
              ]),
              Switch(
                value: SubscriptionService.isPremium,
                onChanged: (v) async { await SubscriptionService.setDebugPremiumOverride(v); setState(() {}); },
                activeColor: const Color(0xFF62E3BC),
                inactiveThumbColor: const Color(0xFF8C8C8C),
                inactiveTrackColor: const Color(0xFF35373C),
              ),
            ],
          ),
          if (override != null) ...[
            GestureDetector(
              onTap: () async { await SubscriptionService.setDebugPremiumOverride(null); setState(() {}); },
              child: Text('Reset to real', style: GoogleFonts.ibmPlexSans(
                  fontSize: 13, color: const Color(0xFF89F1EC),
                  decoration: TextDecoration.underline, decorationColor: const Color(0xFF89F1EC))),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          _devButton('Quick Debug Session (7P Cash 1/2)', const Color(0xFFFF6B6B), _launchQuickDebugSession),
          const SizedBox(height: 8),
          _devButton('Test Summary Card (Tournament)', const Color(0xFFFF6B6B), _showTestSummaryCard),
          const SizedBox(height: 8),
          _devButton('Test Onboarding + Paywall', const Color(0xFF6B9FFF), () {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const OnboardingFlow(skipNickname: true, testMode: true)));
          }),
          const SizedBox(height: 8),
          _devButton('Open Latest Session Analytics', const Color(0xFFFFB74D), _openLatestSession),
        ],
      ),
    );
  }

  Widget _devButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Center(
          child: Text(label, style: GoogleFonts.ibmPlexSans(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }

  void _showTestSummaryCard() {
    SessionSummaryCard.show(
      context: context,
      data: SessionSummaryData(
        sessionName: 'Deepstack Turbo',
        gameType: GameType.tournament,
        profitLoss: -600.0,
        totalBuyIn: 600.0,
        handsPlayed: 47,
        biggestPot: 95000,
        biggestPotBB: 1000.0,
        durationMinutes: 185,
        finishedPlace: 11,
        fieldSize: 28,
        prizeWon: 0,
        biggestPotWonCards: 'A♠ K♥',
        biggestPotLostCards: 'Hand #42',
      ),
    );
  }

  Future<void> _openLatestSession() async {
    try {
      final userId = AuthService.currentUser?.uid;
      if (userId == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('poker_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) { if (mounted) _showSnack('No sessions found'); return; }
      final doc = snap.docs.first;
      final data = doc.data()..['id'] = doc.id;
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => SessionAnalyticsScreen(sessionData: data, sessionId: doc.id)));
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  void _launchQuickDebugSession() {
    final sessionManager = PokerSessionManager(
      smallBlind: 1, bigBlind: 2, playerCount: 9,
      gameType: GameType.cash, sessionName: 'Debug Session',
      initialBuyIn: 200, startingStack: 200,
    );
    const names = ['Hero', 'Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank'];
    for (int i = 0; i < 7; i++) {
      sessionManager.addPlayer(i + 1, names[i]);
      sessionManager.setPlayerStack(i + 1, 200);
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PokerHandScreen(
        smallBlind: 1, bigBlind: 2, numberOfPlayers: 9,
        gameType: GameType.cash, hasBBante: false, ante: 0,
        sessionName: 'Debug Session', buyInAmount: 200, startingStack: 200,
        initialSeat: 1, initialButtonPosition: 1, sessionManager: sessionManager,
      ),
    ));
  }
}
