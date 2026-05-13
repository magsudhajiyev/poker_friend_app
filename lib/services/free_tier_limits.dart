import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../screens/paywall_screen.dart';
import 'subscription_service.dart';

/// Free-tier limits for the v1 launch.
///
/// Centralizes the cap values and the "show the upgrade dialog" logic so
/// the gates in different screens stay consistent.
class FreeTierLimits {
  FreeTierLimits._();

  /// Maximum number of hands a free user can log per session.
  /// TODO(v1-launch): Set back to 5 once subscriptions are wired up.
  static const int maxHandsPerSession = 999;

  /// Maximum number of saved opponent profiles for a free user.
  static const int maxOpponentProfiles = 10;

  /// Returns true if the user can log more hands in the current session.
  /// Premium users always return true.
  static bool canLogAnotherHand(int completedHandsInSession) {
    if (SubscriptionService.isPremium) return true;
    return completedHandsInSession < maxHandsPerSession;
  }

  /// Returns true if the user can create another opponent profile.
  /// Premium users always return true.
  static bool canCreateAnotherOpponent(int currentOpponentCount) {
    if (SubscriptionService.isPremium) return true;
    return currentOpponentCount < maxOpponentProfiles;
  }

  /// Show a styled explanation dialog for the "hands per session" limit,
  /// with an Upgrade button that routes to the paywall. Resolves to `true`
  /// if the user tapped Upgrade, `false` (or null) if they dismissed.
  static Future<bool?> showHandsLimitDialog(
    BuildContext context, {
    String dismissLabel = 'Not now',
  }) {
    return _showLimitDialog(
      context: context,
      title: 'Hand limit reached',
      message:
          'Free accounts can log up to $maxHandsPerSession hands per session. '
          'Upgrade to Pro to log unlimited hands and keep your full history.',
      featureName: 'Unlimited hand logging',
      dismissLabel: dismissLabel,
    );
  }

  /// Show a styled explanation dialog for the "opponent profiles" limit.
  static Future<bool?> showOpponentLimitDialog(BuildContext context) {
    return _showLimitDialog(
      context: context,
      title: 'Opponent limit reached',
      message:
          'Free accounts can save up to $maxOpponentProfiles opponent profiles. '
          'Upgrade to Pro to track as many opponents as you like.',
      featureName: 'Unlimited opponent profiles',
    );
  }

  static Future<bool?> _showLimitDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String featureName,
    String dismissLabel = 'Not now',
  }) async {
    // Show dialog and wait for user's choice.
    // barrierDismissible: false forces user to tap a button.
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.backgroundSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                        borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(60),
                            side: BorderSide(
                              color: AppColors.whiteBorder(opacity: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          dismissLabel,
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
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: Center(
                            child: Text(
                              'Upgrade',
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
