import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/username_service.dart';
import '../../services/display_identity_service.dart';

class NicknameStep extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  const NicknameStep({super.key, required this.onContinue, this.onBack});

  @override
  State<NicknameStep> createState() => _NicknameStepState();
}

class _NicknameStepState extends State<NicknameStep>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _hasChecked = false;
  bool _isClaiming = false;
  String? _availabilityError;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();

    final trimmed = value.trim();
    final lowercase = trimmed.toLowerCase();
    final error = UsernameService.validateUsername(trimmed);

    if (error != null || trimmed.isEmpty) {
      setState(() {
        _hasChecked = false;
        _isAvailable = false;
        _isChecking = false;
        _availabilityError = null;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _hasChecked = false;
      _availabilityError = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await UsernameService.isUsernameAvailable(
          lowercase,
          currentUserEmail: AuthService.currentUser?.email,
        );
        if (mounted && _controller.text.trim().toLowerCase() == lowercase) {
          setState(() {
            _isChecking = false;
            _hasChecked = true;
            _isAvailable = available;
            _availabilityError = available
                ? null
                : AppLocalizations.of(context).usernameSetupAlreadyTaken;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _hasChecked = false;
            _availabilityError =
                AppLocalizations.of(context).usernameSetupCouldNotCheck;
          });
        }
      }
    });
  }

  Future<void> _claimUsername() async {
    final raw = _controller.text.trim();
    final error = UsernameService.validateUsername(raw);
    if (error != null) return;
    final original = raw[0].toUpperCase() + raw.substring(1);

    setState(() => _isClaiming = true);

    final success = await UsernameService.claimUsername(original);

    if (!mounted) return;

    if (success) {
      DisplayIdentityService.clearCache();
      widget.onContinue();
    } else {
      setState(() {
        _isClaiming = false;
        _isAvailable = false;
        _hasChecked = true;
        _availabilityError =
            AppLocalizations.of(context).usernameSetupJustTaken;
      });
    }
  }

  Future<void> _skip() async {
    await UsernameService.skipUsername();
    if (mounted) {
      widget.onContinue();
    }
  }

  bool get _canClaim {
    final normalized = _controller.text.toLowerCase().trim();
    return !_isClaiming &&
        !_isChecking &&
        _hasChecked &&
        _isAvailable &&
        UsernameService.validateUsername(normalized) == null;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Stack(
      children: [
        const GradientBackground(),
        Positioned.fill(
          child: Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/main_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (widget.onBack != null)
                        _buildBackChevron(widget.onBack!),
                      const SizedBox(height: 16),
                      Text(
                        l10n.onboardingNicknameTitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.onboardingNicknameSubtitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8C8C8C),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Username input
                      TextFormField(
                        controller: _controller,
                        onChanged: _onUsernameChanged,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: l10n.usernameSetupLabel,
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, right: 4),
                            child: Text(
                              '@',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 18,
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          suffixIcon: _buildSuffixIcon(),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _hasChecked && !_isAvailable
                                  ? Colors.red
                                  : AppColors.accentGreen,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAvailabilityStatus(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          l10n.usernameSetupRulesHint,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  (bottomPadding > 0 ? bottomPadding + 16 : 40) +
                      viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _canClaim ? _claimUsername : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.backgroundPaper,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(110),
                          ),
                          elevation: 0,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.5),
                        ),
                        child: _isClaiming
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.backgroundPaper),
                                ),
                              )
                            : Text(
                                l10n.usernameSetupClaimButton,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.backgroundPaper,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isClaiming ? null : _skip,
                      child: Text(
                        l10n.onboardingSkipNickname,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isChecking) {
      return const UnconstrainedBox(
        child: Padding(
          padding: EdgeInsets.only(right: 12),
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
      );
    }
    if (_hasChecked && _isAvailable) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.check_circle, color: AppColors.accentGreen, size: 20),
      );
    }
    if (_hasChecked && !_isAvailable) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.cancel, color: Colors.red, size: 20),
      );
    }
    return null;
  }

  Widget _buildAvailabilityStatus() {
    final l10n = AppLocalizations.of(context);
    if (_isChecking) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          l10n.usernameSetupCheckingAvailability,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        ),
      );
    }
    if (_hasChecked && _isAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          l10n.usernameSetupAvailable,
          style: const TextStyle(color: AppColors.accentGreen, fontSize: 13),
        ),
      );
    }
    if (_availabilityError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          _availabilityError!,
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBackChevron(VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
