import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../design_system/constants/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../models/currency.dart';
import 'onboarding_scaffold.dart';

/// Onboarding step: pick the currency all money amounts are shown in.
/// The device locale pre-selects a sensible default, so a single tap on
/// Continue is enough for most users.
///
/// Layout matches Figma node 1919:15994: centered 28px title, 15px
/// centered subtitle, borderless pill search, then a single `bgSurface`
/// card that hosts the list — rows separated by hairlines instead of
/// being individually chipped cards. Selected row gets a `bgElevated`
/// fill and the symbol tints to `accentSecondary`.
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selected = _defaultForLocale();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Currency> get _filtered {
    if (_query.isEmpty) return Currency.all;
    return Currency.all.where((c) {
      return c.name.toLowerCase().contains(_query) ||
          c.code.toLowerCase().contains(_query) ||
          c.symbol.toLowerCase().contains(_query);
    }).toList();
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.onboardingCurrencyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingCurrencySubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 24),
          _SearchField(controller: _searchController),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius:
                    BorderRadius.circular(AppDecorations.radiusLg),
              ),
              padding: const EdgeInsets.all(16),
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matches',
                        style: AppTypography.ibm(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 9,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, index) {
                        final currency = _filtered[index];
                        return _CurrencyRow(
                          currency: currency,
                          isSelected: _selected == currency.code,
                          onTap: () =>
                              setState(() => _selected = currency.code),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One 38-tall currency row inside the list card. Figma node 1919:16040.
///
/// Layout: [symbol · name (CODE)] ······················· [flag]
/// - Symbol column: fixed 32w so names align across rows
/// - Selected: row fills `bgElevated`, symbol tints `accentSecondary`,
///   name brightens to white
class _CurrencyRow extends StatelessWidget {
  final Currency currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyRow({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
        ),
        child: Row(
          children: [
            // Fixed check slot — reserved on every row so the layout
            // doesn't shift when the selection moves. Shows an
            // `accentSecondary` check on the selected row only.
            SizedBox(
              width: 18,
              height: 18,
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.accentSecondary,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text(
                currency.symbol,
                textAlign: TextAlign.left,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.accentSecondary
                      : AppColors.contentInactive,
                  height: 22 / 15,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${currency.name} (${currency.code})',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ibm(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color:
                      isSelected ? Colors.white : AppColors.textSecondary,
                  height: 22 / 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              height: 18,
              child: currency.flagAsset != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SvgPicture.asset(
                        currency.flagAsset!,
                        width: 24,
                        height: 18,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        currency.flag,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search input — Figma node 1919:16030. `bgSurface` fill with a
/// same-colour default border (reads as borderless); on focus the
/// border switches to `accentPrimary` for a subtle affordance.
class _SearchField extends StatefulWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusFull),
        border: Border.all(
          color: isFocused ? AppColors.accentPrimary : AppColors.bgSurface,
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'icons/figma_icons/search.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              AppColors.contentInactive,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              cursorColor: AppColors.accentPrimary,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 22 / 15,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).commonSearch,
                hintStyle: AppTypography.ibm(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 22 / 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => widget.controller.clear(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.cancel,
                    color: AppColors.contentInactive,
                    size: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
