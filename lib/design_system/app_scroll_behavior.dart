import 'package:flutter/material.dart';

/// App-wide scroll behaviour.
///
/// Uses iOS-style `BouncingScrollPhysics` on every scrollable widget so
/// lists rubber-band at the edges and carry momentum consistently
/// across platforms — the app is designed iOS-first, and platform-
/// default `ClampingScrollPhysics` on Android reads as abrupt by
/// comparison. Also suppresses Android's overscroll glow indicator
/// because the bounce covers the same "you've reached the end" cue.
///
/// Wired into `MaterialApp.scrollBehavior`, so every `ListView`,
/// `SingleChildScrollView`, `PageView`, etc. inherits it automatically —
/// individual screens shouldn't need to set their own physics.
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // No Android glow — the bounce is our edge feedback.
    return child;
  }
}
