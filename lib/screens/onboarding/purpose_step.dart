import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';

class PurposeStep extends StatefulWidget {
  final ValueChanged<List<String>> onContinue;
  final VoidCallback? onBack;

  const PurposeStep({super.key, required this.onContinue, this.onBack});

  @override
  State<PurposeStep> createState() => _PurposeStepState();
}

class _PurposeStepState extends State<PurposeStep>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _selected = {};

  @override
  bool get wantKeepAlive => true;

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final options = [
      ('logging', l10n.onboardingPurposeLogging),
      ('bankroll', l10n.onboardingPurposeBankroll),
      ('opponents', l10n.onboardingPurposeOpponents),
      ('actions', l10n.onboardingPurposeActions),
      ('studying', l10n.onboardingPurposeStudying),
      ('sharing', l10n.onboardingPurposeSharing),
      ('ai', l10n.onboardingPurposeAi),
      ('export', l10n.onboardingPurposeExport),
      ('stacks', l10n.onboardingPurposeStacks),
    ];

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
                        l10n.onboardingPurposeTitle,
                        style: AppTypography.ibm(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.onboardingPurposeSubtitle,
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textDisabled,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ...options.map((option) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CheckCard(
                              label: option.$2,
                              isSelected: _selected.contains(option.$1),
                              onTap: () => _toggle(option.$1),
                            ),
                          )),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  bottomPadding > 0 ? bottomPadding + 16 : 40,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selected.isNotEmpty
                        ? () => widget.onContinue(_selected.toList())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.bgPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(110),
                      ),
                      elevation: 0,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      l10n.onboardingGetStarted,
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

class _CheckCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CheckCard({
    required this.label,
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
            Expanded(
              child: Text(
                label,
                style: AppTypography.ibm(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            // Checkbox indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentSecondary
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.accentSecondary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
