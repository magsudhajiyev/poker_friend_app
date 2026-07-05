import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../models/currency.dart';

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    if (widget.onBack != null)
                      _buildBackChevron(widget.onBack!),
                    const SizedBox(height: 16),
                    Text(
                      l10n.onboardingCurrencyTitle,
                      style: AppTypography.ibm(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.onboardingCurrencySubtitle,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textDisabled,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
              // Continue button — always enabled: a locale-based default is
              // pre-selected so nobody gets stuck on this step.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  bottomPadding > 0 ? bottomPadding + 16 : 40,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => widget.onContinue(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.bgPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDecorations.radius110),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.onboardingContinue,
                      style: AppTypography.ibm(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bgPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          color: AppColors.surfaceDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppColors.accentSecondary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
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
                color: AppColors.textDisabled,
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
                      ? AppColors.accentSecondary
                      : Colors.white.withValues(alpha: 0.3),
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
                          color: AppColors.accentSecondary,
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
