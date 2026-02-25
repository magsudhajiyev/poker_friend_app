import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/dealer_session.dart';
import '../../models/qr_table_data.dart';
import '../../services/auth_service.dart';
import '../../services/qr_service.dart';
import '../../services/dealer_service.dart';
import '../../services/table_service.dart';
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
        _showError('Invalid QR code. Please scan a valid table QR code.');
        return;
      }

      // Validate the table belongs to this event's club
      if (clubId != widget.club.id) {
        _showError('This table belongs to a different club.');
        return;
      }

      // Get the table details - try direct ID first, then by name pattern
      var table = await TableService.getTable(clubId, tableId);
      if (table == null) {
        // Try to find by name pattern (e.g., "table_1" -> "Table 1")
        table = await TableService.findTableByNamePattern(clubId, tableId);
      }

      if (table == null) {
        _showError('Table not found. Please scan a valid table QR code.');
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
      _showError('Error processing QR code: ${e.toString()}');
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
    int smallBlind = 1;
    int bigBlind = 2;
    bool hasBBante = false;
    String gameType = 'cash';
    int buttonPosition = 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: PokerFriendColors.dark3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Session Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table: ${table.name}',
                  style: TextStyle(
                    color: PokerFriendColors.dark11,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Event: ${widget.event.name}',
                  style: TextStyle(
                    color: PokerFriendColors.purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 24),

                // Blinds
                Text(
                  'Blinds',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        label: 'Small',
                        value: smallBlind,
                        onChanged: (v) => setDialogState(() => smallBlind = v),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        label: 'Big',
                        value: bigBlind,
                        onChanged: (v) => setDialogState(() => bigBlind = v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // BB Ante toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BB Ante',
                      style: TextStyle(color: Colors.white),
                    ),
                    Switch(
                      value: hasBBante,
                      onChanged: (v) => setDialogState(() => hasBBante = v),
                      activeColor: PokerFriendColors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: PokerFriendColors.dark9),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: PokerFriendColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Dealing',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
    int min = 1,
    int max = 100000,
  }) {
    return GestureDetector(
      onTap: () => _showNumberInputDialog(
        label: label,
        currentValue: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark5,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PokerFriendColors.dark7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNumberInputDialog({
    required String label,
    required int currentValue,
    required int min,
    required int max,
    required Function(int) onChanged,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Enter $label',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: PokerFriendColors.dark5,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null && parsed >= min && parsed <= max) {
              Navigator.pop(context, parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: PokerFriendColors.dark9),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null && parsed >= min && parsed <= max) {
                Navigator.pop(context, parsed);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid number between $min and $max'),
                    backgroundColor: PokerFriendColors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokerFriendColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      onChanged(result);
    }

    // Note: Don't dispose controller here - it can cause "used after disposed" error
    // if the dialog is still animating. Controller will be garbage collected.
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
      _showError('Failed to start session: ${e.toString()}');
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PokerFriendColors.dark3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange),
            SizedBox(width: 12),
            Text(
              'Resume Session',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taking over from ${session.dealerName ?? "previous dealer"}',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildResumeInfoRow('Hands Played', '${session.currentHandNumber}'),
            _buildResumeInfoRow('Blinds', '${session.smallBlind}/${session.bigBlind}'),
            _buildResumeInfoRow('Players', '${session.players.values.where((p) => p.isActive).length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: PokerFriendColors.dark9)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Resume'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildResumeInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: PokerFriendColors.dark9)),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
      _showError('Failed to resume session: ${e.toString()}');
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
              'Table Not Assigned',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${table.name} is not assigned to this event.',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Event tables:',
              style: TextStyle(
                color: PokerFriendColors.dark9,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.event.tableIds.isEmpty
                  ? 'No tables assigned'
                  : widget.event.tableIds.join(', '),
              style: TextStyle(
                color: PokerFriendColors.dark11,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 16),
            Text(
              'This table\'s ID:',
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
                'Correct QR code URL:',
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
              'OK',
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
              'Scan Table QR',
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
                        'Scan the table QR code to start dealing',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.event.tableIds.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          '${widget.event.tableIds.length} table(s) assigned to this event',
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
