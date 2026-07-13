import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../models/currency.dart';
import 'onboarding_scaffold.dart';

/// Onboarding step: pick the currency all money amounts are shown in.
/// The device locale pre-selects a sensible default, so a single tap on
/// Continue is enough for most users.
class CurrencyStep extends StatefulWidget {
  final ValueChanged<String> onContinue;
  final VoidCallback? onBack;

  const CurrencyStep({super.key, required this.onContinue, this.onBack});

  @override
  State<CurrencyStep> createState() => _CurrencyStepState();
}

class _CurrencyStepState extends State<CurrencyStep>
    with AutomaticKeepAliveClientMixin {
  late String _selected;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selected = _defaultForLocale();
  }

  /// Best-guess currency from the device locale's country code.
  static String _defaultForLocale() {
    const euro = {
      'DE', 'FR', 'ES', 'IT', 'NL', 'PT', 'IE', 'AT', 'BE', 'FI', 'GR',
      'SK', 'SI', 'LV', 'LT', 'EE', 'LU', 'MT', 'CY', 'HR',
    };
    const byCountry = {
      'US': 'USD', 'GB': 'GBP', 'CA': 'CAD', 'AU': 'AUD', 'BR': 'BRL',
      'PL': 'PLN', 'RU': 'RUB', 'IN': 'INR', 'JP': 'JPY', 'CN': 'CNY',
      'KR': 'KRW', 'SE': 'SEK', 'MX': 'MXN', 'TR': 'TRY', 'CZ': 'CZK',
      'NO': 'NOK', 'DK': 'DKK', 'CH': 'CHF', 'IL': 'ILS', 'UA': 'UAH',
      'AR': 'ARS',
    };
    final country =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (country == null) return 'USD';
    if (euro.contains(country)) return 'EUR';
    return byCountry[country] ?? 'USD';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      currentStep: 3,
      onBack: widget.onBack,
      onContinue: () => widget.onContinue(_selected),
      continueLabel: l10n.onboardingContinue,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            l10n.onboardingCurrencyTitle,
            textAlign: TextAlign.left,
            style: AppTypography.ibm(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingCurrencySubtitle,
            textAlign: TextAlign.left,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: Currency.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final currency = Currency.all[index];
                return _CurrencyCard(
                  currency: currency,
                  isSelected: _selected == currency.code,
                  onTap: () => setState(() => _selected = currency.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final Currency currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyCard({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderStrong,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(currency.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                currency.name,
                style: AppTypography.ibm(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${currency.code} · ${currency.symbol}',
              style: AppTypography.mono(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.borderStrong,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
