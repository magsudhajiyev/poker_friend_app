import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/components/buttons/app_button.dart';
import '../design_system/components/sheets/app_sheet.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/spacing.dart';
import '../design_system/constants/typography.dart';
import '../l10n/app_localizations.dart';
import '../onboarding/onboarding_state.dart';
import '../services/auth_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/feature_flag_service.dart';
import '../services/notification_prefs_service.dart';
import '../services/paid_nudge_service.dart';
import '../services/subscription_service.dart';

/// One-time, explicit opt-in for offer pushes (trial recap, missed-day replay,
/// plan reminders) — Apple requires a clear consent and an opt-out (the opt-out
/// is the Settings toggle). Shown after a completed Daily Challenge, i.e. after
/// a positive moment, never during onboarding or the tour. Asked at most once:
/// dismissing without a choice leaves offers OFF and does not ask again.
class OffersConsentSheet {
  OffersConsentSheet._();

  static const _kPrompted = 'offers_consent_prompted';

  /// Pure: whether the prompt is due.
  static bool shouldPrompt({
    required bool flagOn,
    required bool signedIn,
    required bool alreadyDecided,
    required bool alreadyPrompted,
    required bool dayOverride,
    bool onboardingActive = false,
  }) =>
      flagOn &&
      signedIn &&
      !alreadyDecided &&
      !alreadyPrompted &&
      !dayOverride &&
      !onboardingActive;

  /// Entry point for a user held by the hard paywall (they can never finish
  /// a challenge, so the post-challenge prompt never reaches them). Shown
  /// once, shortly after the paywall first renders, and only while it is
  /// the visible route with no purchase/restore running and no onboarding
  /// or tour active; otherwise it is skipped (and retried on a later
  /// render, since nothing is marked as prompted). Uses the plan-reminder
  /// wording — the standard text mentions daily spots they cannot see.
  static Future<void> maybeShowOnPaywall(
    BuildContext context, {
    required bool Function() paywallIdle,
  }) =>
      maybeShow(
        context,
        delay: const Duration(seconds: 3),
        paywall: true,
        stillValid: () =>
            paywallIdle() &&
            !SubscriptionService.isPremium &&
            (ModalRoute.of(context)?.isCurrent ?? false),
        onAccepted: () => unawaited(PaidNudgeService.onPaywallOpened()),
      );

  /// Show the sheet after [delay] if due. [onAccepted] runs after the user
  /// opts in (e.g. to queue the nudge the just-finished run would have).
  /// [stillValid] is re-checked after the delay (false = skip, not marked).
  static Future<void> maybeShow(
    BuildContext context, {
    Duration delay = const Duration(seconds: 2),
    VoidCallback? onAccepted,
    bool paywall = false,
    bool Function()? stillValid,
  }) async {
    try {
      final prefs = await NotificationPrefsService.ensureLoaded();
      final sp = await SharedPreferences.getInstance();
      bool due() => shouldPrompt(
            flagOn: FeatureFlagService.isEnabled(FeatureFlagService.paidNudges),
            signedIn: AuthService.currentUser != null,
            alreadyDecided: prefs.offersConsentAt != null,
            alreadyPrompted: sp.getBool(_kPrompted) ?? false,
            dayOverride: DailyChallengeService.debugDayOffset != 0,
            onboardingActive: OnboardingState.isOnboardingActive,
          );
      if (!due()) return;
      await Future<void>.delayed(delay);
      if (!context.mounted) return;
      if (!due() || !(stillValid?.call() ?? true)) return;
      await sp.setBool(_kPrompted, true);
      final accepted = await AppSheet.show<bool>(
        context: context,
        heightFraction: null,
        scrollable: false,
        body: _ConsentBody(paywall: paywall),
      );
      if (accepted == null) return; // dismissed: stays OFF, not asked again
      await NotificationPrefsService.setOffers(accepted, source: 'prompt');
      unawaited(PaidNudgeService.onOffersChanged());
      if (accepted) onAccepted?.call();
    } catch (_) {
      // Consent UI must never break the results screen.
    }
  }
}

class _ConsentBody extends StatelessWidget {
  final bool paywall;
  const _ConsentBody({this.paywall = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.offersConsentTitle,
            style: AppTypography.ibm(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Text(paywall ? l10n.offersConsentBodyPaywall : l10n.offersConsentBody,
            style: AppTypography.ibm(
                fontSize: 15, color: AppColors.textDisabled, height: 22 / 15)),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.offersConsentAccept,
          fullWidth: true,
          onTap: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AppButton(
          label: l10n.offersConsentDecline,
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onTap: () => Navigator.pop(context, false),
        ),
      ],
    );
  }
}
