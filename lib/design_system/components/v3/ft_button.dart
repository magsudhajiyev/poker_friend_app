import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens/ft_tokens.g.dart';

/// Visual style of an [FtButton] — the Figma `Button` set's `Style` property.
enum FtButtonVariant {
  /// Filled green. The one commit action on a screen.
  prominent,

  /// Neutral alternative: elevated surface with a hairline border.
  bordered,

  /// Low-emphasis action on a tinted fill.
  secondary,

  /// Link-style action, no container.
  borderless,
}

/// Size of an [FtButton] — the Figma `Button` set's `Size` property.
enum FtButtonSize {
  /// 26pt tall, Footnote label, 14px icon. Off-table only.
  small,

  /// 37pt tall, Callout label, 16px icon.
  medium,

  /// 50pt tall, Body/Emphasized label, 20px icon. Anything tapped at the table.
  large,
}

/// Final Table v3 pill button (Figma `finaltable_v3` › Button).
///
/// Every colour comes from the `button*` component tokens in [FtColors], so
/// retheming a button means changing its tokens, not this widget.
///
/// ```dart
/// FtButton(label: l10n.save, onPressed: _save)                     // prominent, large
/// FtButton(label: l10n.cancel, variant: FtButtonVariant.bordered)
/// FtButton(label: l10n.delete, destructive: true, onPressed: _delete)
/// ```
///
/// A button with `onPressed: null` renders the disabled state. Small and
/// Medium buttons keep a 44pt minimum hit area (Apple HIG) even though they
/// draw smaller; set [expandHitArea] to false only where the surrounding
/// layout already guarantees it.
class FtButton extends StatefulWidget {
  const FtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FtButtonVariant.prominent,
    this.size = FtButtonSize.large,
    this.destructive = false,
    this.icon,
    this.iconPosition = FtIconPosition.start,
    this.fullWidth = false,
    this.expandHitArea = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final FtButtonVariant variant;
  final FtButtonSize size;

  /// Red treatment for actions that delete or discard. Pair with undo.
  final bool destructive;

  /// Usually an [Icon]; it picks up the token colour and size automatically.
  final Widget? icon;
  final FtIconPosition iconPosition;

  /// Stretch to the parent's width (sheet and form actions).
  final bool fullWidth;
  final bool expandHitArea;
  final String? semanticLabel;

  bool get enabled => onPressed != null;

  @override
  State<FtButton> createState() => _FtButtonState();
}

enum FtIconPosition { start, end }

