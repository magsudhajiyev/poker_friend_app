import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/main_shell.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  
  // Controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerNameController.dispose();
    _confirmPasswordController.dispose();
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainShell()),
        );
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
      await AuthService.registerWithEmail(
        _registerEmailController.text.trim(),
        _registerPasswordController.text,
        _registerNameController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainShell()),
        );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant1,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            Padding(
              padding: EdgeInsets.fromLTRB(32, 60, 32, 40),
              child: Column(
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                  ),
                  SizedBox(height: 24),
                  Text(
                    l10n.authWelcome,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Auth Form
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant2,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppDecorations.radiusXl),
                    topRight: Radius.circular(AppDecorations.radiusXl),
                  ),
                ),
                child: Column(
                  children: [
                    // Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.surfaceVariant3,
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textMuted,
                        indicatorColor: AppColors.errorRedVariant,
                        indicatorWeight: 3,
                        labelStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(text: l10n.authSignIn),
                          Tab(text: l10n.authRegister),
                        ],
                      ),
                    ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSignInForm(),
                          _buildRegisterForm(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),

            TextFormField(
              controller: _loginEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.email, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.authPleaseEnterEmail;
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return l10n.authPleaseEnterValidEmail;
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            TextFormField(
              controller: _loginPasswordController,
              obscureText: _obscureLoginPassword,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authPassword,
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.lock, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.authPleaseEnterPassword;
                }
                return null;
              },
            ),

            SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRedVariant,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                ),
                disabledBackgroundColor: Colors.grey[600],
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.authSignIn,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),

            SizedBox(height: 16),

            TextButton(
              onPressed: () => _showForgotPasswordDialog(),
              child: Text(
                l10n.authForgotPassword,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),

            TextFormField(
              controller: _registerNameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authDisplayName,
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.person, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.authPleaseEnterName;
                }
                if (value.length < 2) {
                  return l10n.authNameMinLength;
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            TextFormField(
              controller: _registerEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.email, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.authPleaseEnterEmail;
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return l10n.authPleaseEnterValidEmail;
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            TextFormField(
              controller: _registerPasswordController,
              obscureText: _obscureRegisterPassword,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authPassword,
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.lock, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegisterPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.authPleaseEnterAPassword;
                }
                if (value.length < 6) {
                  return l10n.authPasswordMinLength;
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authConfirmPassword,
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.authPleaseConfirmPassword;
                }
                if (value != _registerPasswordController.text) {
                  return l10n.authPasswordsDoNotMatch;
                }
                return null;
              },
            ),

            SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRedVariant,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                ),
                disabledBackgroundColor: Colors.grey[600],
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.authCreateAccount,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceVariant2,
        title: Text(
          l10n.authResetPassword,
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.authResetPasswordMessage,
              style: TextStyle(color: AppColors.textMuted),
            ),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceVariant3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.surfaceVariant3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  borderSide: BorderSide(color: AppColors.errorRedVariant),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                try {
                  await AuthService.sendPasswordReset(emailController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.authPasswordResetSent),
                      backgroundColor: AppColors.errorRedVariant,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(UserFacingError.message(e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.profitGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.authSendResetLink),
          ),
        ],
      ),
    );
  }
}