import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../constants/colors.dart';
import '../../constants/typography.dart';
import '../../constants/decorations.dart';

/// A sliding in-app notification that appears from the top of the screen.
/// Swipe up to dismiss, or tap to trigger an action.
class SlidingNotification extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? detail;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final Duration displayDuration;
  final bool autoDismiss;

  const SlidingNotification({
    Key? key,
    required this.title,
    required this.subtitle,
    this.detail,
    this.icon = Icons.event_seat,
    this.iconColor = AppColors.profitGreen,
    this.onTap,
    required this.onDismiss,
    this.displayDuration = const Duration(seconds: 5),
    this.autoDismiss = true,
  }) : super(key: key);

  @override
  State<SlidingNotification> createState() => _SlidingNotificationState();
}

class _SlidingNotificationState extends State<SlidingNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  double _dragOffset = 0;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start the entrance animation
    _controller.forward();

    // Set up auto-dismiss timer
    if (widget.autoDismiss) {
      _autoDismissTimer = Timer(widget.displayDuration, _dismiss);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _autoDismissTimer?.cancel();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Only allow dragging upward (negative values)
      _dragOffset += details.delta.dy;
      if (_dragOffset > 0) _dragOffset = 0;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    // If dragged up more than 50px or with enough velocity, dismiss
    if (_dragOffset < -50 || details.velocity.pixelsPerSecond.dy < -500) {
      _dismiss();
    } else {
      // Snap back
      setState(() {
        _dragOffset = 0;
      });
      // Restart auto-dismiss timer
      if (widget.autoDismiss) {
        _autoDismissTimer = Timer(widget.displayDuration, _dismiss);
      }
    }
  }

  void _handleTap() {
    if (widget.onTap != null) {
      _dismiss();
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: GestureDetector(
                onVerticalDragStart: _handleDragStart,
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: _handleDragEnd,
                onTap: _handleTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildNotificationCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 27, sigmaY: 27),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFDFE7FF).withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 44,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Header row: "NOTIFICATION" label + close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).slidingNotificationHeader,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFE6E6E7),
                        height: 1.64,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(
                        Icons.close,
                        color: const Color(0xFFE6E6E7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Content row: icon + text
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppTypography.ibm(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              height: 1.64,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: AppTypography.ibm(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFE6E6E7),
                              height: 1.44,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (widget.detail != null)
                            Text(
                              widget.detail!,
                              style: AppTypography.ibm(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFE6E6E7),
                                height: 1.44,
                                decoration: TextDecoration.none,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper class to show sliding notifications using an overlay
class SlidingNotificationOverlay {
  static OverlayEntry? _currentEntry;

  /// Show a sliding notification
  static void show({
    required BuildContext context,
    required String title,
    required String subtitle,
    String? detail,
    IconData icon = Icons.event_seat,
    Color iconColor = AppColors.profitGreen,
    VoidCallback? onTap,
    Duration displayDuration = const Duration(seconds: 5),
    bool autoDismiss = true,
  }) {
    // Dismiss any existing notification
    dismiss();

    _currentEntry = OverlayEntry(
      builder: (context) => SlidingNotification(
        title: title,
        subtitle: subtitle,
        detail: detail,
        icon: icon,
        iconColor: iconColor,
        onTap: onTap,
        onDismiss: dismiss,
        displayDuration: displayDuration,
        autoDismiss: autoDismiss,
      ),
    );

    Overlay.of(context).insert(_currentEntry!);
  }

  /// Dismiss the current notification
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}
