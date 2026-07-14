import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';
import '../buttons/back_button_circle.dart';

/// Reusable top nav bar — unified spec.
///
/// Container: `bgPrimary` (`#0C0C0C`), 56px content + status bar + 12px bottom.
/// Left:      `BackButtonCircle` (38px `bgElevated` circle, white 24px caret).
/// Center:    17px SemiBold title, optional 13px `textSecondary` subtitle.
/// Right:     44px `bgElevated` circle with 24px white icon, OR custom widget.
///
/// For landing screens (no back), use [TopNavBar.landing] which drops the
/// back button and left-aligns a 24px title.
class TopNavBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onMenuTap;
  final GlobalKey? menuKey;
  final Widget? rightAction;
  final bool isLanding;
  final bool includeStatusBarPadding;

  const TopNavBar({
    super.key,
    required this.title,
    this.subtitle,
    required VoidCallback this.onBack,
    this.onMenuTap,
    this.menuKey,
    this.rightAction,
    this.includeStatusBarPadding = true,
  }) : isLanding = false;

  /// Landing-screen variant — no back button, larger left-aligned title.
  const TopNavBar.landing({
    super.key,
    required this.title,
    this.subtitle,
    this.onMenuTap,
    this.menuKey,
    this.rightAction,
    this.includeStatusBarPadding = true,
  })  : onBack = null,
        isLanding = true;

  @override
  Widget build(BuildContext context) {
    final statusBarHeight =
        includeStatusBarPadding ? MediaQuery.of(context).padding.top : 0.0;

    return Container(
      color: AppColors.bgPrimary,
      padding: EdgeInsets.only(top: statusBarHeight, bottom: 12),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isLanding ? _buildLanding() : _buildDetail(),
        ),
      ),
    );
  }

  Widget _buildDetail() => _threeSlotRow();

  /// Landing variant flushes the title to the left edge and lets the
  /// right action size intrinsically (44px circle button, pill button, etc.).
  Widget _buildLanding() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _LeadingTitle(title: title, subtitle: subtitle),
        ),
        _rightSlot(),
      ],
    );
  }

  /// Detail 3-slot layout: [44px left] [flexible center] [44px right].
  /// Left/right slots are always 44px so the back button and right action
  /// stay at identical X positions across every detail screen. The back
  /// button itself renders at 38px, centered within its 44px slot.
  Widget _threeSlotRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: onBack != null
              ? Center(child: BackButtonCircle(onPressed: onBack))
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _CenterTitle(title: title, subtitle: subtitle),
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: _rightSlot(),
        ),
      ],
    );
  }

  Widget _rightSlot() {
    if (rightAction != null) {
      return rightAction!;
    }
    if (onMenuTap != null) {
      return _CircleIconButton(
        key: menuKey,
        onTap: onMenuTap!,
        assetPath: 'assets/icons/DotsThreeOutline.svg',
      );
    }
    return const SizedBox(width: 44);
  }
}

class _CenterTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _CenterTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.ibm(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 22 / 17,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ibm(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 20 / 13,
            ),
          ),
      ],
    );
  }
}

class _LeadingTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _LeadingTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.ibm(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 30 / 24,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ibm(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 20 / 13,
            ),
          ),
      ],
    );
  }
}

/// 44px circular action button matching `BackButtonCircle` style.
class _CircleIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final String assetPath;

  const _CircleIconButton({
    super.key,
    required this.onTap,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SvgPicture.asset(
            assetPath,
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
