import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../screens/paywall_screen.dart';
import '../onboarding/onboarding_state.dart';
import 'subscription_service.dart';
import '../design_system/constants/decorations.dart';

/// Free-tier limits for the 4-tier subscription system.
///
/// Centralizes cap values and "show upgrade dialog" logic so gates across
/// different screens stay consistent.
class FreeTierLimits {
  FreeTierLimits._();

  // ---------------------------------------------------------------------------
  // Hand logging limits
  // ---------------------------------------------------------------------------

  /// Free tier: 10 hands per session.
  static const int maxHandsPerSessionFree = 10;

  /// Pro tier: 50 hands per session.
  static const int maxHandsPerSessionPro = 50;

  /// Guided tour is always capped at 5 hands regardless of plan.
  static const int maxHandsPerTour = 5;

  /// Computed cap for the current tier (used for display in subtitles).
  static int get maxHandsPerSession {
    if (SubscriptionService.isElite) return 999999; // unlimited
    if (SubscriptionService.isPro) return maxHandsPerSessionPro;
    return maxHandsPerSessionFree;
  }

  // ---------------------------------------------------------------------------
  // Opponent limits
  // ---------------------------------------------------------------------------

  /// Free tier: 5 opponent profiles.
  static const int maxOpponentProfilesFree = 5;

  /// Pro tier: 15 opponent profiles.
  static const int maxOpponentProfilesPro = 15;

  /// Computed cap for the current tier.
  static int get maxOpponentProfiles {
    if (SubscriptionService.isElite) return 999999; // unlimited
    if (SubscriptionService.isPro) return maxOpponentProfilesPro;
    return maxOpponentProfilesFree;
  }

  // ---------------------------------------------------------------------------
  // Session history window
  // ---------------------------------------------------------------------------

  /// Returns null (all time) for Elite/Club, or a cutoff DateTime for others.
  static DateTime? sessionHistoryCutoff() {
    if (SubscriptionService.isElite) return null; // all time
    if (SubscriptionService.isPro) {
      return DateTime.now().subtract(const Duration(days: 90));
    }
    return DateTime.now().subtract(const Duration(days: 30));
  }

  // ---------------------------------------------------------------------------
  // Gate checks
  // ---------------------------------------------------------------------------

  /// Returns true if the user can log another hand in the current session.
  static bool canLogAnotherHand(int completedHandsInSession) {
    // Tour has its own fixed cap — no upgrade dialog ever shown during tour
    if (OnboardingState.isOnboardingActive) {
      return completedHandsInSession < maxHandsPerTour;
    }
    if (SubscriptionService.isElite) return true; // unlimited
    if (SubscriptionService.isPro) {
      return completedHandsInSession < maxHandsPerSessionPro;
    }
    return completedHandsInSession < maxHandsPerSessionFree;
  }

  /// Returns true if the user can create another opponent profile.
  static bool canCreateAnotherOpponent(int currentOpponentCount) {
    if (SubscriptionService.isElite) return true; // unlimited
    if (SubscriptionService.isPro) {
      return currentOpponentCount < maxOpponentProfilesPro;
    }
    return currentOpponentCount < maxOpponentProfilesFree;
  }

  // ---------------------------------------------------------------------------
  // Upgrade dialogs
  // ---------------------------------------------------------------------------

  /// Show a styled explanation dialog for the "hands per session" limit.
  /// Tier-aware: message varies based on current tier.
  static Future<bool?> showHandsLimitDialog(
    BuildContext context, {
    String? dismissLabel,
  }) {
    final l10n = AppLocalizations.of(context);
    final String message = SubscriptionService.isPro
        ? l10n.freeTierHandLimitPro(maxHandsPerSessionPro)
        : l10n.freeTierHandLimitFree(maxHandsPerSessionFree, maxHandsPerSessionPro);

    return _showLimitDialog(
      context: context,
      title: l10n.freeTierHandLimitTitle,
      message: message,
      featureName: 'Unlimited hand logging',
      dismissLabel: dismissLabel ?? l10n.freeTierNotNow,
    );
  }

  /// Show a styled explanation dialog for the "opponent profiles" limit.
  static Future<bool?> showOpponentLimitDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String message = SubscriptionService.isPro
        ? l10n.freeTierOpponentLimitPro(maxOpponentProfilesPro)
        : l10n.freeTierOpponentLimitFree(maxOpponentProfilesFree, maxOpponentProfilesPro);

    return _showLimitDialog(
      context: context,
      title: l10n.freeTierOpponentLimitTitle,
      message: message,
      featureName: 'Unlimited opponent profiles',
    );
  }

  static Future<bool?> _showLimitDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String featureName,
    String? dismissLabel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final resolvedDismissLabel = dismissLabel ?? l10n.freeTierNotNow;
    // Show dialog and wait for user's choice.
    // barrierDismissible: false forces user to tap a button.
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.radius20),
            side: BorderSide(
              color: AppColors.whiteBorder(opacity: 0.12),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.buttonPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: AppColors.buttonPrimary,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.bodyLarge(
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  style: AppTypography.bodyMedium(
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
                SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop('dismiss');
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                            side: BorderSide(
                              color: AppColors.whiteBorder(opacity: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          resolvedDismissLabel,
                          style: AppTypography.bodyMedium(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogContext).pop('upgrade');
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                          ),
                          child: Center(
                            child: Text(
                              l10n.freeTierUpgrade,
                              style: AppTypography.buttonText().copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // Dialog is now fully closed. Sequence the paywall AFTER.
    if (result == 'upgrade') {
      await PaywallScreen.show(context, featureName: featureName);
      return true;
    }
    return false;
  }
}
