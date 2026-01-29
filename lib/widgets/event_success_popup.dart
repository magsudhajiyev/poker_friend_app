import 'package:flutter/material.dart';

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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventSuccessPopup(
        onGoToCalendar: () => Navigator.pop(context, 'calendar'),
        onAddAnotherEvent: () => Navigator.pop(context, 'add_another'),
        onClose: () => Navigator.pop(context, null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF131613),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button row
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            SizedBox(height: 8),
            // Content
            Column(
              children: [
                // Success icon (confetti)
                Image.asset(
                  'icons/flat_icons/confetti.png',
                  width: 44,
                  height: 44,
                  color: Color(0xFFBAFF99),
                ),
                SizedBox(height: 20),
                // Title
                Text(
                  'Nice! Your event is now on\nthe calendar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                // Subtitle
                Text(
                  'You can edit or remove it anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFF8FFF7),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 50),
                // Buttons
                Column(
                  children: [
                    // "Go to calendar" button (filled)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onGoToCalendar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFBAFF99),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Go to calendar',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 11),
                    // "Add another event" button (text only)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onAddAnotherEvent,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Add another event',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
