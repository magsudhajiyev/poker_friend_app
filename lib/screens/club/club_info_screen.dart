import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../design_system/constants/colors.dart';
import '../../models/club.dart';
import '../../models/club_member.dart';
import '../../services/club_service.dart';
import '../../l10n/app_localizations.dart';

/// Club info screen for regular members (read-only view)
class ClubInfoScreen extends StatefulWidget {
  final Club club;

  const ClubInfoScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  State<ClubInfoScreen> createState() => _ClubInfoScreenState();
}

class _ClubInfoScreenState extends State<ClubInfoScreen> {
  bool _isLoading = true;
  List<ClubMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await ClubService.getMembers(widget.club.id);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.backgroundPaper,
      body: Stack(
        children: [
          // Teal glow at top
          Positioned(
            top: -250 + topPadding,
            left: -screenWidth * 0.25,
            right: -screenWidth * 0.25,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.5,
                  colors: [
                    const Color(0xFF2E5A59).withOpacity(0.9),
                    const Color(0xFF2E5A59).withOpacity(0.5),
                    const Color(0xFF0D2B2A).withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Main content
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.buttonPrimary,
                      ),
                    ),
                  )
                else ...[
                  _buildClubInfoSection(),
                  const SizedBox(height: 24),
                  _buildMembersSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.backgroundSurface,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            l10n.clubInfoTitle,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClubInfoSection() {
    final club = widget.club;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Club name with icon
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.buttonPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: AppColors.buttonPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  club.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Description
          if (club.description != null && club.description!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              club.description!,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                color: AppColors.textDisabled,
                height: 1.5,
              ),
            ),
          ],

          // Divider
          if (club.address != null || club.phone != null) ...[
            const SizedBox(height: 18),
            const Divider(color: AppColors.separatorDark, height: 1),
            const SizedBox(height: 16),
          ],

          // Address
          if (club.address != null && club.address!.isNotEmpty)
            _buildInfoRow(Icons.location_on_outlined, club.address!),

          // Phone
          if (club.phone != null && club.phone!.isNotEmpty) ...[
            if (club.address != null && club.address!.isNotEmpty)
              const SizedBox(height: 12),
            _buildInfoRow(Icons.phone_outlined, club.phone!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textDisabled, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              color: AppColors.textDisabled,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.clubInfoMembersCount(_members.length),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 17,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l10n.clubInfoNoMembers,
              style: GoogleFonts.ibmPlexSans(
                color: AppColors.textDisabled,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(_members.length, (index) {
                final member = _members[index];
                return Column(
                  children: [
                    _buildMemberRow(member),
                    if (index < _members.length - 1)
                      const Divider(
                        height: 1,
                        color: AppColors.separatorDark,
                        indent: 70,
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberRow(ClubMember member) {
    final roleColor = _getRoleColor(member.role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (member.displayName ?? 'U')[0].toUpperCase(),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  color: roleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName ?? 'Unknown',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Text(
              member.role.name.toUpperCase(),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: roleColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(ClubRole role) {
    switch (role) {
      case ClubRole.owner:
        return const Color(0xFFFFD13F);
      case ClubRole.admin:
        return AppColors.buttonPrimary;
      case ClubRole.dealer:
        return const Color(0xFF4A87F2);
      case ClubRole.player:
        return const Color(0xFF62E3BC);
    }
  }
}
