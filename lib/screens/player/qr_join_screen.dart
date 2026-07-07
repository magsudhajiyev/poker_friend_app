import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/components/backgrounds/gradient_background.dart';
import '../../l10n/app_localizations.dart';
import '../../models/qr_seat_data.dart';
import '../../models/poker_table.dart';
import '../../models/club.dart';
import '../../models/seat_assignment.dart';
import '../../services/club_service.dart';
import '../../services/table_service.dart';
import '../../services/seat_service.dart';
import 'player_session_screen.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../utils/user_facing_error.dart';

/// Screen for confirming and joining a poker table seat
class QRJoinScreen extends StatefulWidget {
  final QRSeatData qrData;

  const QRJoinScreen({
    Key? key,
    required this.qrData,
  }) : super(key: key);

  @override
  State<QRJoinScreen> createState() => _QRJoinScreenState();
}

class _QRJoinScreenState extends State<QRJoinScreen> {
  bool _isLoading = true;
  bool _isJoining = false;
  bool _isWaitingForApproval = false;
  String? _error;
  Club? _club;
  PokerTable? _table;
  bool _isSeatOccupied = false;
  StreamSubscription? _seatSubscription;

  @override
  void initState() {
    super.initState();
    _loadTableInfo();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTableInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final club = await ClubService.getClub(widget.qrData.clubId);
      if (club == null) throw 'Club not found';

      final table = await TableService.getTable(
        widget.qrData.clubId,
        widget.qrData.tableId,
      );
      if (table == null) throw 'Table not found';

      final seatAssignment = await SeatService.getSeatAssignment(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      );

      setState(() {
        _club = club;
        _table = table;
        _isSeatOccupied = seatAssignment?.isOccupied ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = UserFacingError.message(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _joinSeat() async {
    if (_club == null || _table == null) return;

    setState(() => _isJoining = true);

    try {
      await SeatService.requestJoinSeat(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      );

      setState(() {
        _isJoining = false;
        _isWaitingForApproval = true;
      });

      _seatSubscription = SeatService.watchSeat(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      ).listen((seat) {
        if (!mounted) return;

        if (seat == null || seat.status == SeatStatus.left) {
          setState(() => _isWaitingForApproval = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).qrJoinDeclined,
                style: AppTypography.ibm(color: Colors.white),
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        } else if (seat.status == SeatStatus.joined) {
          _seatSubscription?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerSessionScreen(
                clubId: widget.qrData.clubId,
                tableId: widget.qrData.tableId,
                seatNumber: widget.qrData.seatNumber,
              ),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _isWaitingForApproval = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).qrJoinFailed(UserFacingError.message(e)),
              style: AppTypography.ibm(color: Colors.white),
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _cancelJoinRequest() async {
    try {
      await SeatService.leaveSeat(
        clubId: widget.qrData.clubId,
        tableId: widget.qrData.tableId,
        seatNumber: widget.qrData.seatNumber,
      );
      _seatSubscription?.cancel();
      if (mounted) {
        setState(() => _isWaitingForApproval = false);
      }
    } catch (e) {
      // Ignore errors on cancel
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        onTap: () {
                          if (_isWaitingForApproval) {
                            _cancelJoinRequest();
                          }
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceDark,
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
                        AppLocalizations.of(context).qrJoinTable,
                        style: AppTypography.ibm(
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

                // Body content
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.buttonPrimary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).qrJoinLoading,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    if (_isWaitingForApproval) {
      return _buildWaitingForApproval();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return _buildMainContent();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).qrJoinError,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 15,
                height: 1.44,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
                ),
                child: Text(
                  AppLocalizations.of(context).qrJoinGoBack,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final isActive = _table?.status == TableStatus.active;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Seat hero card
          _buildSeatHeroCard(),

          const SizedBox(height: 28),

          // Info section
          _buildSectionHeader(AppLocalizations.of(context).qrJoinTableInfo),
          const SizedBox(height: 12),
          _buildInfoCard(isActive),

          // Occupied warning
          if (_isSeatOccupied) ...[
            const SizedBox(height: 16),
            _buildOccupiedWarning(),
          ],

          const SizedBox(height: 36),

          // Join button
          _buildJoinButton(),

          const SizedBox(height: 16),

          // Cancel
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  AppLocalizations.of(context).commonCancel,
                  style: AppTypography.ibm(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatHeroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDecorations.radius20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: AppColors.glassyCardBase.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(AppDecorations.radius20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Seat icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.buttonPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_seat_rounded,
                  color: AppColors.buttonPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).qrJoinSeat(widget.qrData.seatNumber),
                style: AppTypography.ibm(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                ),
                child: Text(
                  _table?.name ?? AppLocalizations.of(context).qrJoinTableFallback,
                  style: AppTypography.ibm(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.ibm(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.limeGreen,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInfoCard(bool isActive) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.separatorDark),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.business_rounded,
            label: l10n.qrJoinClubLabel,
            value: _club?.name ?? l10n.commonNotAvailable,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: AppColors.separatorDark, height: 1),
          ),
          _buildInfoRow(
            icon: Icons.table_restaurant_rounded,
            label: l10n.qrJoinTableLabel,
            value: _table?.name ?? l10n.commonNotAvailable,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: AppColors.separatorDark, height: 1),
          ),
          _buildInfoRow(
            icon: Icons.event_seat_rounded,
            label: l10n.qrJoinSeatLabel,
            value: l10n.qrJoinSeat(widget.qrData.seatNumber),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(color: AppColors.separatorDark, height: 1),
          ),
          _buildInfoRow(
            icon: Icons.circle,
            iconSize: 10,
            label: l10n.qrJoinStatusLabel,
            value: isActive ? l10n.qrJoinActiveGame : l10n.qrJoinWaitingStatus,
            valueColor: isActive
                ? AppColors.limeGreen
                : const Color(0xFFFFA726),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    double iconSize = 20,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDisabled, size: iconSize),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textDisabled,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupiedWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(
          color: const Color(0xFFFFA726).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFFA726),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context).qrJoinSeatOccupied,
              style: AppTypography.ibm(
                color: const Color(0xFFFFA726),
                fontSize: 13,
                height: 1.44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForApproval() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing indicator
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.buttonPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: AppColors.buttonPrimary,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              AppLocalizations.of(context).qrJoinWaitingDealer,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).qrJoinRequestSent(widget.qrData.seatNumber),
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                color: AppColors.textMint,
                fontSize: 15,
                height: 1.44,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).qrJoinDealerApproval,
              textAlign: TextAlign.center,
              style: AppTypography.ibm(
                color: AppColors.textDisabled,
                fontSize: 14,
                height: 1.44,
              ),
            ),
            const SizedBox(height: 28),

            // Table info pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(color: AppColors.separatorDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.table_restaurant_rounded,
                    color: AppColors.textDisabled,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _table?.name ?? AppLocalizations.of(context).qrJoinTableFallback,
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.buttonPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                    ),
                    child: Text(
                      AppLocalizations.of(context).qrJoinSeat(widget.qrData.seatNumber),
                      style: AppTypography.ibm(
                        color: AppColors.buttonPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Cancel request
            GestureDetector(
              onTap: () async {
                await _cancelJoinRequest();
                if (mounted) Navigator.pop(context);
              },
              child: Text(
                AppLocalizations.of(context).qrJoinCancelRequest,
                style: AppTypography.ibm(
                  color: AppColors.errorRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return GestureDetector(
      onTap: _isJoining ? null : _joinSeat,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isJoining
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppDecorations.buttonRadius),
        ),
        child: Center(
          child: _isJoining
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Text(
                  AppLocalizations.of(context).qrJoinRequestButton,
                  style: AppTypography.ibm(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: -0.43,
                  ),
                ),
        ),
      ),
    );
  }
}
