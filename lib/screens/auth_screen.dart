import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

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
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
      backgroundColor: Color(0xFF161618),
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
                    'assets/logo_chat.png',
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
                  color: Color(0xFF1F1F23),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF2A2A2E),
                            width: 1,
                          ),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Color(0xFF9A9A9A),
                        indicatorColor: Color(0xFFcb5242),
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
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixIcon: Icon(Icons.email, color: Color(0xFF9A9A9A)),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixIcon: Icon(Icons.lock, color: Color(0xFF9A9A9A)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
                    color: Color(0xFF9A9A9A),
                  ),
                  onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                ),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                backgroundColor: Color(0xFFcb5242),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                style: TextStyle(color: Color(0xFF9A9A9A)),
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
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixIcon: Icon(Icons.person, color: Color(0xFF9A9A9A)),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixIcon: Icon(Icons.email, color: Color(0xFF9A9A9A)),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixIcon: Icon(Icons.lock, color: Color(0xFF9A9A9A)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegisterPassword ? Icons.visibility : Icons.visibility_off,
                    color: Color(0xFF9A9A9A),
                  ),
                  onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
                ),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF9A9A9A)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: Color(0xFF9A9A9A),
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
                backgroundColor: Color(0xFFcb5242),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
        backgroundColor: Color(0xFF1F1F23),
        title: Text(
          l10n.authResetPassword,
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.authResetPasswordMessage,
              style: TextStyle(color: Color(0xFF9A9A9A)),
            ),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                labelStyle: TextStyle(color: Color(0xFF9A9A9A)),
                filled: true,
                fillColor: Color(0xFF2A2A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2A2A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFcb5242)),
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
              style: TextStyle(color: Color(0xFF9A9A9A)),
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
                      backgroundColor: Color(0xFFcb5242),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5AC95A),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.authSendResetLink),
          ),
        ],
      ),
    );
  }
}