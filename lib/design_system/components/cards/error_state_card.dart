import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/typography.dart';

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
    this.message =
        'We couldn\'t load your data.\nPlease check your connection and try again.',
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
                color: AppColors.textDisabled,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.ibm(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.ibm(
                fontSize: 14,
                color: AppColors.textDisabled,
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
                      color: AppColors.accentSecondary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: AppTypography.ibm(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentSecondary,
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
