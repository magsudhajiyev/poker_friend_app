import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../design_system/components/app_toggle.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/dealer_session.dart';
import '../../models/qr_table_data.dart';
import '../../services/auth_service.dart';
import '../../services/qr_service.dart';
import '../../services/dealer_service.dart';
import '../../services/table_service.dart';
import '../../l10n/app_localizations.dart';
import 'dealer_table_screen.dart';

/// Screen for dealers to scan a table QR code to start dealing at an event
class DealerQRScanScreen extends StatefulWidget {
  final ClubEvent event;
  final Club club;

  const DealerQRScanScreen({
    Key? key,
    required this.event,
    required this.club,
  }) : super(key: key);

  @override
  State<DealerQRScanScreen> createState() => _DealerQRScanScreenState();
}

class _DealerQRScanScreenState extends State<DealerQRScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  String? _lastScannedCode;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code == null || code == _lastScannedCode) continue;

      _lastScannedCode = code;
      _processQRCode(code);
      break;
    }
  }

  Future<void> _processQRCode(String code) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Try to parse as table QR code first
      final tableData = QRService.parseAndValidateTableQR(code);

      String? clubId;
      String? tableId;

      if (tableData != null) {
        // It's a table QR code
        clubId = tableData.clubId;
        tableId = tableData.tableId;
      } else {
        // Try parsing as seat QR code (extract table info from it)
        final seatData = QRService.parseAndValidate(code);
        if (seatData != null) {
          clubId = seatData.clubId;
          tableId = seatData.tableId;
        }
      }

      if (clubId == null || tableId == null) {
        _showError(AppLocalizations.of(context).dealerQrScanInvalidCode);
        return;
      }

      // Validate the table belongs to this event's club
      if (clubId != widget.club.id) {
        _showError(AppLocalizations.of(context).dealerQrScanWrongClub);
        return;
      }

      // Get the table details - try direct ID first, then by name pattern
      var table = await TableService.getTable(clubId, tableId);
      if (table == null) {
        // Try to find by name pattern (e.g., "table_1" -> "Table 1")
        table = await TableService.findTableByNamePattern(clubId, tableId);
      }

      if (table == null) {
        _showError(AppLocalizations.of(context).dealerQrScanTableNotFound);
        return;
      }

      // Ensure the table has a QR code (generate if missing - for existing tables)
      if (table.tableQRCode == null || table.tableQRCode!.isEmpty) {
        final qrCode = await TableService.getOrGenerateTableQRCode(clubId, table.id);
        if (qrCode != null) {
          table = table.copyWith(tableQRCode: qrCode);
        }
      }

      // Validate the table is part of this event (using the actual table ID)
      if (widget.event.tableIds.isNotEmpty &&
          !widget.event.tableIds.contains(table.id)) {
        _showTableNotAssignedError(table);
        return;
      }

      // Check for existing paused session on this table (dealer change)
      final pausedSession = await DealerService.getPausedSessionForTable(
        clubId: widget.club.id,
        tableId: table.id,
      );

      if (pausedSession != null && mounted) {
        // Offer to resume the paused session
        final shouldResume = await _showResumePausedSessionDialog(pausedSession);
        if (shouldResume) {
          await _resumePausedSession(pausedSession, table);
        }
        return;
      }

      // No paused session - show session settings dialog before starting
      if (mounted) {
        _showSessionSettingsDialog(table);
      }
    } catch (e) {
      _showError(AppLocalizations.of(context).dealerQrScanError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          // Reset last scanned after delay to allow rescanning
          Future.delayed(const Duration(seconds: 2), () {
            _lastScannedCode = null;
          });
        });
      }
    }
  }

  void _showSessionSettingsDialog(dynamic table) {
    final isTournament = widget.event.gameType == 'tournament';
    int smallBlind = isTournament ? 100 : 1;
    int bigBlind = isTournament ? 200 : 2;
    bool hasBBante = isTournament;
    String gameType = widget.event.gameType;
    int buttonPosition = 1;
    final sbController = TextEditingController(text: isTournament ? '100' : '1');
    final bbController = TextEditingController(text: isTournament ? '200' : '2');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return Dialog(
          backgroundColor: const Color(0xFF101115),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1B1E24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    l10n.dealerQrScanSessionSettings,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.44,
                    ),
                  ),
                  const SizedBox(height: 13),
                  // Info lines
                  Text(
                    l10n.dealerQrScanTableNameLabel(table.name),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      color: const Color(0xFF8C8C8C),
                      height: 1.44,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dealerQrScanEventNameLabel(widget.event.name),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      color: const Color(0xFF8C8C8C),
                      height: 1.44,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Blinds section
                  Text(
                    l10n.dealerQrScanBlindsLabel,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.44,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Two blind cards side by side
                  Row(
                    children: [
                      Expanded(
                        child: _buildBlindCard(
                          label: l10n.dealerQrScanSmallBlindLabel,
                          controller: sbController,
                          onChanged: (v) => setDialogState(() => smallBlind = v),
                          showDollarSign: !isTournament,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBlindCard(
                          label: l10n.dealerQrScanBigBlindLabel,
                          controller: bbController,
                          onChanged: (v) => setDialogState(() => bigBlind = v),
                          showDollarSign: !isTournament,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // BB Ante toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF02050B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1B1E24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.dealerQrScanBbAnte,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 17,
                            color: Colors.white,
                            height: 1.44,
                          ),
                        ),
                        AppToggle(
                          value: hasBBante,
                          onChanged: (v) => setDialogState(() => hasBBante = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.commonCancel,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      GestureDetector(
                        onTap: () async {
                          // Parse final values from controllers
                          smallBlind = int.tryParse(sbController.text) ?? smallBlind;
                          bigBlind = int.tryParse(bbController.text) ?? bigBlind;
                          Navigator.pop(context);
                          await _startSession(
                            table: table,
                            smallBlind: smallBlind,
                            bigBlind: bigBlind,
                            hasBBante: hasBBante,
                            gameType: gameType,
                            buttonPosition: buttonPosition,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF89F1EC),
                            borderRadius: BorderRadius.circular(110),
                          ),
                          child: Text(
                            l10n.dealerQrScanStartDealingBtn,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildBlindCard({
    required String label,
    required TextEditingController controller,
    required Function(int) onChanged,
    bool showDollarSign = true,
  }) {
    return Container(
      height: 124,
      decoration: BoxDecoration(
        color: const Color(0xFF02050B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1B1E24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8C8C8C),
              height: 1.44,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4E5054)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4E5054)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF89F1EC)),
              ),
              prefixText: showDollarSign ? '\$' : null,
              prefixStyle: GoogleFonts.ibmPlexSans(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8C8C8C),
                height: 1.44,
              ),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startSession({
    required dynamic table,
    required int smallBlind,
    required int bigBlind,
    required bool hasBBante,
    required String gameType,
    required int buttonPosition,
  }) async {
    setState(() => _isProcessing = true);

    try {
      // Start dealer session (eventId is automatically detected)
      final session = await DealerService.startSession(
        clubId: widget.club.id,
        tableId: table.id,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        hasBBante: hasBBante,
        gameType: gameType,
        buttonPosition: buttonPosition,
      );

      if (mounted) {
        // Navigate to dealer table screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DealerTableScreen(
              session: session,
              club: widget.club,
              table: table,
            ),
          ),
        );
      }
    } catch (e) {
      _showError(AppLocalizations.of(context).dealerQrScanFailedStart(e.toString()));
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: PokerFriendColors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show dialog to resume a paused session (dealer change handoff)
  Future<bool> _showResumePausedSessionDialog(DealerSession session) async {
    final activePlayers = session.players.values.where((p) => p.isActive).length;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = AppLocalizations.of(context);
        return Dialog(
        backgroundColor: const Color(0xFF101115),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1B1E24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B1E24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_vert,
                      color: Color(0xFF89F1EC),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dialogL10n.dealerQrScanResumeSessionTitle,
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dialogL10n.dealerQrScanTakingOverFrom(session.dealerName ?? dialogL10n.dealerTableDealerFallback),
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFFD3FFFD),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              // Stats rows
              _buildResumeInfoRow(dialogL10n.dealerQrScanHandsPlayedLabel, '${session.currentHandNumber}'),
              const Divider(color: Color(0xFF1B1E24), height: 1),
              _buildResumeInfoRow(dialogL10n.dealerQrScanBlindsInfoLabel, '${session.smallBlind}/${session.bigBlind}'),
              const Divider(color: Color(0xFF1B1E24), height: 1),
              _buildResumeInfoRow(dialogL10n.dealerQrScanPlayersLabel, '$activePlayers'),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(
                          dialogL10n.commonCancel,
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF89F1EC),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Text(
                        dialogL10n.dealerQrScanResumeBtn,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
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
      },
    );
    return result ?? false;
  }

  Widget _buildResumeInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.ibmPlexSans(color: const Color(0xFF8C8C8C), fontSize: 14)),
          Text(value, style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// Resume a paused session with new dealer
  Future<void> _resumePausedSession(DealerSession session, dynamic table) async {
    setState(() => _isProcessing = true);

    try {
      // Update dealer info and resume
      await DealerService.resumeSessionWithNewDealer(
        sessionId: session.id,
        newDealerId: AuthService.userId!,
        newDealerName: AuthService.userDisplayName,
      );

      // Navigate to dealer table screen with updated session
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DealerTableScreen(
              session: session.copyWith(
                dealerId: AuthService.userId!,
                dealerName: AuthService.userDisplayName,
                status: DealerSessionStatus.active,
              ),
              club: widget.club,
              table: table,
            ),
          ),
        );
      }
    } catch (e) {
      _showError(AppLocalizations.of(context).dealerQrScanFailedResume(e.toString()));
      setState(() => _isProcessing = false);
    }
  }

  void _showTableNotAssignedError(dynamic table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: PokerFriendColors.yellow),
            SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).dealerQrScanTableNotAssigned,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).dealerQrTableNotAssigned(table.name),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).dealerQrScanEventTablesLabel,
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.event.tableIds.isEmpty
                  ? AppLocalizations.of(context).dealerQrScanNoTablesAssigned
                  : widget.event.tableIds.join(', '),
              style: TextStyle(
                color: PokerFriendColors.dark11,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).dealerQrScanThisTableId,
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 4),
            SelectableText(
              table.id,
              style: TextStyle(
                color: PokerFriendColors.green,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            if (table.tableQRCode != null) ...[
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).dealerQrScanCorrectQrUrl,
                style: TextStyle(
                  color: PokerFriendColors.dark9,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),
              SelectableText(
                table.tableQRCode!,
                style: TextStyle(
                  color: PokerFriendColors.purple,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).commonOk,
              style: TextStyle(color: PokerFriendColors.purple),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).dealerQrScanScanTableQrTitle,
              style: TextStyle(fontSize: 18),
            ),
            Text(
              widget.event.name,
              style: TextStyle(
                fontSize: 12,
                color: PokerFriendColors.purple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scan overlay
          _buildScanOverlay(),

          // Instructions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: PokerFriendColors.green,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).dealerQrScanScanInstructions,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.event.tableIds.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).dealerQrTablesAssigned(widget.event.tableIds.length),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: PokerFriendColors.dark9,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_isProcessing)
                  const CircularProgressIndicator(
                    color: PokerFriendColors.green,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final scanAreaLeft = (constraints.maxWidth - scanAreaSize) / 2;
        final scanAreaTop = (constraints.maxHeight - scanAreaSize) / 2;

        return Stack(
          children: [
            // Darkened areas around scan zone
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: scanAreaLeft,
                    top: scanAreaTop,
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scan area border
            Positioned(
              left: scanAreaLeft,
              top: scanAreaTop,
              child: Container(
                width: scanAreaSize,
                height: scanAreaSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isProcessing ? PokerFriendColors.green : Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Corner indicators
            ..._buildCornerIndicators(scanAreaLeft, scanAreaTop, scanAreaSize),
          ],
        );
      },
    );
  }

  List<Widget> _buildCornerIndicators(
    double left,
    double top,
    double size,
  ) {
    const cornerSize = 30.0;
    const cornerWidth = 4.0;
    final color = _isProcessing ? PokerFriendColors.green : Colors.white;

    return [
      // Top-left
      Positioned(
        left: left - cornerWidth / 2,
        top: top - cornerWidth / 2,
        child: _buildCorner(color, cornerSize, cornerWidth, topLeft: true),
      ),
      // Top-right
      Positioned(
        right: left - cornerWidth / 2,
        top: top - cornerWidth / 2,
        child: _buildCorner(color, cornerSize, cornerWidth, topRight: true),
      ),
      // Bottom-left
      Positioned(
        left: left - cornerWidth / 2,
        bottom: top - cornerWidth / 2,
        child: _buildCorner(color, cornerSize, cornerWidth, bottomLeft: true),
      ),
      // Bottom-right
      Positioned(
        right: left - cornerWidth / 2,
        bottom: top - cornerWidth / 2,
        child: _buildCorner(color, cornerSize, cornerWidth, bottomRight: true),
      ),
    ];
  }

  Widget _buildCorner(
    Color color,
    double size,
    double width, {
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          strokeWidth: width,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    if (topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (bottomRight) {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
