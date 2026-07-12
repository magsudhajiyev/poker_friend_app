import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/decorations.dart';
import '../../constants/spacing.dart';
import 'sheet_header.dart';

/// Canonical bottom-sheet scaffold.
///
/// Renders a full-width dark ([AppColors.bgPrimary]) container with a top-left
/// and top-right radius of [AppDecorations.radiusXl] and an optional 1px
/// [AppColors.borderStrong] top border. Includes a standard [SheetHeader]
/// unless [header] is overridden or [title] is null. No drop shadow.
///
/// Use [AppSheet.show] for standard modal presentation. Pass
/// `heightFraction: null` for a compact sheet that hugs its content
/// (capped at 90% of screen).
class AppSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget body;
  final Widget? trailing;
  final VoidCallback? onClose;

  /// Fraction of screen height. Pass `null` to hug content
  /// (`mainAxisSize: min`, capped at 90%).
  final double? heightFraction;
  final bool scrollable;
  final bool showTopBorder;
  final EdgeInsets bodyPadding;
  final Widget? header;

  const AppSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.body,
    this.trailing,
    this.onClose,
    this.heightFraction = 0.9,
    this.scrollable = true,
    this.showTopBorder = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      22,
      AppSpacing.xl,
      0,
    ),
    this.header,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    required Widget body,
    Widget? trailing,
    VoidCallback? onClose,
    double? heightFraction = 0.9,
    bool scrollable = true,
    bool showTopBorder = true,
    bool isDismissible = true,
    bool enableDrag = true,
    EdgeInsets bodyPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      22,
      AppSpacing.xl,
      0,
    ),
    Widget? header,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSheet(
        title: title,
        subtitle: subtitle,
        body: body,
        trailing: trailing,
        onClose: onClose,
        heightFraction: heightFraction,
        scrollable: scrollable,
        showTopBorder: showTopBorder,
        bodyPadding: bodyPadding,
        header: header,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final topPadding = media.padding.top;
    final screenHeight = media.size.height;
    final safeBottom = media.padding.bottom;

    final hugContent = heightFraction == null;
    final maxAvailable = screenHeight - bottomInset - topPadding;

    final double? sheetHeight;
    if (hugContent) {
      sheetHeight = null;
    } else {
      final desiredHeight = screenHeight * heightFraction!;
      sheetHeight = desiredHeight > maxAvailable ? maxAvailable : desiredHeight;
    }

    final hasHeader = header != null || title != null;

    final headerBlock = hasHeader
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md - 1,
              AppSpacing.xl,
              0,
            ),
            child: SizedBox(
              height: 56,
              child: header ??
                  SheetHeader(
                    title: title!,
                    subtitle: subtitle,
                    onClose: onClose ?? () => Navigator.pop(context),
                    trailing: trailing,
                  ),
            ),
          )
        : const SizedBox.shrink();

    final Widget bodyBlock;
    if (hugContent) {
      // Hug the content: no Expanded, add safe-area bottom padding.
      final effectivePadding = bodyPadding.copyWith(
        bottom: bodyPadding.bottom + safeBottom + AppSpacing.xl,
      );
      bodyBlock = scrollable
          ? SingleChildScrollView(padding: effectivePadding, child: body)
          : Padding(padding: effectivePadding, child: body);
    } else {
      bodyBlock = Expanded(
        child: scrollable
            ? SingleChildScrollView(padding: bodyPadding, child: body)
            : Padding(padding: bodyPadding, child: body),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: hugContent ? maxAvailable : double.infinity,
          ),
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDecorations.radiusXl),
                topRight: Radius.circular(AppDecorations.radiusXl),
              ),
              border: showTopBorder
                  ? Border.all(color: AppColors.borderStrong)
                  : null,
            ),
            child: Column(
              mainAxisSize: hugContent ? MainAxisSize.min : MainAxisSize.max,
              children: [headerBlock, bodyBlock],
            ),
          ),
        ),
      ),
    );
  }
}
