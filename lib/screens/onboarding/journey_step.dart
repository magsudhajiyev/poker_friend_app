import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';

class JourneyStep extends StatefulWidget {
  final ValueChanged<String> onContinue;
  final VoidCallback? onBack;

  const JourneyStep({super.key, required this.onContinue, this.onBack});

  @override
  State<JourneyStep> createState() => _JourneyStepState();
}

class _JourneyStepState extends State<JourneyStep>
    with AutomaticKeepAliveClientMixin {
  String? _selected;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final options = [
      ('beginner', l10n.onboardingJourneyBeginner),
      ('fun', l10n.onboardingJourneyFun),
      ('regular', l10n.onboardingJourneyRegular),
      ('pro', l10n.onboardingJourneyPro),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (widget.onBack != null)
                        _buildBackChevron(widget.onBack!),
                      const SizedBox(height: 16),
                      Text(
                        l10n.onboardingJourneyTitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.onboardingJourneySubtitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8C8C8C),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ...options.map((option) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OptionCard(
                              label: option.$2,
                              isSelected: _selected == option.$1,
                              onTap: () =>
                                  setState(() => _selected = option.$1),
                            ),
                          )),
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
                    onPressed: _selected != null
                        ? () => widget.onContinue(_selected!)
                        : null,
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
                    child: Text(
                      l10n.onboardingContinue,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.backgroundPaper,
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

class _OptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
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
          color: const Color(0xFF101115).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
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
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
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
