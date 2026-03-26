import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/poker_friend_theme.dart';
import '../services/club_request_service.dart';

/// Show the Register Club dialog with blurred background
Future<void> showRegisterClubDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Register Club',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: const Center(
            child: RegisterClubDialog(),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

/// Dialog for submitting a club registration request
/// Matches Figma design node 324:3492
class RegisterClubDialog extends StatefulWidget {
  const RegisterClubDialog({Key? key}) : super(key: key);

  @override
  State<RegisterClubDialog> createState() => _RegisterClubDialogState();
}

class _RegisterClubDialogState extends State<RegisterClubDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clubNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _adminEmailController = TextEditingController();

  bool _isSubmitting = false;

  bool get _isFormValid =>
      _clubNameController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _adminEmailController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _clubNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await ClubRequestService.submitRequest(
        clubName: _clubNameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    final email = _adminEmailController.text.trim();

    // Show success dialog with blur background
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Success',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: _SuccessDialogContent(
                email: email,
                onDismiss: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: 370,
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface, // #101115
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1B1E24), // neutrals/800
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(20, 4),
              blurRadius: 114,
              spreadRadius: 0,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(),

                const SizedBox(height: 35),

                // Form fields
                _buildFormFields(),

                // Info message
                _buildInfoMessage(),

                const SizedBox(height: 44),

                // Submit button
                _buildSubmitButton(),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header with close button, title, and submit checkmark
  /// Figma node 324:3732
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Close button (X) - gray background
          // Figma: 38x38 button, p:9.68, 24x24 icon container, X at inset 18.75% (=15x15)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF35373C), // neutrals/700
                borderRadius: BorderRadius.circular(88.733),
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    // X vector is 18.75% inset = 15x15 inside 24x24 container
                    child: SvgPicture.asset(
                      'icons/figma_icons/close.svg',
                      width: 15,
                      height: 15,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Title - centered
          Expanded(
            child: Center(
              child: Text(
                'Register Club',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.43,
                  height: 22 / 17,
                ),
              ),
            ),
          ),

          // Submit checkmark button - green background, black icon
          // Figma: 38x38 button, p:9.68, 24x24 icon (fills container)
          GestureDetector(
            onTap: (_isFormValid && !_isSubmitting) ? _submitRequest : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accentGreenBright, // #54E98A
                borderRadius: BorderRadius.circular(88.733),
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : SvgPicture.asset(
                        'icons/figma_icons/check.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.black, // Black checkmark per Figma
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Form fields section
  Widget _buildFormFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            label: 'Club Name',
            placeholder: 'e.g., Lucky Aces Poker Club',
            controller: _clubNameController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a club name';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Address',
            placeholder: 'e.g., 123 Main St, City, Country',
            controller: _addressController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the club address';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Phone Number',
            placeholder: 'e.g., +1 555-123-4567',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildInputField(
            label: 'Club Admin Email',
            placeholder: 'e.g., admin@myclub.com',
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter admin email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Single input field with label
  /// Figma node 324:3736
  Widget _buildInputField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.44,
          ),
        ),
        const SizedBox(height: 4),
        // Input field
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.44,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8C8C8C), // textDisabled
              height: 1.44,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: false,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF4E5054), // neutrals/600
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF73D4CF), // Border/Active
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: PokerFriendColors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: PokerFriendColors.red,
                width: 1,
              ),
            ),
            errorStyle: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: PokerFriendColors.red,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  /// Info message about club admin notification
  /// Figma node 324:3740
  Widget _buildInfoMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info icon (Figma node 324:3743) - teal colored
          SvgPicture.asset(
            'icons/figma_icons/info.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Color(0xFF73D4CF), // Border/Active teal
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          // Info text
          Expanded(
            child: Text(
              'This person will be notified when the club is approved and will become the club owner.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Submit request button
  /// Figma node 324:3746
  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: (_isFormValid && !_isSubmitting) ? _submitRequest : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: (_isFormValid && !_isSubmitting)
                ? AppColors.buttonPrimary // #89F1EC
                : const Color(0xFF4B9A96), // buttonDisabled
            borderRadius: BorderRadius.circular(110),
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Submit Request',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      letterSpacing: -0.5,
                      height: 24 / 17,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Success dialog content matching Figma node 324:4369
class _SuccessDialogContent extends StatelessWidget {
  final String email;
  final VoidCallback onDismiss;

  const _SuccessDialogContent({
    required this.email,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 370,
        decoration: BoxDecoration(
          color: AppColors.backgroundSurface, // #101115
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1B1E24), // neutrals/800
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(20, 4),
              blurRadius: 114,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Content section with icon and text
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  // Success badge icon (32x32)
                  SvgPicture.asset(
                    'icons/figma_icons/success_badge.svg',
                    width: 32,
                    height: 32,
                  ),

                  const SizedBox(height: 24),

                  // Text content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Title
                        Text(
                          'Request Submitted!',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 27,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Description
                        Text(
                          'Your club registration request has been submitted. We\'ll notify you at $email once it\'s reviewed.',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            height: 1.44,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Button section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF89F1B1), // Success green
                    borderRadius: BorderRadius.circular(110),
                  ),
                  child: Center(
                    child: Text(
                      'Got it',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        letterSpacing: -0.5,
                        height: 24 / 17,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
