import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/components/app_text_field.dart';
import '../l10n/app_localizations.dart';
import '../services/club_request_service.dart';

/// Show the Register Club bottom sheet
Future<void> showRegisterClubDialog(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _RegisterClubSheet(),
  );
}

class _RegisterClubSheet extends StatefulWidget {
  const _RegisterClubSheet();

  @override
  State<_RegisterClubSheet> createState() => _RegisterClubSheetState();
}

class _RegisterClubSheetState extends State<_RegisterClubSheet> {
  final _clubNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _adminEmailController = TextEditingController();

  String? _clubNameError;
  String? _addressError;
  String? _phoneError;
  String? _adminEmailError;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _clubNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  bool _validate(AppLocalizations l10n) {
    String? nameErr;
    String? addrErr;
    String? phoneErr;
    String? emailErr;

    if (_clubNameController.text.trim().isEmpty) {
      nameErr = l10n.registerClubNameRequired;
    }
    if (_addressController.text.trim().isEmpty) {
      addrErr = l10n.registerClubAddressRequired;
    }
    if (_phoneController.text.trim().isEmpty) {
      phoneErr = l10n.registerClubPhoneRequired;
    }
    final email = _adminEmailController.text.trim();
    if (email.isEmpty) {
      emailErr = l10n.registerClubAdminEmailRequired;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      emailErr = l10n.registerClubAdminEmailInvalid;
    }

    setState(() {
      _clubNameError = nameErr;
      _addressError = addrErr;
      _phoneError = phoneErr;
      _adminEmailError = emailErr;
    });

    return nameErr == null && addrErr == null && phoneErr == null && emailErr == null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validate(l10n)) return;

    setState(() => _isSubmitting = true);

    try {
      await ClubRequestService.submitRequest(
        clubName: _clubNameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
      );

      if (mounted) {
        final email = _adminEmailController.text.trim();
        Navigator.pop(context);
        _showSuccessDialog(context, email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registerClubFailedToSubmit(e.toString())),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(BuildContext rootContext, String email) {
    showGeneralDialog(
      context: rootContext,
      barrierDismissible: true,
      barrierLabel: 'Success',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: _SuccessDialogContent(
                email: email,
                onDismiss: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            SizedBox(
              height: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    l10n.registerClubTitle,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0C0C0C),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFFB9B9B9)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Fields
            AppTextField(
              label: l10n.registerClubNameLabel,
              hint: l10n.registerClubNamePlaceholder,
              controller: _clubNameController,
              textInputAction: TextInputAction.next,
              errorText: _clubNameError,
              onChanged: (_) => setState(() => _clubNameError = null),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: l10n.registerClubAddressLabel,
              hint: l10n.registerClubAddressPlaceholder,
              controller: _addressController,
              textInputAction: TextInputAction.next,
              errorText: _addressError,
              onChanged: (_) => setState(() => _addressError = null),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: l10n.registerClubPhoneLabel,
              hint: l10n.registerClubPhonePlaceholder,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              errorText: _phoneError,
              onChanged: (_) => setState(() => _phoneError = null),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: l10n.registerClubAdminEmailLabel,
              hint: l10n.registerClubAdminEmailPlaceholder,
              controller: _adminEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              errorText: _adminEmailError,
              onChanged: (_) => setState(() => _adminEmailError = null),
            ),

            const SizedBox(height: 4),

            // Info note
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 12, color: Color(0xFFB9B9B9)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.registerClubInfoMessage,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF0C0C0C),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(color: const Color(0xFFB9B9B9), width: 1),
                      ),
                      child: Center(
                        child: Text(
                          l10n.commonCancel,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0C0C0C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0C0C),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.registerClubSubmitRequest,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
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
      ),
    );
  }
}

class _SuccessDialogContent extends StatelessWidget {
  const _SuccessDialogContent({
    required this.email,
    required this.onDismiss,
  });

  final String email;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEFBF3),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 28,
              color: Color(0xFF4CDE78),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            l10n.registerClubSuccessTitle,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C0C0C),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            l10n.registerClubSuccessMessage(email),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFB9B9B9),
              height: 1.44,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0C),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Center(
                child: Text(
                  l10n.registerClubGotIt,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
