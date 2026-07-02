import 'package:flutter/material.dart';
import '../design_system/poker_friend_theme.dart';
import '../models/club_member.dart';
import '../services/invitation_service.dart';
import '../l10n/app_localizations.dart';

/// Screen for redeeming an invitation code to join a club
class RedeemInvitationScreen extends StatefulWidget {
  const RedeemInvitationScreen({Key? key}) : super(key: key);

  @override
  State<RedeemInvitationScreen> createState() => _RedeemInvitationScreenState();
}

class _RedeemInvitationScreenState extends State<RedeemInvitationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  String? _clubName;
  String? _role;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an invitation code';
      });
      return;
    }

    if (code.length != 8) {
      setState(() {
        _errorMessage = 'Invitation code should be 8 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First, check if the invitation exists and is valid
      final invitation = await InvitationService.getInvitationByToken(code);

      if (invitation == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid or expired invitation code';
        });
        return;
      }

      // Accept the invitation
      await InvitationService.acceptInvitationByToken(code);

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _clubName = invitation.clubName;
        _role = invitation.role.displayName;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          l10n.redeemInvitationTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isSuccess ? _buildSuccessState() : _buildInputState(),
      ),
    );
  }

  Widget _buildInputState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        // Icon
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(bottom: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PokerFriendColors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.qr_code,
            size: 40,
            color: PokerFriendColors.purple,
          ),
        ),
        Text(
          l10n.redeemEnterCode,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.redeemCodeDescription,
          style: TextStyle(
            fontSize: 14,
            color: PokerFriendColors.dark9,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Code input
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: 'XXXXXXXX',
            hintStyle: TextStyle(
              color: PokerFriendColors.dark7,
              fontSize: 28,
              letterSpacing: 6,
            ),
            filled: true,
            fillColor: PokerFriendColors.dark3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: PokerFriendColors.purple, width: 2),
            ),
            counterText: '',
            errorText: _errorMessage,
            errorStyle: TextStyle(color: PokerFriendColors.red),
          ),
          onChanged: (_) {
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
          },
        ),
        const SizedBox(height: 24),
        // Submit button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _redeemCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: PokerFriendColors.purple.withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n.redeemJoinClub,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: PokerFriendColors.green.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 60,
            color: PokerFriendColors.green,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          l10n.redeemWelcome,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.redeemJoinedAs(_clubName ?? '', _role ?? ''),
          style: TextStyle(
            fontSize: 16,
            color: PokerFriendColors.dark9,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true); // Return true to indicate success
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              l10n.redeemContinue,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
