import 'dart:async';
import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/decorations.dart';
import '../design_system/constants/typography.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/username_service.dart';
import '../services/display_identity_service.dart';

class UsernameSetupScreen extends StatefulWidget {
  /// If true, user is changing an existing username (from profile).
  /// If false, this is the post-registration setup flow.
  final bool isChanging;
  final String? currentUsername;

  /// Pre-fill from a web reservation (nickname_claims).
  final String? reservedUsername;

  /// Opened from the Daily Challenge leaderboard submit (username missing).
  /// Shows an info note that a username is required for the leaderboard and
  /// that skipping falls back to the player's real name, and makes Skip RETURN
  /// an empty string (caller submits with the display name) instead of routing
  /// to the app root.
  final bool leaderboardContext;

  const UsernameSetupScreen({
    Key? key,
    this.isChanging = false,
    this.currentUsername,
    this.reservedUsername,
    this.leaderboardContext = false,
  }) : super(key: key);

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Timer? _debounce;
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _hasChecked = false;
  bool _isClaiming = false;
  String? _availabilityError;

  @override
  void initState() {
    super.initState();
    if (widget.currentUsername != null) {
      _controller.text = widget.currentUsername!;
    } else if (widget.reservedUsername != null) {
      _controller.text = widget.reservedUsername!;
      // Trigger availability check after frame builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onUsernameChanged(widget.reservedUsername!);
      });
    }
  }

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

    // Skip check if it's the same as current username (compare lowercase)
    if (widget.isChanging &&
        widget.currentUsername != null &&
        lowercase == widget.currentUsername!.toLowerCase()) {
      setState(() {
        _hasChecked = false;
        _isAvailable = false;
        _isChecking = false;
        _availabilityError = AppLocalizations.of(context).usernameSetupCurrentUsername;
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
            _availabilityError = available ? null : AppLocalizations.of(context).usernameSetupAlreadyTaken;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _hasChecked = false;
            _availabilityError = AppLocalizations.of(context).usernameSetupCouldNotCheck;
          });
        }
      }
    });
  }

  Future<void> _claimUsername() async {
    final raw = _controller.text.trim();
    final error = UsernameService.validateUsername(raw);
    if (error != null) return;
    // Capitalize first letter for display (uniqueness check is case-insensitive)
    final original = raw[0].toUpperCase() + raw.substring(1);

    setState(() => _isClaiming = true);

    bool success;
    if (widget.isChanging && widget.currentUsername != null) {
      success = await UsernameService.releaseAndClaimNew(
        widget.currentUsername!,
        original,
      );
    } else {
      success = await UsernameService.claimUsername(original);
    }

    if (!mounted) return;

    if (success) {
      DisplayIdentityService.clearCache();
      if (widget.isChanging) {
        Navigator.pop(context, original);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else {
      setState(() {
        _isClaiming = false;
        _isAvailable = false;
        _hasChecked = true;
        _availabilityError = AppLocalizations.of(context).usernameSetupJustTaken;
      });
    }
  }

  Future<void> _skipUsername() async {
    await UsernameService.skipUsername();
    if (!mounted) return;
    if (widget.leaderboardContext) {
      // Return '' = "skipped": the caller submits with the display name.
      Navigator.pop(context, '');
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    if (widget.isChanging)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.arrow_back_ios,
                              color: Colors.white.withOpacity(0.7), size: 22),
                        ),
                      ),
                    Text(
                      widget.isChanging
                          ? AppLocalizations.of(context).usernameSetupChangeTitle
                          : AppLocalizations.of(context).usernameSetupChooseTitle,
                      style: AppTypography.pageTitleLarge(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).usernameSetupSubtitle,
                      style: AppTypography.bodyMedium()
                          .copyWith(color: Colors.white.withOpacity(0.60)),
                    ),
                    const SizedBox(height: 40),

                    // Username input
                    TextFormField(
                      controller: _controller,
                      onChanged: _onUsernameChanged,
                      style: AppTypography.bodyMedium().copyWith(fontSize: 16),
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).usernameSetupLabel,
                        labelStyle: TextStyle(
                          color: Colors.white.withOpacity(0.50),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 4),
                          child: Text(
                            '@',
                            style: AppTypography.bodyMedium().copyWith(
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
                        fillColor: AppColors.whiteOverlay(opacity: 0.10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDecorations.cardRadius),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDecorations.cardRadius),
                          borderSide: BorderSide(
                            color: AppColors.whiteOverlay(opacity: 0.20),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppDecorations.cardRadius),
                          borderSide: BorderSide(
                            color: _hasChecked && _isAvailable
                                ? AppColors.accentPrimary
                                : _hasChecked && !_isAvailable
                                    ? Colors.red
                                    : AppColors.accentPrimary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(context).usernameSetupRequired;
                        }
                        return UsernameService.validateUsername(
                            value.toLowerCase().trim());
                      },
                    ),

                    const SizedBox(height: 8),

                    // Availability status
                    _buildAvailabilityStatus(),

                    const SizedBox(height: 8),

                    // Rules hint
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        AppLocalizations.of(context).usernameSetupRulesHint,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Claim button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _canClaim ? _claimUsername : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.bgPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDecorations.buttonRadius),
                          ),
                          elevation: 0,
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.50),
                        ),
                        child: _isClaiming
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.bgPrimary),
                                ),
                              )
                            : Text(
                                widget.isChanging
                                    ? AppLocalizations.of(context).usernameSetupUpdateButton
                                    : AppLocalizations.of(context).usernameSetupClaimButton,
                                style: AppTypography.buttonText()
                                    .copyWith(fontSize: 16),
                              ),
                      ),
                    ),

                    // Leaderboard context: a note that a username is required
                    // for the leaderboard, and that skipping falls back to the
                    // player's real name.
                    if (widget.leaderboardContext) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.leaderboard_outlined,
                                size: 18, color: AppColors.accentPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)
                                    .usernameLeaderboardNote,
                                style: AppTypography.ibm(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: Colors.white.withOpacity(0.70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Skip button (initial setup, or the leaderboard prompt).
                    if (!widget.isChanging || widget.leaderboardContext) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _isClaiming ? null : _skipUsername,
                          child: Text(
                            widget.leaderboardContext
                                ? AppLocalizations.of(context)
                                    .usernameLeaderboardSkip
                                : AppLocalizations.of(context).usernameSetupSkip,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.50),
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.50),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
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
        child: Icon(Icons.cancel, color: Colors.red, size: 20),
      );
    }
    return null;
  }

  Widget _buildAvailabilityStatus() {
    if (_isChecking) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          AppLocalizations.of(context).usernameSetupCheckingAvailability,
          style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 13),
        ),
      );
    }
    if (_hasChecked && _isAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          AppLocalizations.of(context).usernameSetupAvailable,
          style: TextStyle(color: AppColors.accentPrimary, fontSize: 13),
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
}
