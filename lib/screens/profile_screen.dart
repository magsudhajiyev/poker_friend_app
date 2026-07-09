import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/components/modals/confirm_dialog.dart';
import '../services/auth_service.dart';
import '../services/username_service.dart';
import '../services/display_identity_service.dart';
import '../services/subscription_service.dart';
import '../models/hand_state_machine.dart';
import '../models/game_types.dart';
import 'intro_screen.dart';
import 'auth_screen_experimental.dart';
import 'help_support_screen.dart';
import 'username_setup_screen.dart';
import 'poker_hand_screen.dart';
import 'session_analytics_screen.dart';
import '../widgets/session_summary_card.dart';
import 'onboarding/onboarding_flow.dart';
import '../services/stats_calculator.dart';
import '../l10n/app_localizations.dart';
import '../services/feature_flag_service.dart';
import 'admin/partner_grants_screen.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';

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

  static const _bg = AppColors.bgPrimary;
  static const _surface = AppColors.bgSurface;
  static const _elevated = AppColors.bgElevated;
  static const _secondary = AppColors.contentInactive;
  static const _saveGreen = AppColors.accentSecondary;
  static const _danger = AppColors.accentDanger;
  static const _grey = AppColors.bgOverlay;

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
        // SECURITY (main audit H2): dev tools / premium override must never
        // be reachable in release, even for a role=='admin' user.
        _isAdmin = isAdmin && !kReleaseMode;
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
          _usernameError = available ? null : AppLocalizations.of(context).profileUsernameTaken;
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
      _showSnack(AppLocalizations.of(context).profileFixUsernameError);
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
          if (mounted) _showSnack(AppLocalizations.of(context).profileUsernameUnavailable);
          setState(() => _isSaving = false);
          return;
        }
        setState(() => _originalUsername = newUsername);
      }

      if (mounted) {
        _showSnack(AppLocalizations.of(context).profileSavedSuccessfully, isSuccess: true);
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to save: ${UserFacingError.message(e)}');
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AppTypography.ibm(color: Colors.white)),
      backgroundColor: isSuccess ? AppColors.bgElevated : AppColors.contentDisabled,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radiusMd)),
    ));
  }

  // ── Sign out / Delete ──────────────────────────────────────────────────────

  void _showSignOutConfirmation() {
    final l10n = AppLocalizations.of(context);
    // Guests lose access to their data permanently when signing out —
    // there is no credential to sign back in with
    final message = AuthService.isAnonymous
        ? l10n.anonSignOutWarning
        : l10n.profileSignOutConfirmation;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
        title: Text(l10n.profileSignOut, style: AppTypography.ibm(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(message,
            style: AppTypography.ibm(color: Colors.white, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel, style: AppTypography.ibm(color: _secondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Navigate to Intro FIRST so the logout registers on the first
              // tap, regardless of auth-stream timing. Awaiting signOut() before
              // navigating meant its auth-stream churn (worse for guests) could
              // trip AuthWrapper's "unexpected logout" recovery loading and leave
              // the user on the same screen. Removing AuthWrapper from the stack
              // here bypasses that; the sign-out clears the session in the
              // background.
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => IntroScreen()), (_) => false);
              try {
                await AuthService.signOut();
              } catch (_) {}
            },
            child: Text(l10n.profileSignOut, style: AppTypography.ibm(color: _danger, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final l10n = AppLocalizations.of(context);
    ConfirmDialog.show(
      context,
      title: l10n.profileDeleteAccount,
      message: l10n.profileDeleteAccountMessage,
      confirmLabel: l10n.commonDelete,
      onConfirm: _deleteAccount,
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
      if (mounted) _showSnack('Failed to delete account: ${UserFacingError.message(e)}');
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
            style: AppTypography.ibm(
                fontSize: size * 0.35, fontWeight: FontWeight.w600, color: AppColors.limeGreen)),
      ),
    );
  }

  // ── Guest upgrade card ─────────────────────────────────────────────────────

  Widget _buildGuestUpgradeCard(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () async {
        final linked = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AuthScreenExperimental(linkMode: true),
          ),
        );
        if (linked == true && mounted) {
          setState(() {});
          _showSnack(l10n.linkAccountSuccess, isSuccess: true);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tealPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: AppColors.tealPrimary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined,
                color: AppColors.tealPrimary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.linkAccountTitle,
                    style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.linkAccountBody,
                    style: AppTypography.ibm(
                      fontSize: 13,
                      color: _secondary,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.tealPrimary, size: 22),
          ],
        ),
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
            valueColor: AlwaysStoppedAnimation(AppColors.buttonPrimary))),
      );
    }

    final hPad = MediaQuery.of(context).size.width * 0.044;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          TopNavBar(
            title: l10n.profileSettings,
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
                          l10n.commonSave,
                          style: AppTypography.ibm(
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
                  // ── Guest upgrade card ──────────────────────────────────
                  if (AuthService.isAnonymous) ...[
                    _buildGuestUpgradeCard(l10n),
                    const SizedBox(height: 24),
                  ],

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
                                  borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
                                ),
                                child: Text(l10n.profileEdit,
                                    style: AppTypography.ibm(
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
                    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(AppDecorations.radiusLg)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.profileUseNicknameInGames,
                                  style: AppTypography.ibm(
                                      fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                'Show @${_usernameCtrl.text.replaceAll('@', '').isNotEmpty ? _usernameCtrl.text.replaceAll('@', '') : 'username'} ${l10n.profileInsteadOfName}',
                                style: AppTypography.ibm(fontSize: 13, color: _secondary, height: 20 / 13),
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
                    label: l10n.profileEditName,
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    placeholder: l10n.profileYourName,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: l10n.profileEditEmail,
                    controller: _emailCtrl,
                    placeholder: 'your@email.com',
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                    onTap: () => _showSnack(l10n.profileEditEmailHint),
                  ),
                  const SizedBox(height: 16),
                  _buildUsernameField(),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: l10n.profileChangePassword,
                    controller: TextEditingController(text: l10n.profilePasswordMask),
                    placeholder: l10n.profilePasswordMask,
                    readOnly: true,
                    onTap: _showChangePasswordSheet,
                  ),

                  const SizedBox(height: 32),

                  // ── List rows ───────────────────────────────────────────
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
                    icon: const Icon(Icons.email_outlined, color: AppColors.contentInactive, size: 24),
                    title: l10n.profileEmailUpdates,
                    trailing: _buildToggle(_emailUpdates, (v) => setState(() => _emailUpdates = v)),
                  ),
                  _buildRow(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.contentInactive, size: 24),
                    title: l10n.profileSignOut,
                    onTap: _showSignOutConfirmation,
                  ),
                  _buildRow(
                    title: l10n.profileDeleteAccount,
                    titleColor: _grey,
                    onTap: _showDeleteConfirmation,
                    showCaret: true,
                  ),

                  // ── Admin dev tools ─────────────────────────────────────
                  if (_isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildDevTools(),
                  ],

                  // ── Super-admin feature flags ───────────────────────────
                  // Available in release too: writes are enforced by
                  // Firestore rules (isSuperAdmin), not by this UI check.
                  if (FeatureFlagService.isSuperAdmin) ...[
                    const SizedBox(height: 24),
                    _buildFeatureFlags(),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PartnerGrantsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                          border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.handshake_outlined, color: AppColors.accentPrimary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'User Management',
                                style: AppTypography.ibm(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.contentInactive, size: 20),
                          ],
                        ),
                      ),
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
        ? AppColors.accentPrimary
        : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.ibm(fontSize: 13, fontWeight: FontWeight.w500, color: _secondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            style: AppTypography.ibm(
              fontSize: 15,
              color: readOnly ? _secondary : Colors.white,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: AppTypography.ibm(fontSize: 15, color: _secondary),
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
            ? AppColors.accentPrimary
            : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).profileEditUsername,
            style: AppTypography.ibm(fontSize: 13, fontWeight: FontWeight.w500, color: _secondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            style: AppTypography.ibm(fontSize: 15, color: Colors.white),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).profileUsernameHint,
              hintStyle: AppTypography.ibm(fontSize: 15, color: _secondary),
              prefixText: '@',
              prefixStyle: AppTypography.ibm(fontSize: 15, color: Colors.white),
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
                style: AppTypography.ibm(fontSize: 11, color: _danger)),
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
                  color: AppColors.bgPrimary,
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
    Widget? icon,
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
            if (icon != null) ...[
              SizedBox(width: 24, height: 24, child: icon),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(title,
                  style: AppTypography.ibm(
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

  // ── Change password sheet ──────────────────────────────────────────────────

  void _showChangePasswordSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppDecorations.radiusXl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.profileChangePasswordTitle,
                  style: AppTypography.ibm(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Text(l10n.profileChangePasswordMessage,
                  style: AppTypography.ibm(fontSize: 14, color: _secondary), textAlign: TextAlign.center),
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
                        if (mounted) _showSnack(l10n.profileResetEmailSent(email), isSuccess: true);
                      } catch (e) {
                        if (mounted) _showSnack(l10n.profileResetEmailFailed);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                        color: _elevated, borderRadius: BorderRadius.circular(AppDecorations.buttonRadius)),
                    child: Text(l10n.profileSendResetEmail,
                        textAlign: TextAlign.center,
                        style: AppTypography.ibm(
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

  // ── Super-admin feature flags ──────────────────────────────────────────────

  Widget _buildFeatureFlags() {
    return ValueListenableBuilder<int>(
      valueListenable: FeatureFlagService.revision,
      builder: (context, _, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
              color: AppColors.tealPrimary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.flag_outlined,
                  color: AppColors.tealPrimary, size: 20),
              const SizedBox(width: 8),
              Text('Feature Flags',
                  style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tealPrimary)),
            ]),
            const SizedBox(height: 4),
            Text(
                'Global — applies to all users immediately. '
                '"Only me" hides the feature for users but keeps it live '
                'for you (preview); "Off" hides it for everyone, you '
                'included.',
                style:
                    AppTypography.ibm(fontSize: 12, color: _secondary)),
            const SizedBox(height: 12),
            for (final flag in FeatureFlagService.all) ...[
              Text(flag.title,
                  style: AppTypography.ibm(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
              Text(flag.description,
                  style: AppTypography.ibm(
                      fontSize: 12, color: _secondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _flagModeChip(flag.key, FlagMode.on, 'On'),
                  const SizedBox(width: 8),
                  _flagModeChip(flag.key, FlagMode.adminOnly, 'Only me'),
                  const SizedBox(width: 8),
                  _flagModeChip(flag.key, FlagMode.off, 'Off'),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _flagModeChip(String flagKey, FlagMode mode, String label) {
    final selected = FeatureFlagService.modeOf(flagKey) == mode;
    final accent = switch (mode) {
      FlagMode.on => AppColors.tealPrimary,
      FlagMode.adminOnly => AppColors.warningAmber, // preview state
      FlagMode.off => AppColors.errorRed,
    };
    return Expanded(
      child: GestureDetector(
        onTap: selected
            ? null
            : () async {
                try {
                  await FeatureFlagService.setMode(flagKey, mode);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Flag update failed: ${UserFacingError.message(e)}')));
                  }
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
            border: Border.all(
                color: selected ? accent : AppColors.neutral700),
          ),
          child: Text(label,
              style: AppTypography.ibm(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? accent : _secondary)),
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
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bug_report, color: Color(0xFFFF6B6B), size: 20),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).profileDevTools, style: AppTypography.ibm(
                fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B6B))),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(context).profilePremiumOverride, style: AppTypography.ibm(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                Text(
                  override == null
                      ? 'Real: ${SubscriptionService.isPremium ? 'Premium' : 'Free'}'
                      : 'Overridden: ${override ? 'Premium' : 'Free'}',
                  style: AppTypography.ibm(fontSize: 12, color: _secondary),
                ),
              ]),
              Switch(
                value: SubscriptionService.isPremium,
                onChanged: (v) async { await SubscriptionService.setDebugPremiumOverride(v); setState(() {}); },
                activeColor: AppColors.tealPrimary,
                inactiveThumbColor: AppColors.textDisabled,
                inactiveTrackColor: AppColors.neutral700,
              ),
            ],
          ),
          if (override != null) ...[
            GestureDetector(
              onTap: () async { await SubscriptionService.setDebugPremiumOverride(null); setState(() {}); },
              child: Text('Reset to real', style: AppTypography.ibm(
                  fontSize: 13, color: AppColors.buttonPrimary,
                  decoration: TextDecoration.underline, decorationColor: AppColors.buttonPrimary)),
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
          _devButton('Open Latest Session Analytics', AppColors.warningAmber, _openLatestSession),
          const SizedBox(height: 8),
          _devButton('Diagnose Stats (Latest Session)', AppColors.warningAmber, _diagnoseStats),
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
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Center(
          child: Text(label, style: AppTypography.ibm(
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
      if (mounted) _showSnack(UserFacingError.message(e));
    }
  }

  Future<void> _diagnoseStats() async {
    final userId = AuthService.currentUser?.uid;
    if (userId == null) { _showSnack('Not logged in'); return; }

    _showSnack('Fetching latest session & stats...');
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Get latest session
      final sessSnap = await firestore
          .collection('poker_sessions')
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();
      if (sessSnap.docs.isEmpty) { _showSnack('No sessions found'); return; }
      final sessDoc = sessSnap.docs.first;
      final sess = sessDoc.data();
      final sessId = sessDoc.id;
      final heroSeat = sess['ourSeatNumber'] as int?;

      debugPrint('\n${'=' * 80}');
      debugPrint('STATS DIAGNOSTIC — Latest Session');
      debugPrint('${'=' * 80}');
      debugPrint('Session: ${sess['sessionName']} | ID: $sessId');
      debugPrint('Hero seat: $heroSeat | Game: ${sess['gameType']}');
      debugPrint('Blinds: ${sess['smallBlind']}/${sess['bigBlind']}');

      // 2. Get hands for this session
      final handsSnap = await firestore
          .collection('poker_sessions').doc(sessId)
          .collection('poker_hands')
          .orderBy('handNumber')
          .get();
      final hands = handsSnap.docs.map((d) => d.data()).toList();
      debugPrint('Hands in session: ${hands.length}\n');

      // 3. Recalculate ALL stats from these hands
      int calcTotalHands = 0, calcHandsPlayed = 0, calcWonHands = 0;
      int calcVpip = 0, calcPfr = 0, calcWalks = 0;
      int calc3Bet = 0, calc3BetOpp = 0;
      int calcFold3Bet = 0, calcFacing3Bet = 0;
      int calcCbet = 0, calcCbetOpp = 0;
      int calcSteal = 0, calcStealOpp = 0;
      int calcCRFlop = 0, calcCRFlopOpp = 0;

      for (final hand in hands) {
        calcTotalHands++;
        final actions = List<Map<String, dynamic>>.from(hand['actions'] ?? []);
        final winnerId = hand['winnerId'] as int?;
        final choppedWinners = (hand['choppedWinners'] as List?)?.cast<int>();
        final handNum = hand['handNumber'] ?? '?';

        if (heroSeat == null) continue;

        // Replicate _updateUserStatsFromHand logic exactly
        bool didPlay = false;
        bool didVpip = false;
        bool didPfr = false;
        bool didWin = false;

        if ((winnerId != null && winnerId == heroSeat) ||
            (choppedWinners?.contains(heroSeat) ?? false)) {
          didWin = true;
        }

        final heroActions = <String>[];
        for (final action in actions) {
          final pid = action['player'] as int?;
          final aType = action['action']?.toString().toLowerCase() ?? '';
          final street = action['street']?.toString().toLowerCase() ?? '';
          if (pid != heroSeat) continue;

          heroActions.add('$aType($street)');

          if (aType == 'call' || aType == 'bet' || aType == 'raise' ||
              aType == 'all-in' || aType == 'check') {
            didPlay = true;
          }

          if (street == 'preflop') {
            if (aType == 'bet' || aType == 'call' || aType == 'raise' || aType == 'all-in') {
              if (!StatsCalculator.isBlindAction(action)) {
                didVpip = true;
              }
              if (aType == 'bet' || aType == 'raise' || aType == 'all-in') {
                didPfr = true;
              }
            }
          }
        }

        final didThreeBet = didPlay ? StatsCalculator.didPlayerThreeBet(actions, heroSeat) : false;
        final isWalk = StatsCalculator.isWalkHand(actions);
        final isBBWalk = isWalk && StatsCalculator.isBigBlind(actions, heroSeat);
        final had3BetOpp = StatsCalculator.hadThreeBetOpportunity(actions, heroSeat);
        final foldedTo3Bet = StatsCalculator.didFoldTo3Bet(actions, heroSeat);
        final faced3Bet = StatsCalculator.facedThreeBet(actions, heroSeat);
        final hadCbetOpp = StatsCalculator.hadCbetOpportunity(actions, heroSeat);
        final didCbet = hadCbetOpp && StatsCalculator.didCbet(actions, heroSeat);
        final hadStealOpp = StatsCalculator.hadStealOpportunity(actions, heroSeat);
        final didSteal = hadStealOpp && StatsCalculator.didSteal(actions, heroSeat);
        final hadCROpp = StatsCalculator.hadCheckRaiseFlopOpportunity(actions, heroSeat);
        final didCR = hadCROpp && StatsCalculator.didCheckRaiseFlop(actions, heroSeat);

        // Get position from actions
        String pos = '?';
        for (final a in actions) {
          if (a['player'] == heroSeat && a['playerPosition'] != null) {
            pos = a['playerPosition'].toString();
            break;
          }
        }

        // Print hand detail
        final flags = <String>[];
        if (didVpip) flags.add('VPIP');
        if (didPfr) flags.add('PFR');
        if (didThreeBet) flags.add('3BET');
        if (isWalk) flags.add('WALK');
        if (isBBWalk) flags.add('BB-WALK');
        if (had3BetOpp) flags.add('3BET-OPP');
        if (foldedTo3Bet) flags.add('FOLD-3BET');
        if (faced3Bet) flags.add('FACED-3BET');
        if (hadCbetOpp) flags.add('CBET-OPP');
        if (didCbet) flags.add('CBET');
        if (hadStealOpp) flags.add('STEAL-OPP');
        if (didSteal) flags.add('STEAL');
        if (hadCROpp) flags.add('CR-OPP');
        if (didCR) flags.add('CR');
        if (didWin) flags.add('WON');

        debugPrint('  H#$handNum [$pos] hero=${heroActions.join(",")} → ${flags.join(" ")}');

        if (didPlay) calcHandsPlayed++;
        if (didVpip) calcVpip++;
        if (didPfr) calcPfr++;
        if (isBBWalk) calcWalks++;
        if (didThreeBet) calc3Bet++;
        if (had3BetOpp) calc3BetOpp++;
        if (foldedTo3Bet) calcFold3Bet++;
        if (faced3Bet) calcFacing3Bet++;
        if (didCbet) calcCbet++;
        if (hadCbetOpp) calcCbetOpp++;
        if (didSteal) calcSteal++;
        if (hadStealOpp) calcStealOpp++;
        if (didCR) calcCRFlop++;
        if (hadCROpp) calcCRFlopOpp++;
        if (didWin && didPlay) calcWonHands++;
      }

      // 4. Fetch current stored stats
      final statsDoc = await firestore.collection('user_stats').doc(userId).get();
      final db = statsDoc.data() ?? {};

      final eligible = calcTotalHands - calcWalks;

      debugPrint('\n${'=' * 80}');
      debugPrint('CALCULATED FROM HANDS (this session only):');
      debugPrint('${'=' * 80}');
      debugPrint('totalHands=$calcTotalHands  handsPlayed=$calcHandsPlayed  walks=$calcWalks');
      debugPrint('vpip=$calcVpip/${eligible > 0 ? eligible : "?"}=${eligible > 0 ? (calcVpip / eligible * 100).toStringAsFixed(1) : "?"}%');
      debugPrint('pfr=$calcPfr/${eligible > 0 ? eligible : "?"}=${eligible > 0 ? (calcPfr / eligible * 100).toStringAsFixed(1) : "?"}%');
      debugPrint('3bet=$calc3Bet/$calc3BetOpp  fold3bet=$calcFold3Bet/$calcFacing3Bet');
      debugPrint('cbet=$calcCbet/$calcCbetOpp  steal=$calcSteal/$calcStealOpp');
      debugPrint('crFlop=$calcCRFlop/$calcCRFlopOpp  wonHands=$calcWonHands');

      debugPrint('\n${'=' * 80}');
      debugPrint('DATABASE user_stats (cumulative, all sessions):');
      debugPrint('${'=' * 80}');
      final dbTotal = db['totalHands'] ?? 0;
      final dbWalks = db['walksCount'] ?? 0;
      final dbEligible = dbTotal - dbWalks;
      debugPrint('totalHands=${db['totalHands']}  handsPlayed=${db['handsPlayed']}  walks=${db['walksCount']}');
      debugPrint('vpip=${db['vpipCount']}/$dbEligible=${dbEligible > 0 ? ((db['vpipCount'] ?? 0) / dbEligible * 100).toStringAsFixed(1) : "?"}%');
      debugPrint('pfr=${db['pfrCount']}/$dbEligible=${dbEligible > 0 ? ((db['pfrCount'] ?? 0) / dbEligible * 100).toStringAsFixed(1) : "?"}%');
      debugPrint('3bet=${db['threeBetCount']}/${db['threeBetOpportunity']}  fold3bet=${db['fold3betCount']}/${db['facing3BetCount']}');
      debugPrint('cbet=${db['cbetCount']}/${db['cbetOpportunity']}  steal=${db['stealCount']}/${db['stealOpportunity']}');
      debugPrint('crFlop=${db['checkRaiseFlopCount']}/${db['checkRaiseFlopOpportunity']}  wonHands=${db['wonHands']}');
      debugPrint('${'=' * 80}\n');

      if (mounted) _showSnack('Stats diagnostic printed to console — check debug log');
    } catch (e) {
      debugPrint('Diagnostic error: $e');
      if (mounted) _showSnack(UserFacingError.message(e));
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
