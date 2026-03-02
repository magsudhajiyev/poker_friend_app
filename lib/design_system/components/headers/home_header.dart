import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Home screen header with gradient background and rounded bottom corners
/// Matches the new Figma design for the home screen
class HomeHeader extends StatelessWidget {
  final String userName;
  final String subtitle;
  final double currentBankroll;
  final double bankrollGoal;
  final String? filterLabel;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onFilterPressed;
  final bool showNotificationBadge;
  final int? notificationCount;

  const HomeHeader({
    Key? key,
    required this.userName,
    this.subtitle = 'Welcome back',
    required this.currentBankroll,
    required this.bankrollGoal,
    this.filterLabel,
    this.onMenuPressed,
    this.onNotificationPressed,
    this.onSettingsPressed,
    this.onFilterPressed,
    this.showNotificationBadge = false,
    this.notificationCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final remaining = bankrollGoal - currentBankroll;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.headerGradientCyan,
            AppColors.headerGradientGreen,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with icons and greeting
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    // Left: Scanner button (white bg, dark icon from Figma)
                    _buildImageIconButton(
                      imagePath: 'icons/flat_icons/scanner.png',
                      onPressed: onMenuPressed,
                      backgroundColor: Colors.white,
                      applyColorFilter: false,
                    ),
                    const SizedBox(width: 14),

                    // Center: Greeting text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hey, $userName',
                            style: AppTypography.homeGreeting(),
                          ),
                          Text(
                            subtitle,
                            style: AppTypography.homeSubtitle(),
                          ),
                        ],
                      ),
                    ),

                    // Right: Dark pill with icons (no individual backgrounds)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.darkPillBg,
                        borderRadius: BorderRadius.circular(110),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPillIconButton(
                            imagePath: 'icons/flat_icons/bell.png',
                            onPressed: onNotificationPressed,
                            showBadge: showNotificationBadge,
                            badgeCount: notificationCount,
                          ),
                          const SizedBox(width: 4),
                          _buildPillIconButton(
                            icon: Icons.menu,
                            onPressed: onSettingsPressed,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Financial Snapshot section
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 24, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter chip (pill shape)
                    if (filterLabel != null)
                      GestureDetector(
                        onTap: onFilterPressed,
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(78),
                          ),
                          child: Text(
                            filterLabel!,
                            style: AppTypography.labelChip(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Bankroll amount
                    Text(
                      '\$${currentBankroll.toInt()} of \$${bankrollGoal.toInt()}',
                      style: AppTypography.bankrollAmount(),
                    ),
                    const SizedBox(height: 14),

                    // Remaining amount
                    Text(
                      '\$${remaining.toInt()} left',
                      style: AppTypography.bankrollSubtext(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool showBadge = false,
    int? badgeCount,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.iconButtonBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 24,
            ),
          ),
          if (showBadge && badgeCount != null && badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageIconButton({
    required String imagePath,
    VoidCallback? onPressed,
    bool showBadge = false,
    int? badgeCount,
    Color? backgroundColor,
    bool applyColorFilter = true,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.iconButtonBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: 24,
                height: 24,
                color: applyColorFilter ? Colors.white : null,
              ),
            ),
          ),
          if (showBadge && badgeCount != null && badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Icon button for use inside the dark pill container (no individual background)
  Widget _buildPillIconButton({
    IconData? icon,
    String? imagePath,
    VoidCallback? onPressed,
    bool showBadge = false,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: imagePath != null
                  ? Image.asset(
                      imagePath,
                      width: 28,
                      height: 28,
                      color: Colors.white,
                    )
                  : Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          if (showBadge && badgeCount != null && badgeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
