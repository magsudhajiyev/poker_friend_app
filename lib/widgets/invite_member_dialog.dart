import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/club.dart';
import '../models/club_member.dart';
import '../models/club_notification.dart';
import '../services/auth_service.dart';
import '../services/club_service.dart';
import '../services/club_notification_service.dart';
import '../services/email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';
import '../utils/user_facing_error.dart';

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
      final l10n = AppLocalizations.of(context);
      final email = _emailController.text.trim().toLowerCase();
      final club = widget.club;
      final inviterName = AuthService.userDisplayName ?? 'Club Admin';
      final roleName = _selectedRole == ClubRole.admin ? 'admin' : 'dealer';
      final roleDisplay = _selectedRole == ClubRole.admin ? l10n.inviteMemberRoleAnAdmin : l10n.inviteMemberRoleADealer;

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
              content: Text(l10n.inviteMemberAlreadyMember(existingUser['displayName'], club.name)),
              backgroundColor: Colors.amber,
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
          title: l10n.inviteMemberAddedNotificationTitle,
          body: l10n.inviteMemberAddedNotificationBody(inviterName, club.name, roleDisplay),
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
          title: l10n.inviteMemberAddedSuccessTitle,
          message: l10n.inviteMemberAddedSuccessMessage(existingUser['displayName'], club.name, roleDisplay),
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
          title: l10n.inviteMemberInvitationSentTitle,
          message: l10n.inviteMemberInvitationSentMessage(email, club.name),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).inviteMemberError(UserFacingError.message(e))),
          backgroundColor: AppColors.lossRed,
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
        backgroundColor: AppColors.infoCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.buttonPrimary,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTypography.ibm(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).commonDone,
              style: AppTypography.ibm(
                color: AppColors.buttonPrimary,
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
      backgroundColor: AppColors.infoCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radius18),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context);
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.buttonPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDecorations.radius10),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: AppColors.buttonPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.inviteMemberTitle,
                      style: AppTypography.ibm(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.club.name,
                      style: AppTypography.ibm(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  color: Colors.white.withOpacity(0.4),
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Email field
          Text(
            l10n.inviteMemberEmailLabel,
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.ibm(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: l10n.inviteMemberEmailHint,
              hintStyle: AppTypography.ibm(
                color: Colors.white.withOpacity(0.25),
                fontSize: 15,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.buttonPrimary, width: 1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.lossRed, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                borderSide: const BorderSide(color: AppColors.lossRed, width: 1),
              ),
              errorStyle: AppTypography.ibm(
                fontSize: 12,
                color: AppColors.lossRed,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.inviteMemberEmailRequired;
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return l10n.inviteMemberEmailInvalid;
              }
              return null;
            },
          ),

          const SizedBox(height: 18),

          // Role selector
          Text(
            l10n.inviteMemberRoleLabel,
            style: AppTypography.ibm(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRoleOption(
                  role: ClubRole.dealer,
                  icon: Icons.style,
                  label: l10n.inviteMemberRoleDealer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRoleOption(
                  role: ClubRole.admin,
                  icon: Icons.admin_panel_settings,
                  label: l10n.inviteMemberRoleAdmin,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isSubmitting ? null : () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: Center(
                      child: Text(
                        l10n.commonCancel,
                        style: AppTypography.ibm(
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _submitInvitation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                      color: AppColors.buttonPrimary,
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              l10n.inviteMemberSendInvite,
                              style: AppTypography.ibm(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
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
  }) {
    final isSelected = _selectedRole == role;
    const mint = AppColors.buttonPrimary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? mint.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(
            color: isSelected ? mint : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? mint : Colors.white.withOpacity(0.4),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.ibm(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? mint : Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
