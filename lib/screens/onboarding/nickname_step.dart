import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/username_service.dart';
import '../../services/display_identity_service.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import 'onboarding_scaffold.dart';

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

    return OnboardingScaffold(
      currentStep: 2,
      onBack: widget.onBack,
      onContinue: _canClaim ? _claimUsername : null,
      continueLabel: l10n.usernameSetupClaimButton,
      secondaryAction: GestureDetector(
        onTap: _isClaiming ? null : _skip,
        child: Text(
          l10n.onboardingSkipNickname,
          style: AppTypography.ibm(
            fontSize: 15,
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textSecondary,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingNicknameTitle,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -2.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingNicknameSubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
              letterSpacing: -0.85,
            ),
          ),
          const SizedBox(height: 40),
          // Username input
          TextFormField(
            controller: _controller,
            onChanged: _onUsernameChanged,
            style: AppTypography.ibm(
              fontSize: 16,
              color: Colors.white,
            ),
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.usernameSetupLabel,
              labelStyle: AppTypography.ibm(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Text(
                  '@',
                  style: AppTypography.ibm(
                    fontSize: 18,
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: _buildSuffixIcon(),
              filled: true,
              fillColor: AppColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(
                  color: AppColors.borderStrong,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: BorderSide(
                  color: _hasChecked && !_isAvailable
                      ? AppColors.accentDanger
                      : AppColors.accentPrimary,
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
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    if (_hasChecked && _isAvailable) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.check_circle, color: AppColors.accentPrimary, size: 20),
      );
    }
    if (_hasChecked && !_isAvailable) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(Icons.cancel, color: AppColors.accentDanger, size: 20),
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
          style: AppTypography.ibm(
              color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }
    if (_hasChecked && _isAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          l10n.usernameSetupAvailable,
          style: AppTypography.ibm(
              color: AppColors.accentPrimary, fontSize: 13),
        ),
      );
    }
    if (_availabilityError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          _availabilityError!,
          style: AppTypography.ibm(
              color: AppColors.accentDanger, fontSize: 13),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
