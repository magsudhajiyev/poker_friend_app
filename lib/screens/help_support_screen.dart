import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/backgrounds/gradient_background.dart';
import '../services/support_request_service.dart';
import '../l10n/app_localizations.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategoryKey = 'Bug Report';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.supportFillAllFields,
            style: GoogleFonts.ibmPlexSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFD55A41),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await SupportRequestService.submitRequest(
        category: _selectedCategoryKey,
        subject: subject,
        description: description,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.supportSubmitted,
            style: GoogleFonts.ibmPlexSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF87ED81),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.supportFailedSubmit(e.toString()),
            style: GoogleFonts.ibmPlexSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFD55A41),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = [
      (key: 'Bug Report', label: l10n.supportBugReport),
      (key: 'Feature Request', label: l10n.supportFeatureRequest),
      (key: 'Account Issue', label: l10n.supportAccountIssue),
      (key: 'Other', label: l10n.supportOther),
    ];
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF101115),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.supportTitle,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category
                        _buildSectionHeader(l10n.supportCategoryLabel),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((cat) {
                            final isSelected = _selectedCategoryKey == cat.key;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategoryKey = cat.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF89F1EC).withValues(alpha: 0.15)
                                      : AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF89F1EC)
                                        : const Color(0xFF1C1F21),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  cat.label,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF89F1EC)
                                        : const Color(0xFF8C8C8C),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 28),

                        // Subject
                        _buildSectionHeader(l10n.supportSubjectLabel),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _subjectController,
                          hint: l10n.supportSubjectHint,
                        ),

                        const SizedBox(height: 28),

                        // Description
                        _buildSectionHeader(l10n.supportDescriptionLabel),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _descriptionController,
                          hint: l10n.supportDescriptionHint,
                          maxLines: 6,
                        ),

                        const SizedBox(height: 36),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _isSubmitting ? null : _submit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: _isSubmitting
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: Center(
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        l10n.supportSubmitButton,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                          letterSpacing: -0.43,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF87ED81),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1.44,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSans(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF8C8C8C),
          height: 1.44,
        ),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4E5054), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4E5054), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF89F1EC), width: 1),
        ),
      ),
    );
  }
}
