import 'package:flutter/material.dart';

/// Single-flight navigation for the running-session screens. A tap on the Home
/// bar, a notification action or a Session History row must never push the
/// same hub twice: while the hub is on the stack a further open pops back to
/// it, and while another action with the same key is running it does nothing.
class SessionNavigation {
  SessionNavigation._();

  /// Key of the hub of the running FULL logging session (only one session runs
  /// at a time, and its id is not known when its hub is pushed).
  static const String fullHubKey = 'hub:full';

  static String hubKey(String sessionId) => 'hub:$sessionId';

  static final Map<String, Route<dynamic>> _open = {};
  static final Set<String> _busy = {};

  /// Remembers [route] as the screen for [key] until it leaves the stack.
  static void track(String key, Route<dynamic> route) {
    _open[key] = route;
    route.popped.whenComplete(() {
      if (identical(_open[key], route)) _open.remove(key);
    });
  }

  /// The route for [key] when it is still on the navigator stack.
  static Route<dynamic>? active(String key) {
    final r = _open[key];
    if (r != null && r.isActive) return r;
    return null;
  }

  static bool isOpen(String key) => active(key) != null;

  /// Pops back to the screen for [key]. False when it is not on the stack.
  static bool popTo(NavigatorState nav, String key) {
    final r = active(key);
    if (r == null) return false;
    nav.popUntil((x) => identical(x, r) || x.isFirst);
    return true;
  }

  /// Opens the screen for [key] immediately: pops back to it when it is
  /// already open, ignores a second call while the first is still pushing,
  /// otherwise pushes the route made by [build]. Completes when the screen is
  /// closed (or at once when it was already open).
  static Future<void> openOnce<T>(
      NavigatorState nav, String key, Route<T> Function() build) async {
    if (popTo(nav, key)) return;
    if (!_busy.add(key)) return;
    final Future<T?> closed;
    try {
      final route = build();
      track(key, route);
      closed = nav.push(route);
    } finally {
      // push registers the route synchronously: from here on `active` guards.
      _busy.remove(key);
    }
    await closed;
  }

  /// Runs [action] unless one with the same [key] is still running.
  static Future<void> runOnce(String key, Future<void> Function() action) async {
    if (!_busy.add(key)) return;
    try {
      await action();
    } finally {
      _busy.remove(key);
    }
  }

  @visibleForTesting
  static void reset() {
    _open.clear();
    _busy.clear();
  }
}
