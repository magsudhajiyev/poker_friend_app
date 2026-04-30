import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/club_invitation.dart';
import '../models/club_member.dart';
import '../services/invitation_service.dart';

/// Screen to display and manage pending club invitations
class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({Key? key}) : super(key: key);

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  List<ClubInvitation> _invitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final invitations = await InvitationService.getPendingInvitations();
      setState(() {
        _invitations = invitations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).invitationsFailedLoad(e.toString()))),
        );
      }
    }
  }

  Future<void> _acceptInvitation(ClubInvitation invitation) async {
    try {
      await InvitationService.acceptInvitation(
        clubId: invitation.clubId,
        invitationId: invitation.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).invitationsScreenJoinedAs(invitation.clubName ?? 'club', invitation.role.displayName)),
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }

      _loadInvitations(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).invitationsFailedAccept(e.toString())),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineInvitation(ClubInvitation invitation) async {
    try {
      await InvitationService.declineInvitation(
        clubId: invitation.clubId,
        invitationId: invitation.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).invitationsDeclined),
          ),
        );
      }

      _loadInvitations(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).invitationsFailedDecline(e.toString())),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      appBar: AppBar(
        backgroundColor: PokerFriendColors.dark1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).invitationsScreenTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PokerFriendColors.purple),
            )
          : _invitations.isEmpty
              ? _buildEmptyState()
              : _buildInvitationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.mail_outline,
              size: 40,
              color: PokerFriendColors.dark9,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).invitationsScreenNoPending,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).invitationsScreenYouWillSee,
            style: TextStyle(
              fontSize: 14,
              color: PokerFriendColors.dark9,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).invitationsScreenGoBack,
              style: TextStyle(
                color: PokerFriendColors.purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsList() {
    return RefreshIndicator(
      onRefresh: _loadInvitations,
      color: PokerFriendColors.purple,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _invitations.length,
        itemBuilder: (context, index) {
          return _buildInvitationCard(_invitations[index]);
        },
      ),
    );
  }

  Widget _buildInvitationCard(ClubInvitation invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PokerFriendColors.purple.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Club icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: PokerFriendColors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.business,
                  color: PokerFriendColors.purple,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.clubName ?? AppLocalizations.of(context).invitationsScreenUnknownClub,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(invitation.role).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            invitation.role.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getRoleColor(invitation.role),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Invited by
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: PokerFriendColors.dark9,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).invitationsScreenInvitedBy(invitation.invitedByName ?? 'Admin'),
                style: TextStyle(
                  fontSize: 13,
                  color: PokerFriendColors.dark9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Expiry info
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: PokerFriendColors.dark9,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).invitationsScreenExpires(_formatExpiryDate(invitation.expiresAt)),
                style: TextStyle(
                  fontSize: 13,
                  color: invitation.isExpired
                      ? PokerFriendColors.red
                      : PokerFriendColors.dark9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineInvitation(invitation),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: PokerFriendColors.dark7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    AppLocalizations.of(context).invitationsScreenDecline,
                    style: TextStyle(
                      color: PokerFriendColors.dark11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: invitation.canAccept
                      ? () => _acceptInvitation(invitation)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PokerFriendColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    AppLocalizations.of(context).invitationsScreenAccept,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(ClubRole role) {
    switch (role) {
      case ClubRole.owner:
        return PokerFriendColors.yellow;
      case ClubRole.admin:
        return PokerFriendColors.blue;
      case ClubRole.dealer:
        return PokerFriendColors.purple;
      case ClubRole.player:
        return PokerFriendColors.green;
    }
  }

  String _formatExpiryDate(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    final l10n = AppLocalizations.of(context);

    if (difference.isNegative) {
      return l10n.invitationsScreenExpired;
    } else if (difference.inDays > 0) {
      return l10n.invitationsScreenExpiresInDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.invitationsScreenExpiresInHours(difference.inHours);
    } else {
      return l10n.invitationsScreenExpiresSoon;
    }
  }
}
