import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_member.dart';
import '../../models/poker_table.dart';
import '../../services/club_service.dart';
import '../../services/table_service.dart';

/// Club settings screen for admins to manage club info, tables, and members
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
            backgroundColor: PokerFriendColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokerFriendColors.dark1,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PokerFriendColors.purple,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: PokerFriendColors.purple,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildClubInfoSection(),
                            const SizedBox(height: 32),
                            _buildTablesSection(),
                            const SizedBox(height: 32),
                            _buildMembersSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Club Settings',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // ========== Club Info Section ==========

  Widget _buildClubInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Club Information'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PokerFriendColors.dark3,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Club Name',
                icon: Icons.home,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveClubInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PokerFriendColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: PokerFriendColors.dark9),
        prefixIcon: Icon(icon, color: PokerFriendColors.dark9),
        filled: true,
        fillColor: PokerFriendColors.dark5,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PokerFriendColors.purple),
        ),
      ),
    );
  }

  // ========== Tables Section ==========

  Widget _buildTablesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Tables',
          trailing: GestureDetector(
            onTap: _showAddTableDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: PokerFriendColors.purple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_tables.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.table_restaurant,
                  size: 48,
                  color: PokerFriendColors.dark7,
                ),
                const SizedBox(height: 12),
                Text(
                  'No tables yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: PokerFriendColors.dark9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a table to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: PokerFriendColors.dark7,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_tables.length, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index < _tables.length - 1 ? 12 : 0),
              child: _buildTableCard(_tables[index]),
            );
          }),
      ],
    );
  }

  Widget _buildTableCard(PokerTable table) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PokerFriendColors.dark5,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${table.tableNumber}',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  table.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: table.status == TableStatus.active
                        ? PokerFriendColors.green
                        : PokerFriendColors.dark9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // QR button
          _buildIconButton(
            icon: Icons.qr_code,
            color: PokerFriendColors.purple,
            onTap: () => _showTableQRDialog(table),
          ),
          const SizedBox(width: 8),
          // Edit button
          _buildIconButton(
            icon: Icons.edit,
            color: PokerFriendColors.blue,
            onTap: () => _showEditTableDialog(table),
          ),
          const SizedBox(width: 8),
          // Delete button
          _buildIconButton(
            icon: Icons.delete,
            color: PokerFriendColors.red,
            onTap: () => _confirmDeleteTable(table),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Future<void> _showAddTableDialog() async {
    final nameController = TextEditingController(text: 'Table ${_tables.length + 1}');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Table',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Table Name',
            labelStyle: TextStyle(color: PokerFriendColors.dark9),
            filled: true,
            fillColor: PokerFriendColors.dark5,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: PokerFriendColors.dark9)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
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
              backgroundColor: PokerFriendColors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: PokerFriendColors.red),
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
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Table',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Table Name',
            labelStyle: TextStyle(color: PokerFriendColors.dark9),
            filled: true,
            fillColor: PokerFriendColors.dark5,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: PokerFriendColors.dark9)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: PokerFriendColors.red),
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
        backgroundColor: PokerFriendColors.dark3,
        title: const Text('Delete Table?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${table.name}"? This cannot be undone.',
          style: TextStyle(color: PokerFriendColors.dark11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: PokerFriendColors.red),
            child: const Text('Delete'),
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
            SnackBar(content: Text('Error: $e'), backgroundColor: PokerFriendColors.red),
          );
        }
      }
    }
  }

  Future<void> _showTableQRDialog(PokerTable table) async {
    // Get the table with QR code
    final tableWithQR = await TableService.getTableWithQRCode(_club.id, table.id);
    final qrCode = tableWithQR?.tableQRCode;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${table.name} QR Code',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                const Text(
                  'QR code not available',
                  style: TextStyle(color: Colors.white),
                ),
              const SizedBox(height: 16),
              Text(
                'Dealers scan this to start a session at this table',
                style: TextStyle(
                  fontSize: 14,
                  color: PokerFriendColors.dark9,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          // Download PDF button
          if (qrCode != null)
            TextButton.icon(
              onPressed: () => _downloadQRCodePDF(table, qrCode),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('PDF'),
              style: TextButton.styleFrom(
                foregroundColor: PokerFriendColors.green,
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
                      backgroundColor: PokerFriendColors.green,
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
            child: Text('Regenerate', style: TextStyle(color: PokerFriendColors.yellow)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Generate and download/share QR code as PDF
  Future<void> _downloadQRCodePDF(PokerTable table, String qrCode) async {
    try {
      // Generate QR code image bytes
      final qrPainter = QrPainter(
        data: qrCode,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      final qrImageSize = 300.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw white background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, qrImageSize, qrImageSize),
        Paint()..color = Colors.white,
      );

      // Draw QR code
      qrPainter.paint(canvas, Size(qrImageSize, qrImageSize));

      final picture = recorder.endRecording();
      final img = await picture.toImage(qrImageSize.toInt(), qrImageSize.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final qrImageBytes = byteData!.buffer.asUint8List();

      // Create PDF document
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
                  // Club name
                  pw.Text(
                    _club.name,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // Table name
                  pw.Text(
                    table.name,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  // QR Code
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Image(qrImage, width: 250, height: 250),
                  ),
                  pw.SizedBox(height: 30),
                  // Instructions
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

      // Save PDF to temp directory and share
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
            backgroundColor: PokerFriendColors.red,
          ),
        );
      }
    }
  }

  // ========== Members Section ==========

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Members (${_members.length})'),
        const SizedBox(height: 16),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'No members found',
              style: TextStyle(color: PokerFriendColors.dark9),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: PokerFriendColors.dark3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(_members.length, (index) {
                final member = _members[index];
                return Column(
                  children: [
                    _buildMemberRow(member),
                    if (index < _members.length - 1)
                      Divider(
                        height: 1,
                        color: PokerFriendColors.dark5,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getRoleColor(member.role).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (member.displayName ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  color: _getRoleColor(member.role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (member.email != null)
                  Text(
                    member.email!,
                    style: TextStyle(
                      fontSize: 13,
                      color: PokerFriendColors.dark9,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(member.role).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.role.name.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: _getRoleColor(member.role),
                fontWeight: FontWeight.w600,
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
        return PokerFriendColors.yellow;
      case ClubRole.admin:
        return PokerFriendColors.purple;
      case ClubRole.dealer:
        return PokerFriendColors.blue;
      case ClubRole.player:
        return PokerFriendColors.green;
    }
  }
}
