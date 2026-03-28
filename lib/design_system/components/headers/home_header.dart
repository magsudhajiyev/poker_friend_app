import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';

/// Home screen header with gradient background and rounded bottom corners
/// Matches the new Figma design for the home screen
class HomeHeader extends StatelessWidget {
  final String userName;
  final String subtitle;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onSettingsPressed;
  final bool showNotificationBadge;
  final int? notificationCount;

  const HomeHeader({
    Key? key,
    required this.userName,
    this.subtitle = 'Welcome back',
    this.onMenuPressed,
    this.onNotificationPressed,
    this.onSettingsPressed,
    this.showNotificationBadge = false,
    this.notificationCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the status bar height to add as top padding
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate ellipse size based on screen width (not container height to avoid infinite constraints)
    final ellipseWidth = screenWidth * 1.5;
    final ellipseSize = screenWidth * 1.2; // Use width-based sizing for the circle

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(34),
        bottomRight: Radius.circular(34),
      ),
      child: Container(
        decoration: const BoxDecoration(
          // Base linear gradient (black to teal)
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
            colors: [
              AppColors.headerGradientBlack,
              Color(0xFF0A1A1C),  // Mid transition
              AppColors.headerGradientTeal,
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Elliptical teal glow (Figma node 580-3127)
            Positioned(
              top: -ellipseSize * 0.35,  // Position above header
              right: -screenWidth * 0.25, // -25.24%
              child: Transform.scale(
                scaleX: 1.0,
                scaleY: 0.7,  // Elliptical shape (stretched horizontally)
                child: Container(
                  width: ellipseWidth,
                  height: ellipseSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: [
                        const Color(0xFF1A4A4A),  // Bright teal center
                        const Color(0xFF133538).withOpacity(0.7),
                        const Color(0xFF133538).withOpacity(0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Content with safe area padding
            Padding(
              padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
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

                  // Right: Dark pill with bell + hamburger menu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E24),
                      borderRadius: BorderRadius.circular(110),
                      border: Border.all(
                        color: const Color(0xFF6388A5),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 10,
                          offset: Offset(0, 0),
                        ),
                        BoxShadow(
                          color: Color(0x73000000),
                          blurRadius: 37,
                          offset: Offset(0, 2),
                        ),
                      ],
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

            const SizedBox(height: 18),
              ],
            ),
          ),
          ],
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

  Widget _buildImageIcon(String path, double size, Color? color) {
    if (path.endsWith('.svg')) {
      return color != null
          ? SvgPicture.asset(
              path,
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            )
          : SvgPicture.asset(
              path,
              width: size,
              height: size,
            );
    } else {
      return Image.asset(
        path,
        width: size,
        height: size,
        color: color,
      );
    }
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
              child: _buildImageIcon(
                imagePath,
                24,
                applyColorFilter ? Colors.white : null,
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
                  ? _buildImageIcon(imagePath, 28, Colors.white)
                  : Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2D55),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
