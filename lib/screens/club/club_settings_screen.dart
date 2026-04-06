import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../design_system/constants/colors.dart';
import '../../models/club.dart';
import '../../models/club_member.dart';
import '../../models/poker_table.dart';
import '../../services/club_service.dart';
import '../../services/table_service.dart';
import '../../widgets/invite_member_dialog.dart';
import '../../widgets/global_bottom_nav_bar.dart';

/// Club settings screen for admins to manage club info, tables, and members
/// Matches Figma node 436:5292
class ClubSettingsScreen extends StatefulWidget {
  final Club club;

  const ClubSettingsScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  State<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends State<ClubSettingsScreen> {
  late Club _club;
  bool _isLoading = true;
  bool _isSaving = false;

  // Club info controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _descriptionController;

  // Data
  List<PokerTable> _tables = [];
  List<ClubMember> _members = [];

  @override
  void initState() {
    super.initState();
    _club = widget.club;
    _nameController = TextEditingController(text: _club.name);
    _addressController = TextEditingController(text: _club.address ?? '');
    _phoneController = TextEditingController(text: _club.phone ?? '');
    _descriptionController = TextEditingController(text: _club.description ?? '');
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        TableService.getTables(_club.id),
        ClubService.getMembers(_club.id),
      ]);
      setState(() {
        _tables = results[0] as List<PokerTable>;
        _members = results[1] as List<ClubMember>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _saveClubInfo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ClubService.updateClub(
        _club.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      _club = _club.copyWith(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Club info saved'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: const Color(0xFFDA5B5E),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF02050B),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Cyan ellipse glow at top
          Positioned(
            top: -162,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 412,
                height: 217,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      const Color(0xFF4CDBFF).withValues(alpha: 0.25),
                      const Color(0xFF2EB46A).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              SizedBox(height: statusBarHeight),
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.tealAccent,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.tealAccent,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildClubInfoSection(),
                              _buildTablesSection(),
                              const SizedBox(height: 8),
                              _buildMembersSection(),
                              if (_club.appStoreQRUrl != null || _club.playStoreQRUrl != null) ...[
                                const SizedBox(height: 8),
                                _buildAppQRSection(),
                              ],
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: GlobalBottomNavBar(currentScreen: 'club'),
    );
  }

  /// Header matching Figma design
  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 84,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101115),
                    borderRadius: BorderRadius.circular(88),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'icons/figma_icons/back.svg',
                      width: 18,
                      height: 15,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Text(
                  'Club Settings',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== Club Info Section ==========

  Widget _buildClubInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Text(
            'Club Information',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8C8C8C),
              height: 1.44,
            ),
          ),
          const SizedBox(height: 24),
          // Text fields with 28px gap
          _buildOutlineTextField(
            controller: _nameController,
            label: 'Club Name',
          ),
          const SizedBox(height: 28),
          _buildOutlineTextField(
            controller: _addressController,
            label: 'Address',
          ),
          const SizedBox(height: 28),
          _buildOutlineTextField(
            controller: _phoneController,
            label: 'Phone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 28),
          _buildOutlineTextField(
            controller: _descriptionController,
            label: 'Description',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          // Save Changes button
          GestureDetector(
            onTap: _isSaving ? null : _saveClubInfo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF89F1EC),
                borderRadius: BorderRadius.circular(110),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Save Changes',
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
        ],
      ),
    );
  }

  Widget _buildOutlineTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF8C8C8C),
        height: 1.44,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        floatingLabelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
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

  // ========== Tables Section ==========

  Widget _buildTablesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label + add button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                'Tables',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8C8C8C),
                  height: 1.44,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showAddTableDialog,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF89F1EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_tables.isEmpty)
          // Empty state card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF101115),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.table_restaurant_outlined,
                  size: 24,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Text(
                  'No tables yet',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.44,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a table to get started',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.44,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...List.generate(_tables.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTableCard(_tables[index]),
            );
          }),
      ],
    );
  }

  Widget _buildTableCard(PokerTable table) {
    final isActive = table.status == TableStatus.active;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : Colors.black,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${table.tableNumber}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.name,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  table.status.name.toUpperCase(),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    color: isActive
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF808285),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // QR button
          _buildIconButton(
            icon: Icons.qr_code,
            onTap: () => _showTableQRDialog(table),
          ),
          const SizedBox(width: 8),
          // Edit button
          _buildIconButton(
            icon: Icons.edit,
            onTap: () => _showEditTableDialog(table),
          ),
          const SizedBox(width: 8),
          // Delete button
          _buildIconButton(
            icon: Icons.delete,
            color: const Color(0xFFDA5B5E),
            onTap: () => _confirmDeleteTable(table),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E24),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 18),
      ),
    );
  }

  // ========== Members Section ==========

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label + add button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                'Members (${_members.length})',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8C8C8C),
                  height: 1.44,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showInviteMemberDialog,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF89F1EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No members found',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                color: const Color(0xFF8C8C8C),
              ),
            ),
          )
        else
          ...List.generate(_members.length, (index) {
            return _buildMemberRow(_members[index]);
          }),
      ],
    );
  }

  Widget _buildMemberRow(ClubMember member) {
    final initials = _getInitials(member.displayName ?? 'U');
    final avatarColor = _getAvatarColor(member.role);
    final roleLabel = member.role == ClubRole.owner
        ? 'Owner'
        : member.role == ClubRole.admin
            ? 'Admin'
            : member.role == ClubRole.dealer
                ? 'Dealer'
                : 'Player';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Avatar (rounded rect)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avatarColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName ?? 'Unknown',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.44,
                  ),
                ),
                if (member.email != null)
                  Text(
                    member.email!,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF808285),
                      height: 1.64,
                    ),
                  ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4341),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              roleLabel,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF89F1EC),
                height: 1.64,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 3)).toUpperCase();
  }

  Color _getAvatarColor(ClubRole role) {
    switch (role) {
      case ClubRole.owner:
        return const Color(0xFF7C3AED);
      case ClubRole.admin:
        return const Color(0xFF2563EB);
      case ClubRole.dealer:
        return const Color(0xFF0891B2);
      case ClubRole.player:
        return const Color(0xFF059669);
    }
  }

  // ========== Dialogs ==========

  Future<void> _showAddTableDialog() async {
    final nameController = TextEditingController(text: 'Table ${_tables.length + 1}');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Table',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Table Name',
            labelStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            filled: true,
            fillColor: const Color(0xFF1B1E24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89F1EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(110),
              ),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await TableService.createTable(
          clubId: _club.id,
          tableNumber: _tables.length + 1,
          name: nameController.text.trim(),
          maxSeats: 9,
        );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Table added'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFDA5B5E),
            ),
          );
        }
      }
    }
    nameController.dispose();
  }

  Future<void> _showEditTableDialog(PokerTable table) async {
    final nameController = TextEditingController(text: table.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Table',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Table Name',
            labelStyle: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            filled: true,
            fillColor: const Color(0xFF1B1E24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89F1EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(110),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await TableService.updateTable(
          _club.id,
          table.id,
          name: nameController.text.trim(),
        );
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFDA5B5E),
            ),
          );
        }
      }
    }
    nameController.dispose();
  }

  Future<void> _confirmDeleteTable(PokerTable table) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101115),
        title: Text(
          'Delete Table?',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${table.name}"? This cannot be undone.',
          style: GoogleFonts.ibmPlexSans(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDA5B5E)),
            child: Text(
              'Delete',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await TableService.deleteTable(_club.id, table.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Table deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFDA5B5E),
            ),
          );
        }
      }
    }
  }

  Future<void> _showTableQRDialog(PokerTable table) async {
    final tableWithQR = await TableService.getTableWithQRCode(_club.id, table.id);
    final qrCode = tableWithQR?.tableQRCode;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${table.name} QR Code',
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (qrCode != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: qrCode,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                )
              else
                Text(
                  'QR code not available',
                  style: GoogleFonts.ibmPlexSans(color: Colors.white),
                ),
              const SizedBox(height: 16),
              Text(
                'Dealers scan this to start a session at this table',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: const Color(0xFF8C8C8C),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          if (qrCode != null)
            TextButton.icon(
              onPressed: () => _downloadQRCodePDF(table, qrCode),
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                'PDF',
                style: GoogleFonts.ibmPlexSans(),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF89F1EC),
              ),
            ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await TableService.regenerateQRCodes(_club.id, table.id, maxSeats: 9);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('QR codes regenerated'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(
              'Regenerate',
              style: GoogleFonts.ibmPlexSans(color: const Color(0xFFFFB300)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89F1EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(110),
              ),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Build App Download QR Codes section
  Widget _buildAppQRSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APP DOWNLOAD',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF87ED81),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C1F21)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF89F1EC).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_rounded, color: Color(0xFF89F1EC), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App QR Codes',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Share with players to download the app',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            color: const Color(0xFF8C8C8C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadAppQRCodePDF,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Download PDF',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(60),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Generate and download/share App Store QR codes as PDF
  Future<void> _downloadAppQRCodePDF() async {
    try {
      final qrImages = <String, pw.MemoryImage>{};
      final qrImageSize = 300.0;

      for (final entry in {
        'iOS': _club.appStoreQRUrl,
        'Android': _club.playStoreQRUrl,
      }.entries) {
        if (entry.value == null) continue;

        final qrPainter = QrPainter(
          data: entry.value!,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, qrImageSize, qrImageSize),
          Paint()..color = Colors.white,
        );
        qrPainter.paint(canvas, Size(qrImageSize, qrImageSize));

        final picture = recorder.endRecording();
        final img = await picture.toImage(qrImageSize.toInt(), qrImageSize.toInt());
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        qrImages[entry.key] = pw.MemoryImage(byteData!.buffer.asUint8List());
      }

      if (qrImages.isEmpty) return;

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    _club.name,
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Download the Final Table App',
                    style: const pw.TextStyle(fontSize: 18),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: qrImages.entries.map((entry) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                        child: pw.Column(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(16),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(width: 2),
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Image(entry.value, width: 200, height: 200),
                            ),
                            pw.SizedBox(height: 12),
                            pw.Text(
                              entry.key,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    'Scan the QR code for your device to get started',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final fileName = '${_club.name}_App_QR_Codes.pdf'.replaceAll(' ', '_');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${_club.name} - App Download QR Codes',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: const Color(0xFFDA5B5E),
          ),
        );
      }
    }
  }

  /// Generate and download/share QR code as PDF
  Future<void> _downloadQRCodePDF(PokerTable table, String qrCode) async {
    try {
      final qrPainter = QrPainter(
        data: qrCode,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      final qrImageSize = 300.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawRect(
        Rect.fromLTWH(0, 0, qrImageSize, qrImageSize),
        Paint()..color = Colors.white,
      );

      qrPainter.paint(canvas, Size(qrImageSize, qrImageSize));

      final picture = recorder.endRecording();
      final img = await picture.toImage(qrImageSize.toInt(), qrImageSize.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final qrImageBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final qrImage = pw.MemoryImage(qrImageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    _club.name,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    table.name,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Image(qrImage, width: 250, height: 250),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'Scan this QR code to start a session',
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'For dealers only',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final fileName = '${_club.name}_${table.name}_QR.pdf'.replaceAll(' ', '_');
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${table.name} QR Code',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: const Color(0xFFDA5B5E),
          ),
        );
      }
    }
  }

  Future<void> _showInviteMemberDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => InviteMemberDialog(club: _club),
    );

    if (result == true) {
      await _loadData();
    }
  }
}
