import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Success popup shown after successfully adding a calendar event.
/// Slides up from the bottom of the screen with two action buttons.
class EventSuccessPopup extends StatelessWidget {
  final VoidCallback onGoToCalendar;
  final VoidCallback onAddAnotherEvent;
  final VoidCallback onClose;

  const EventSuccessPopup({
    Key? key,
    required this.onGoToCalendar,
    required this.onAddAnotherEvent,
    required this.onClose,
  }) : super(key: key);

  /// Shows the success popup as a modal bottom sheet.
  /// Returns 'calendar' if user taps "Go to calendar",
  /// 'add_another' if user taps "Add another event",
  /// or null if dismissed.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: EventSuccessPopup(
          onGoToCalendar: () => Navigator.pop(context, 'calendar'),
          onAddAnotherEvent: () => Navigator.pop(context, 'add_another'),
          onClose: () => Navigator.pop(context, null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral800,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            blurRadius: 114,
            offset: Offset(20, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Close button
            GestureDetector(
              onTap: onClose,
              child: SvgPicture.asset(
                'icons/figma_icons/close.svg',
                width: 15,
                height: 15,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 24),

            // Content
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // Success icon — checkmark in mint circle
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.buttonPrimary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SvgPicture.asset(
                      'icons/figma_icons/check.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    l10n.eventSuccessTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                  ),
                  const SizedBox(height: 7),

                  // Subtitle
                  Text(
                    l10n.eventSuccessSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.ibm(
                      color: const Color(0xFFB3B4B6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.64,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Column(
                    children: [
                      // "Go to calendar" button (white filled, pill shape)
                      GestureDetector(
                        onTap: onGoToCalendar,
                        child: Container(
                          width: 218,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Text(
                            l10n.eventSuccessGoToCalendar,
                            textAlign: TextAlign.center,
                            style: AppTypography.ibm(
                              color: Colors.black,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 24 / 17,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // "Add another event" button (white outline, pill shape)
                      GestureDetector(
                        onTap: onAddAnotherEvent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(110),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'icons/figma_icons/plus.svg',
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.eventSuccessAddAnother,
                                style: AppTypography.ibm(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 24 / 17,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
