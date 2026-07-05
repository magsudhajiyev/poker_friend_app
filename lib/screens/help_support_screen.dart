import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/constants/colors.dart';
import '../design_system/components/headers/top_nav_bar.dart';
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
  final _subjectFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  String _selectedCategoryKey = 'Bug Report';
  bool _isSubmitting = false;

  static const _surface = Color(0xFF161719);
  static const _secondary = Color(0xFFB9B9B9);
  static const _focusBorder = Color(0xFF4CDE78);

  @override
  void initState() {
    super.initState();
    _subjectFocus.addListener(() => setState(() {}));
    _descriptionFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _subjectFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.supportFillAllFields,
              style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
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
          content: Text(l10n.supportSubmitted,
              style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: AppColors.limeGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.supportFailedSubmit(e.toString()),
              style: GoogleFonts.ibmPlexSans(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
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
      body: Column(
        children: [
          TopNavBar(
            title: l10n.supportTitle,
            onBack: () => Navigator.pop(context),
            backgroundColor: _surface,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category ─────────────────────────────────────────────
                  Text(
                    l10n.supportCategoryLabel,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFA3FF78),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: categories.map((cat) {
                      final isSelected = _selectedCategoryKey == cat.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategoryKey = cat.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFA3FF78) : const Color(0xFF2C2C2E),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            cat.label,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 22 / 15,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 40),

                  // ── Subject ───────────────────────────────────────────────
                  _buildInputField(
                    label: l10n.supportSubjectLabel,
                    controller: _subjectController,
                    focusNode: _subjectFocus,
                    hint: l10n.supportSubjectHint,
                  ),

                  const SizedBox(height: 24),

                  // ── Description ───────────────────────────────────────────
                  _buildInputField(
                    label: l10n.supportDescriptionLabel,
                    controller: _descriptionController,
                    focusNode: _descriptionFocus,
                    hint: l10n.supportDescriptionHint,
                    maxLines: 8,
                  ),

                  const SizedBox(height: 24),

                  // ── Submit ────────────────────────────────────────────────
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: _isSubmitting ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(
                                l10n.supportSubmitButton,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0C0C0C),
                                  height: 20 / 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }


  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    int maxLines = 1,
  }) {
    final isFocused = focusNode.hasFocus;
    final isFilled = controller.text.isNotEmpty;
    final isMultiline = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _secondary,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused ? _focusBorder : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: maxLines,
                style: GoogleFonts.ibmPlexSans(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.ibmPlexSans(fontSize: 15, color: _secondary),
                  contentPadding: EdgeInsets.fromLTRB(
                    16, 12,
                    isFilled && !isMultiline ? 4 : 16,
                    12,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixIcon: isFilled && !isMultiline
                      ? GestureDetector(
                          onTap: () => setState(() => controller.clear()),
                          child: const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.contentInactive,
                            size: 18,
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
