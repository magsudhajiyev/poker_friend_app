import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Friendly error state shown when screen data fails to load.
/// Replaces infinite loading spinners with a message and retry button.
class ErrorStateCard extends StatelessWidget {
  final VoidCallback? onRetry;
  final String title;
  final String message;

  const ErrorStateCard({
    Key? key,
    this.onRetry,
    this.title = 'Something went wrong',
    this.message = 'We couldn\'t load your data.\nPlease check your connection and try again.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF8C8C8C),
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: const Color(0xFF8C8C8C),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color(0xFF89F1EC).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF89F1EC),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
