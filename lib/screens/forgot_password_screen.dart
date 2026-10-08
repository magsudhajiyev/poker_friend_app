import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../design_system/components/buttons/glassy_icon_button.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../utils/user_facing_error.dart';

/// Password reset via Firebase's built-in email link.
///
/// Replaces the custom `password_reset_codes` Firestore flow (audit B9):
/// that collection is denied by rules since the launch-night hardening, so
/// the old screen could never send a code — and its reset step required a
/// matching GOOGLE account to change an email/password account. The
/// built-in `sendPasswordResetEmail` link needs no Firestore, no Resend
/// and no re-authentication.
enum _Phase { email, sent }

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({Key? key, this.initialEmail}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Phase _phase = _Phase.email;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // Resend cooldown so the button can't be hammered.
  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _canResend = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  // ==================== Actions ====================

  Future<void> _sendLink() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.sendPasswordReset(_emailController.text.trim());
      if (mounted) {
        setState(() => _phase = _Phase.sent);
        _startCountdown();
      }
    } catch (e) {
      _showError(UserFacingError.message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendLink() async {
    if (!_canResend) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.sendPasswordReset(_emailController.text.trim());
      if (mounted) {
        _startCountdown();
        _showSuccess(AppLocalizations.of(context).forgotPasswordLinkSent);
      }
    } catch (e) {
      _showError(UserFacingError.message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    if (_phase == _Phase.email) _buildEmailPhase(),
                    if (_phase == _Phase.sent) _buildSentPhase(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final title = _phase == _Phase.email
        ? l10n.forgotPasswordResetTitle
        : l10n.forgotPasswordCheckEmail;
    final subtitle = _phase == _Phase.email
        ? l10n.forgotPasswordResetSubtitle
        : l10n.forgotPasswordLinkSubtitle(_emailController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassyIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (_phase == _Phase.email) {
              Navigator.pop(context);
            } else {
              setState(() => _phase = _Phase.email);
              _countdownTimer?.cancel();
            }
          },
          size: 40,
          iconSize: 20,
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: AppTypography.pageTitleLarge().copyWith(
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTypography.bodyMedium(
            color: Colors.white.withOpacity(0.70),
          ).copyWith(fontSize: 16),
        ),
      ],
    );
  }

  // ==================== Phase 1: Email ====================

  Widget _buildEmailPhase() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _emailController,
            label: l10n.forgotPasswordEmail,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.forgotPasswordEnterEmail;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return l10n.forgotPasswordValidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: l10n.forgotPasswordSendLink,
            onPressed: _isLoading ? null : _sendLink,
          ),
        ],
      ),
    );
  }

  // ==================== Phase 2: Link sent ====================

  Widget _buildSentPhase() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.whiteOverlay(opacity: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.whiteOverlay(opacity: 0.20),
              ),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: AppColors.accentPrimary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: l10n.forgotPasswordBackToSignIn,
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        const SizedBox(height: 24),
        Center(
          child: _canResend
              ? GestureDetector(
                  onTap: _isLoading ? null : _resendLink,
                  child: Text(
                    l10n.forgotPasswordResendLink,
                    style: AppTypography.bodySmall(color: Colors.white).copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  l10n.forgotPasswordResendIn('0:${_secondsRemaining.toString().padLeft(2, '0')}'),
                  style: AppTypography.bodySmall(
                    color: Colors.white.withOpacity(0.50),
                  ),
                ),
        ),
      ],
    );
  }

  // ==================== Shared Widgets ====================

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTypography.bodyMedium().copyWith(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.50),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: AppColors.whiteOverlay(opacity: 0.10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: BorderSide(color: AppColors.whiteOverlay(opacity: 0.20), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: BorderSide(color: AppColors.accentPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.bgPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.white.withOpacity(0.50),
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.bgPrimary),
                ),
              )
            : Text(
                label,
                style: AppTypography.buttonText().copyWith(fontSize: 16),
              ),
      ),
    );
  }
}
