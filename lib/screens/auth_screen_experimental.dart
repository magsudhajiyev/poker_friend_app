import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../design_system/components/buttons/glassy_icon_button.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'forgot_password_screen.dart';
import '../utils/user_facing_error.dart';
import '../design_system/components/modals/confirm_dialog.dart';

class AuthScreenExperimental extends StatefulWidget {
  final bool initialIsSignUp;

  /// When true, the sign-up form and social buttons LINK the current guest
  /// (anonymous) account to the chosen credential — keeping the same uid and
  /// all data — instead of creating/signing into a separate account. On
  /// success the screen pops with `true` so the caller can continue (e.g.
  /// the paywall's purchase flow).
  final bool linkMode;

  /// When false, the screen becomes a hard gate: system back is blocked, the
  /// back arrow and the sign-in/sign-up toggle links are hidden, so the only
  /// way out is a successful sign-up/link (or signing into a conflicting
  /// account). Used by the post-tour guest funnel where signing up is required.
  final bool canDismiss;

  const AuthScreenExperimental({
    Key? key,
    this.initialIsSignUp = true,
    this.linkMode = false,
    this.canDismiss = true,
  }) : super(key: key);

  @override
  _AuthScreenExperimentalState createState() => _AuthScreenExperimentalState();
}

class _AuthScreenExperimentalState extends State<AuthScreenExperimental> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();

  bool _isLoading = false;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  late bool _isSignUp; // Toggle between sign in and sign up

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerNameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signInWithEmail(
        _loginEmailController.text.trim(),
        _loginPasswordController.text,
      );

      if (mounted) {
        // Clear entire stack back to AuthWrapper, which will show HomeScreen
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.linkMode) {
        // Upgrade the guest account in place — same uid, data stays
        await AuthService.linkAnonymousWithEmail(
          _registerEmailController.text.trim(),
          _registerPasswordController.text,
          _registerNameController.text.trim(),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }

      await AuthService.registerWithEmail(
        _registerEmailController.text.trim(),
        _registerPasswordController.text,
        _registerNameController.text.trim(),
      );

      // Schedule onboarding reminder for 2 hours after registration
      NotificationService.scheduleOnboardingReminder();

      if (mounted) {
        // Clear entire stack back to AuthWrapper, which will show HomeScreen
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on AnonymousLinkConflictException {
      if (mounted) _showLinkConflictDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The credential already belongs to an existing account. Warn that the
  /// guest data won't transfer, then switch to the sign-in form.
  void _showLinkConflictDialog() {
    final l10n = AppLocalizations.of(context);
    ConfirmDialog.show(
      context,
      title: l10n.linkAccountConflictTitle,
      message: l10n.linkAccountConflictBody,
      confirmLabel: l10n.onboardingLogIn,
      confirmColor: Colors.black,
      onConfirm: () {
        if (mounted) setState(() => _isSignUp = false);
      },
    );
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _loginEmailController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Only LINK the guest from the sign-up form. On the sign-in form (e.g.
      // after a credential conflict switched us here) do a plain sign-in into
      // the existing account instead of re-attempting the link.
      if (widget.linkMode && _isSignUp) {
        final linked = await AuthService.linkAnonymousWithGoogle();
        if (linked != null && mounted) Navigator.pop(context, true);
        return;
      }

      final credential = await AuthService.signInWithGoogle();
      if (credential != null && mounted) {
        // Clear entire stack back to AuthWrapper, which will show HomeScreen
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on AnonymousLinkConflictException {
      if (mounted) _showLinkConflictDialog();
    } on GoogleSignInAccountLinkException catch (e) {
      if (mounted) _showAccountLinkDialog(e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAccountLinkDialog(GoogleSignInAccountLinkException e) {
    final passwordController = TextEditingController();
    bool isLinking = false;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
          title: Text(l10n.authExpLinkGoogleTitle,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.authExpLinkGoogleMessage(e.email),
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.authExpPassword,
                  labelStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: AppColors.whiteOverlay(opacity: 0.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel, style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isLinking
                  ? null
                  : () async {
                      setDialogState(() => isLinking = true);
                      try {
                        await AuthService.linkGoogleToExistingAccount(
                          email: e.email,
                          password: passwordController.text,
                          googleCredential: e.googleCredential,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          // Clear entire stack back to AuthWrapper, which will show HomeScreen
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        }
                      } catch (err) {
                        setDialogState(() => isLinking = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLinking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.authExpLinkAccount),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Only LINK the guest from the sign-up form; on the sign-in form do a
      // plain sign-in into the existing account (see _handleGoogleSignIn).
      if (widget.linkMode && _isSignUp) {
        final linked = await AuthService.linkAnonymousWithApple();
        if (linked != null && mounted) Navigator.pop(context, true);
        return;
      }

      final credential = await AuthService.signInWithApple();
      if (credential != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on AnonymousLinkConflictException {
      if (mounted) _showLinkConflictDialog();
    } on AppleSignInAccountLinkException catch (e) {
      if (mounted) _showAppleAccountLinkDialog(e);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAppleAccountLinkDialog(AppleSignInAccountLinkException e) {
    final passwordController = TextEditingController();
    bool isLinking = false;
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDecorations.radius20)),
          title: Text(l10n.authExpLinkAppleTitle,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.authExpLinkAppleMessage(e.email),
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.authExpPassword,
                  labelStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: AppColors.whiteOverlay(opacity: 0.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel, style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isLinking
                  ? null
                  : () async {
                      setDialogState(() => isLinking = true);
                      try {
                        await AuthService.linkAppleToExistingAccount(
                          email: e.email,
                          password: passwordController.text,
                          appleCredential: e.appleCredential,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        }
                      } catch (err) {
                        setDialogState(() => isLinking = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLinking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.authExpLinkAccount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialSignInSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.whiteOverlay(opacity: 0.24))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.authExpOr, style: AppTypography.bodySmall(color: Colors.white54)),
            ),
            Expanded(child: Divider(color: AppColors.whiteOverlay(opacity: 0.24))),
          ],
        ),
        const SizedBox(height: 20),
        // Apple Sign-In button — iOS only, shown above Google per Apple HIG
        if (defaultTargetPlatform == TargetPlatform.iOS) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _handleAppleSignIn,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.whiteOverlay(opacity: 0.30)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/icons/apple_logo.svg', height: 20, width: 20),
                  const SizedBox(width: 10),
                  Text(
                    l10n.authExpContinueApple,
                    style: AppTypography.buttonText(color: Colors.white).copyWith(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Google Sign-In button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.whiteOverlay(opacity: 0.30)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/icons/google_logo.svg', height: 20, width: 20),
                const SizedBox(width: 10),
                Text(
                  l10n.authExpContinueGoogle,
                  style: AppTypography.buttonText(color: Colors.white).copyWith(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canDismiss,
      child: Scaffold(
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
                      _isSignUp ? _buildSignUpForm() : _buildSignInForm(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back arrow (hidden when the screen is a hard gate)
        if (widget.canDismiss)
          GlassyIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
            size: 40,
            iconSize: 20,
          ),

        if (widget.canDismiss) const SizedBox(height: 24),

        // Title
        Text(
          _isSignUp ? AppLocalizations.of(context).authExpSignUpTitle : AppLocalizations.of(context).authExpLogInTitle,
          style: AppTypography.pageTitleLarge().copyWith(
            letterSpacing: -1,
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          _isSignUp
            ? AppLocalizations.of(context).authExpSignUpSubtitle
            : AppLocalizations.of(context).authExpLogInSubtitle,
          style: AppTypography.bodyMedium(
            color: Colors.white.withOpacity(0.70),
          ).copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _registerNameController,
            label: l10n.authExpName,
            showIcon: false,
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.authExpEnterName;
              if (value.length < 2) return l10n.authExpNameMinLength;
              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildInputField(
            controller: _registerEmailController,
            label: l10n.authExpEmail,
            keyboardType: TextInputType.emailAddress,
            showIcon: false,
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.authExpEnterEmail;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return l10n.authExpValidEmail;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildInputField(
            controller: _registerPasswordController,
            label: l10n.authExpPassword,
            obscureText: _obscureRegisterPassword,
            showIcon: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegisterPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.50),
              ),
              onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.authExpEnterPassword;
              if (value.length < 6) return l10n.authExpPasswordMinLength;
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Terms of Service
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTypography.bodySmall(
                  color: Colors.white.withOpacity(0.60),
                ).copyWith(fontSize: 13, height: 1.5),
                children: [
                  TextSpan(text: l10n.authExpBySigningUp),
                  TextSpan(
                    text: l10n.authExpTermsOfService,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      launchUrl(Uri.parse('https://www.finaltable.io/terms'));
                    },
                  ),
                  TextSpan(text: l10n.authExpAnd),
                  TextSpan(
                    text: l10n.authExpPrivacyPolicy,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      launchUrl(Uri.parse('https://www.finaltable.io/privacy'));
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Create Account Button
          _buildPrimaryButton(
            label: l10n.authExpCreateAccount,
            onPressed: _isLoading ? null : _register,
          ),

          const SizedBox(height: 20),

          // Already have an account? (hidden in hard-gate mode)
          if (widget.canDismiss)
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _isSignUp = false),
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.bodySmall(color: Colors.white.withOpacity(0.70)),
                    children: [
                      TextSpan(text: l10n.authExpAlreadyHaveAccount),
                      TextSpan(
                        text: l10n.authExpSignIn,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _buildSocialSignInSection(),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _loginEmailController,
            label: l10n.authExpEmail,
            keyboardType: TextInputType.emailAddress,
            showIcon: false,
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.authExpEnterEmail;
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return l10n.authExpValidEmail;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildInputField(
            controller: _loginPasswordController,
            label: l10n.authExpPassword,
            obscureText: _obscureLoginPassword,
            showIcon: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.50),
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return l10n.authExpEnterPassword;
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _handleForgotPassword,
              child: Text(
                l10n.authExpForgotPassword,
                style: AppTypography.bodySmall(
                  color: Colors.white.withOpacity(0.70),
                ).copyWith(
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sign In Button
          _buildPrimaryButton(
            label: l10n.authExpSignIn,
            onPressed: _isLoading ? null : _signIn,
          ),

          const SizedBox(height: 20),

          // Don't have an account? (hidden in hard-gate mode)
          if (widget.canDismiss)
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _isSignUp = true),
                child: RichText(
                  text: TextSpan(
                    style: AppTypography.bodySmall(color: Colors.white.withOpacity(0.70)),
                    children: [
                      TextSpan(text: l10n.authExpDontHaveAccount),
                      TextSpan(
                        text: l10n.authExpSignUp,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _buildSocialSignInSection(),
        ],
      ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool showIcon = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
          borderSide: BorderSide(
            color: AppColors.whiteOverlay(opacity: 0.20),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: BorderSide(
            color: AppColors.accentPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }
}
