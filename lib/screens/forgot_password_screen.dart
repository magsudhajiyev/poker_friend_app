import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../design_system/components/buttons/glassy_icon_button.dart';
import '../services/password_reset_service.dart';

enum _Phase { email, code, password }

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({Key? key, this.initialEmail}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Phase _phase = _Phase.email;
  bool _isLoading = false;

  // Phase 1 — Email
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // Phase 2 — Code
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  // Phase 3 — Password
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final n in _codeFocusNodes) {
      n.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  String get _enteredCode =>
      _codeControllers.map((c) => c.text).join();

  void _clearCode() {
    for (final c in _codeControllers) {
      c.clear();
    }
    _codeFocusNodes[0].requestFocus();
  }

  // ==================== Actions ====================

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final success = await PasswordResetService.sendResetCode(
        _emailController.text.trim(),
      );
      if (!success) {
        _showError('Failed to send code. Please try again.');
        return;
      }
      if (mounted) {
        setState(() {
          _phase = _Phase.code;
        });
        _startCountdown();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _codeFocusNodes[0].requestFocus();
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    setState(() => _isLoading = true);
    try {
      final success = await PasswordResetService.sendResetCode(
        _emailController.text.trim(),
      );
      if (success) {
        _clearCode();
        _startCountdown();
        _showSuccess('New code sent to your email.');
      } else {
        _showError('Failed to resend code.');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _enteredCode;
    if (code.length != 6) {
      _showError('Please enter the full 6-digit code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final valid = await PasswordResetService.verifyCode(
        _emailController.text.trim(),
        code,
      );
      if (!valid) {
        _showError('Invalid or expired code. Please try again.');
        _clearCode();
        return;
      }
      if (mounted) {
        setState(() => _phase = _Phase.password);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await PasswordResetService.resetPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        _showSuccess('Password reset successfully! Please sign in.');
        Navigator.pop(context); // Back to auth screen
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
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
      backgroundColor: AppColors.backgroundPaper,
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
                    if (_phase == _Phase.code) _buildCodePhase(),
                    if (_phase == _Phase.password) _buildPasswordPhase(),
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
    String title;
    String subtitle;
    switch (_phase) {
      case _Phase.email:
        title = 'Reset password';
        subtitle = 'Enter your email to receive a verification code';
        break;
      case _Phase.code:
        title = 'Check your email';
        subtitle = 'Enter the 6-digit code sent to ${_emailController.text.trim()}';
        break;
      case _Phase.password:
        title = 'Set new password';
        subtitle = 'Choose a strong password for your account';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassyIconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            if (_phase == _Phase.email) {
              Navigator.pop(context);
            } else if (_phase == _Phase.code) {
              setState(() => _phase = _Phase.email);
              _countdownTimer?.cancel();
            } else {
              setState(() => _phase = _Phase.code);
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
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Send Code',
            onPressed: _isLoading ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  // ==================== Phase 2: Code ====================

  Widget _buildCodePhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 6 digit input boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _buildCodeBox(i)),
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: 'Verify Code',
          onPressed: _isLoading ? null : _verifyCode,
        ),
        const SizedBox(height: 24),
        // Resend / countdown
        Center(
          child: _canResend
              ? GestureDetector(
                  onTap: _isLoading ? null : _resendCode,
                  child: Text(
                    'Resend code',
                    style: AppTypography.bodySmall(color: Colors.white).copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  'Resend code in 0:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: AppTypography.bodySmall(
                    color: Colors.white.withOpacity(0.50),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _codeControllers[index],
        focusNode: _codeFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.robotoMono(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.whiteOverlay(opacity: 0.10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
            borderSide: BorderSide(color: AppColors.whiteOverlay(opacity: 0.20)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
            borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _codeFocusNodes[index + 1].requestFocus();
          }
          // Auto-submit when all 6 digits entered
          if (index == 5 && value.isNotEmpty && _enteredCode.length == 6) {
            _verifyCode();
          }
        },
      ),
    );
  }

  // ==================== Phase 3: Password ====================

  Widget _buildPasswordPhase() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _passwordController,
            label: 'New password',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.50),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _confirmPasswordController,
            label: 'Confirm password',
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.50),
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Reset Password',
            onPressed: _isLoading ? null : _resetPassword,
          ),
        ],
      ),
    );
  }

  // ==================== Shared Widgets ====================

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
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
          borderSide: BorderSide(color: AppColors.whiteOverlay(opacity: 0.20), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDecorations.cardRadius),
          borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
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
          foregroundColor: AppColors.backgroundPaper,
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
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.backgroundPaper),
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
