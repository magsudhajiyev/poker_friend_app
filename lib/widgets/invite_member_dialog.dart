import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import '../models/club_notification.dart';
import '../services/auth_service.dart';
import '../services/club_service.dart';
import '../services/club_notification_service.dart';
import '../services/email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Dialog for club admins to invite dealers or other admins
class InviteMemberDialog extends StatefulWidget {
  final Club club;

  const InviteMemberDialog({
    super.key,
    required this.club,
  });

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  ClubRole _selectedRole = ClubRole.dealer;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitInvitation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final club = widget.club;
      final inviterName = AuthService.userDisplayName ?? 'Club Admin';
      final roleName = _selectedRole == ClubRole.admin ? 'admin' : 'dealer';

      // Check if user already exists in the system
      final existingUser = await _findUserByEmail(email);

      if (existingUser != null) {
        // User exists - check if already a member
        final existingMember = await ClubService.getMember(club.id, existingUser['userId']);

        if (existingMember != null) {
          // Already a member
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${existingUser['displayName']} is already a member of ${club.name}'),
              backgroundColor: PokerFriendColors.yellow,
            ),
          );
          return;
        }

        // Add user directly as member
        await ClubService.addMemberToClub(
          clubId: club.id,
          userId: existingUser['userId'],
          displayName: existingUser['displayName'],
          email: email,
          role: _selectedRole,
        );

        // Send in-app notification
        await ClubNotificationService.notifyUser(
          userId: existingUser['userId'],
          type: NotificationType.memberInvited,
          title: 'You\'ve Been Added to a Club!',
          body: '$inviterName added you to "${club.name}" as ${_selectedRole == ClubRole.admin ? 'an admin' : 'a dealer'}.',
          clubId: club.id,
          clubName: club.name,
          data: {
            'action': 'view_club',
            'clubId': club.id,
          },
        );

        // Also send email notification
        await EmailService.sendMemberInvitationEmail(
          toEmail: email,
          clubName: club.name,
          inviterName: inviterName,
          role: roleName,
        );

        if (!mounted) return;
        Navigator.pop(context, true); // Return true to indicate member was added
        _showSuccessDialog(
          title: 'Member Added!',
          message: '${existingUser['displayName']} has been added to ${club.name} as ${_selectedRole == ClubRole.admin ? 'an admin' : 'a dealer'}.',
        );
      } else {
        // User doesn't exist - just send email invitation
        await EmailService.sendMemberInvitationEmail(
          toEmail: email,
          clubName: club.name,
          inviterName: inviterName,
          role: roleName,
        );

        if (!mounted) return;
        Navigator.pop(context, false); // Return false as no member was added yet
        _showSuccessDialog(
          title: 'Invitation Sent!',
          message: 'An invitation email has been sent to $email. Once they sign up, they\'ll be able to join ${club.name}.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: PokerFriendColors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _findUserByEmail(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'userId': doc.id,
          'displayName': doc.data()['displayName'] ?? doc.data()['name'] ?? 'User',
          'email': doc.data()['email'] ?? email,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: PokerFriendColors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: PokerFriendColors.green,
                size: 32,
              ),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: PokerFriendColors.dark9,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Done',
              style: TextStyle(
                color: PokerFriendColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PokerFriendColors.dark3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PokerFriendColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add,
                  color: PokerFriendColors.green,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite Member',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.club.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: PokerFriendColors.dark9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Email field
          Text(
            'Email Address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PokerFriendColors.dark9,
            ),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter email address',
              hintStyle: TextStyle(color: PokerFriendColors.dark7),
              filled: true,
              fillColor: PokerFriendColors.dark1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PokerFriendColors.dark5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PokerFriendColors.dark5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PokerFriendColors.green),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PokerFriendColors.red),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          SizedBox(height: 20),

          // Role selector
          Text(
            'Role',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PokerFriendColors.dark9,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRoleOption(
                  role: ClubRole.dealer,
                  icon: Icons.style,
                  label: 'Dealer',
                  color: PokerFriendColors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildRoleOption(
                  role: ClubRole.admin,
                  icon: Icons.admin_panel_settings,
                  label: 'Admin',
                  color: PokerFriendColors.yellow,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: PokerFriendColors.dark5),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: PokerFriendColors.dark9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitInvitation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PokerFriendColors.green,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Send Invite',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required ClubRole role,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : PokerFriendColors.dark1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : PokerFriendColors.dark5,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : PokerFriendColors.dark9,
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : PokerFriendColors.dark9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
