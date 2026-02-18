import 'dart:async';
import 'package:flutter/material.dart';

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
    this.iconColor = const Color(0xFF5AC95A),
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
    return Container(
      decoration: BoxDecoration(
        // Semi-transparent dark background to match app's glassy style
        color: const Color(0xFF1A1A1E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (widget.detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.detail!,
                          style: TextStyle(
                            color: widget.iconColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Tap indicator
                if (widget.onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 24,
                  ),
              ],
            ),
          ),
          // Swipe indicator
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
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
    Color iconColor = const Color(0xFF5AC95A),
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