/// Resolved colours for one button state. Public so tests and the design
/// preview can assert against the tokens.
@immutable
class FtButtonColors {
  const FtButtonColors({
    required this.background,
    required this.border,
    required this.label,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color label;
  final Color icon;

  static FtButtonColors resolve(
    FtColors c, {
    required FtButtonVariant variant,
    required bool destructive,
    required bool enabled,
    bool pressed = false,
  }) {
    const none = Colors.transparent;
    if (!enabled) {
      final hasBorder = variant == FtButtonVariant.prominent ||
          variant == FtButtonVariant.bordered;
      return FtButtonColors(
        background:
            variant == FtButtonVariant.borderless ? none : c.buttonDisabledBg,
        border: hasBorder ? c.buttonDisabledBorder : none,
        label: c.buttonDisabledLabel,
        icon: c.buttonDisabledIcon,
      );
    }
    switch (variant) {
      case FtButtonVariant.prominent:
        if (destructive) {
          return FtButtonColors(
            background: c.buttonDestructiveBg,
            border: none,
            label: c.buttonDestructiveLabel,
            icon: c.buttonDestructiveIcon,
          );
        }
        return FtButtonColors(
          background: pressed ? c.buttonPrimaryBgPressed : c.buttonPrimaryBg,
          border: none,
          label: c.buttonPrimaryLabel,
          icon: c.buttonPrimaryIcon,
        );
      case FtButtonVariant.bordered:
        return FtButtonColors(
          background: c.buttonBorderedBg,
          border: destructive
              ? c.buttonBorderedDestructiveBorder
              : c.buttonBorderedBorder,
          label: destructive
              ? c.buttonBorderedDestructiveLabel
              : c.buttonBorderedLabel,
          icon: destructive
              ? c.buttonBorderedDestructiveIcon
              : c.buttonBorderedIcon,
        );
      case FtButtonVariant.secondary:
        return FtButtonColors(
          background: destructive
              ? c.buttonSecondaryDestructiveBg
              : c.buttonSecondaryBg,
          border: none,
          label: destructive
              ? c.buttonSecondaryDestructiveLabel
              : c.buttonSecondaryLabel,
          icon: destructive
              ? c.buttonSecondaryDestructiveIcon
              : c.buttonSecondaryIcon,
        );
      case FtButtonVariant.borderless:
        return FtButtonColors(
          background: none,
          border: none,
          label: destructive
              ? c.buttonBorderlessDestructiveLabel
              : c.buttonBorderlessLabel,
          icon: destructive
              ? c.buttonBorderlessDestructiveIcon
              : c.buttonBorderlessIcon,
        );
    }
  }
}

/// Per-size metrics from the Figma file. Every variant reserves a 1px border
/// (transparent when unused) so all styles share one footprint; the padding
/// here excludes it: Small 26pt, Medium 37pt, Large 50pt tall.
@immutable
class FtButtonMetrics {
  const FtButtonMetrics._(this.padding, this.gap, this.iconSize, this.textStyle);

  final EdgeInsets padding;
  final double gap;
  final double iconSize;
  final TextStyle textStyle;

  static FtButtonMetrics of(FtButtonSize size) {
    switch (size) {
      case FtButtonSize.small:
        return const FtButtonMetrics._(
          EdgeInsets.symmetric(
            vertical: FtSpacing.s4 - FtBorderWidth.hairline,
            horizontal: FtSpacing.s12 - FtBorderWidth.hairline,
          ),
          FtSpacing.s4,
          FtSize.iconXs,
          FtTextStyles.footnote,
        );
      case FtButtonSize.medium:
        return const FtButtonMetrics._(
          EdgeInsets.symmetric(
            vertical: FtSpacing.s8 - FtBorderWidth.hairline,
            horizontal: FtSpacing.s16 - FtBorderWidth.hairline,
          ),
          FtSpacing.s8,
          FtSize.iconSm,
          FtTextStyles.callout,
        );
      case FtButtonSize.large:
        return const FtButtonMetrics._(
          EdgeInsets.symmetric(
            vertical: FtSpacing.s14 - FtBorderWidth.hairline,
            horizontal: FtSpacing.s24 - FtBorderWidth.hairline,
          ),
          FtSpacing.s8,
          FtSize.iconMd,
          FtTextStyles.bodyEmphasized,
        );
    }
  }
}

class _FtButtonState extends State<FtButton> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _activate() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final c = FtColors.of(context);
    final m = FtButtonMetrics.of(widget.size);
    final colors = FtButtonColors.resolve(
      c,
      variant: widget.variant,
      destructive: widget.destructive,
      enabled: widget.enabled,
      pressed: _pressed,
    );

    final label = Text(
      widget.label,
      style: m.textStyle.copyWith(color: colors.label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    final icon = widget.icon == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(color: colors.icon, size: m.iconSize),
            child: widget.icon!,
          );

    final children = <Widget>[
      if (icon != null && widget.iconPosition == FtIconPosition.start) ...[
        icon,
        SizedBox(width: m.gap),
      ],
      Flexible(child: label),
      if (icon != null && widget.iconPosition == FtIconPosition.end) ...[
        SizedBox(width: m.gap),
        icon,
      ],
    ];

    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: widget.fullWidth ? double.infinity : null,
      padding: m.padding,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(FtRadius.full),
        border: Border.all(
          color: colors.border,
          width: FtBorderWidth.hairline,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: _focused ? FtShadows.focusRing(c) : null,
      ),
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );

    body = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: body,
    );

    if (widget.expandHitArea && widget.size != FtButtonSize.large) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: FtSize.hitTarget),
        child: Center(widthFactor: 1, heightFactor: 1, child: body),
      );
    }

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          enabled: widget.enabled,
          mouseCursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (v) {
            if (mounted && v != _focused) setState(() => _focused = v);
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _activate : null,
            onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
            onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
            onTapCancel: widget.enabled ? () => _setPressed(false) : null,
            child: body,
          ),
        ),
      ),
    );
  }
}
