import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'invitation_service.dart';
import 'club_service.dart';
import 'auth_service.dart';

/// Service for handling deep links from email invitations
///
/// Deep link format: pkr://invite/{clubId}/{invitationId}
///
/// Initialize in main.dart before runApp:
/// ```dart
/// await DeepLinkService.initialize(
///   navigatorKey: navigatorKey,
///   onInvitationAccepted: (clubId, clubName) {
///     // Show success notification
///   },
/// );
/// ```
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static GlobalKey<NavigatorState>? _navigatorKey;
  static Function(String clubId, String clubName)? _onInvitationAccepted;
  static Map<String, String>? _pendingInvitation;
  static bool _isInitialized = false;

  /// Initialize deep link handling
  ///
  /// Must be called before runApp() in main.dart
  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required Function(String clubId, String clubName) onInvitationAccepted,
  }) async {
    if (_isInitialized) return;

    _navigatorKey = navigatorKey;
    _onInvitationAccepted = onInvitationAccepted;
    _isInitialized = true;

    try {
      // Handle initial link (cold start - app opened via deep link)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('DeepLinkService: Initial link received - $initialLink');
        await _handleDeepLink(initialLink);
      }

      // Handle subsequent links (warm start - app already running)
      _appLinks.uriLinkStream.listen(
        (uri) {
          print('DeepLinkService: Stream link received - $uri');
          _handleDeepLink(uri);
        },
        onError: (error) {
          print('DeepLinkService: Stream error - $error');
        },
      );

      print('DeepLinkService: Initialized successfully');
    } catch (e) {
      print('DeepLinkService: Initialization error - $e');
    }
  }

  /// Parse and handle incoming deep link
  static Future<void> _handleDeepLink(Uri uri) async {
    print('DeepLinkService: Handling deep link - $uri');

    // Expected format: pkr://invite/{clubId}/{invitationId}
    if (uri.scheme != 'pkr') {
      print('DeepLinkService: Unknown scheme - ${uri.scheme}');
      return;
    }

    if (uri.host != 'invite') {
      print('DeepLinkService: Unknown host - ${uri.host}');
      return;
    }

    final pathSegments = uri.pathSegments;
    if (pathSegments.length < 2) {
      print('DeepLinkService: Invalid path - missing clubId or invitationId');
      return;
    }

    final clubId = pathSegments[0];
    final invitationId = pathSegments[1];

    print('DeepLinkService: Parsed invitation - clubId: $clubId, invitationId: $invitationId');

    // Check if user is logged in
    if (AuthService.userId == null) {
      // Store pending invitation for after login
      _pendingInvitation = {
        'clubId': clubId,
        'invitationId': invitationId,
      };
      print('DeepLinkService: User not logged in - storing pending invitation');
      return;
    }

    await _acceptInvitation(clubId, invitationId);
  }

  /// Accept an invitation and notify the app
  static Future<void> _acceptInvitation(String clubId, String invitationId) async {
    try {
      print('DeepLinkService: Accepting invitation - $invitationId');

      // Accept the invitation
      await InvitationService.acceptInvitation(
        clubId: clubId,
        invitationId: invitationId,
      );

      // Get club name for notification
      final club = await ClubService.getClub(clubId);
      final clubName = club?.name ?? 'the club';

      print('DeepLinkService: Invitation accepted - now a dealer on $clubName');

      // Notify the app to show success message
      _onInvitationAccepted?.call(clubId, clubName);

    } catch (e) {
      print('DeepLinkService: Error accepting invitation - $e');
      // Could show error snackbar here if we have context
    }
  }

  /// Check and process any pending invitation after user logs in
  ///
  /// Call this in auth_wrapper.dart after authentication completes
  static Future<void> processPendingInvitation() async {
    if (_pendingInvitation == null) {
      print('DeepLinkService: No pending invitation');
      return;
    }

    final clubId = _pendingInvitation!['clubId']!;
    final invitationId = _pendingInvitation!['invitationId']!;
    _pendingInvitation = null;

    print('DeepLinkService: Processing pending invitation - $invitationId');
    await _acceptInvitation(clubId, invitationId);
  }

  /// Check if there's a pending invitation waiting to be processed
  static bool get hasPendingInvitation => _pendingInvitation != null;

  /// Get the navigator key (for navigation if needed)
  static GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;
}
