import 'package:flutter/material.dart';

import '../../design_system/components/buttons/app_button.dart';
import '../../design_system/components/cards/error_state_card.dart';
import '../../design_system/components/cards/info_card.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/sizes.dart';
import '../../design_system/constants/spacing.dart';
import '../../design_system/constants/typography.dart';
import '../../l10n/app_localizations.dart';

/// A tab body: pull-to-refresh list with preserved scroll position, kept
/// alive so swiping between tabs composites the existing page instead of
/// rebuilding it (and replaying entrance animations) mid-gesture.
class LeakTabList extends StatefulWidget {
  final String storageKey;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const LeakTabList({
    super.key,
    required this.storageKey,
    required this.onRefresh,
    required this.children,
  });

  @override
  State<LeakTabList> createState() => _LeakTabListState();
}

class _LeakTabListState extends State<LeakTabList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSurface,
      child: ListView(
        key: PageStorageKey('leak_tab_${widget.storageKey}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.bottomPadding),
        children: widget.children,
      ),
    );
  }
}

/// Static skeleton (no looping animation: battery) with an honest "working"
/// line, since read-time aggregation really is re-crunching every hand.
class LeakLoadingSkeleton extends StatelessWidget {
  const LeakLoadingSkeleton({super.key});

  Widget _block(double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _block(AppSizes.listRowMin),
          const SizedBox(height: AppSpacing.md),
          _block(AppSizes.progressRing * 4),
          const SizedBox(height: AppSpacing.xs),
          _block(AppSizes.progressRing * 2),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: AppSizes.spinner,
                height: AppSizes.spinner,
                child: CircularProgressIndicator(
                    strokeWidth: AppSizes.spinnerStroke,
                    color: AppColors.accentPrimary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(l10n.leakLoading,
                    style: AppTypography.bodySmMedium(
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// First-load failure: shared error card plus a real retry button.
class LeakErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const LeakErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorStateCard(title: l10n.leakErrorTitle, message: message),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.commonRetry,
              variant: AppButtonVariant.primaryLarge,
              onTap: onRetry,
              leadingIcon: const Icon(Icons.refresh,
                  size: AppIconSize.sm, color: AppColors.textInverse),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zero hands logged: explain, and offer the way to fix it.
class LeakEmptyView extends StatelessWidget {
  final VoidCallback? onLogHand;
  final Future<void> Function()? onRefresh;
  const LeakEmptyView({super.key, this.onLogHand, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.bottomPadding),
      children: [
        InfoCard(
          isEmpty: true,
          emptyTitle: l10n.leakEmptyTitle,
          emptySubtitle: l10n.leakEmptyBody,
          buttonText: onLogHand == null ? null : l10n.leakEmptyAction,
          onEmptyTap: onLogHand,
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSurface,
      child: list,
    );
  }
}

/// Fade + small rise for section [index], driven by one shared one-shot
/// controller. With [animation] at 1 (reduced motion) it is a no-op.
class LeakReveal extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Widget child;

  const LeakReveal({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  static const double _step = 0.08;
  static const double _span = 0.45;
  static const Offset _rise = Offset(0, 0.04);

  @override
  Widget build(BuildContext context) {
    final start = (_step * index).clamp(0.0, 0.5);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, (start + _span).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: _rise, end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
