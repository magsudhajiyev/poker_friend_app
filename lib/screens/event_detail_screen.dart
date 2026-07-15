import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../design_system/constants/colors.dart';
import '../design_system/constants/typography.dart';
import '../design_system/constants/decorations.dart';

/// Event detail screen matching Figma node 158:2943
/// Shows event title, date/time, details card, and delete button
class EventDetailScreen extends StatefulWidget {
  final String title;
  final String type;
  final String location;
  final DateTime date;
  final double buyIn;
  final VoidCallback? onDelete;
  /// Called when user taps Edit. Receives a callback to update the displayed data.
  final void Function(void Function({
    required String title,
    required String type,
    required String location,
    required DateTime date,
    required double buyIn,
  }) updateDetail)? onEdit;

  const EventDetailScreen({
    Key? key,
    required this.title,
    required this.type,
    required this.location,
    required this.date,
    required this.buyIn,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late String _title;
  late String _type;
  late String _location;
  late DateTime _date;
  late double _buyIn;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _type = widget.type;
    _location = widget.location;
    _date = widget.date;
    _buyIn = widget.buyIn;
  }

  void _updateFromEdit({
    required String title,
    required String type,
    required String location,
    required DateTime date,
    required double buyIn,
  }) {
    setState(() {
      _title = title;
      _type = type;
      _location = location;
      _date = date;
      _buyIn = buyIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          // Main content (rendered before header so header stays on top for taps)
          Positioned.fill(
            top: 0,
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 80,
                  bottom: MediaQuery.of(context).padding.bottom + 120,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _title,
                        style: AppTypography.ibm(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -1,
                          height: 1.36,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Date line
                      Text(
                        DateFormat('EEEE, d MMM yyyy').format(_date),
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.44,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Time line
                      Text(
                        DateFormat('HH:mm').format(_date),
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.44,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Details card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.infoCardBg,
                          borderRadius: BorderRadius.circular(AppDecorations.radius18),
                        ),
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                _buildListRow(l10n.calendarEventType, _type),
                                _buildSeparator(),
                                _buildListRow(l10n.calendarEventLocation, _location.isNotEmpty ? _location : '-'),
                                _buildSeparator(),
                                _buildListRow(l10n.calendarEventBuyIn, _buyIn > 0 ? CurrencyService.formatCash(_buyIn) : '-'),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Header bar (on top of scroll content for tap handling)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.01),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back pill with chevron + month name
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                              decoration: BoxDecoration(
                                color: AppColors.neutral800,
                                borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Center(
                                      child: Text(
                                        '‹',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMMM').format(_date),
                                    style: AppTypography.ibm(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                      height: 1.44,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Edit pill
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context);
                              return GestureDetector(
                                onTap: () => widget.onEdit?.call(_updateFromEdit),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.neutral800,
                                    borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                                  ),
                                  child: Center(
                                    child: Text(
                                      l10n.calendarEventEdit,
                                      style: AppTypography.ibm(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white,
                                        height: 1.44,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Delete button pinned above nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDA5B5E),
                            borderRadius: BorderRadius.circular(AppDecorations.navBarRadius),
                          ),
                          child: Text(
                            l10n.calendarEventDelete,
                            style: AppTypography.ibm(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.44,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppDecorations.radius18),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          sheetL10n.calendarEventDeleteConfirm(_title),
                          textAlign: TextAlign.center,
                          style: AppTypography.ibm(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          sheetL10n.calendarEventDeleteBody(_title),
                          textAlign: TextAlign.center,
                          style: AppTypography.ibm(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                          child: Text(
                            sheetL10n.calendarEventDeleteButton,
                            textAlign: TextAlign.center,
                            style: AppTypography.ibm(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDA5B5E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Cancel card
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: Text(
                        sheetL10n.commonCancel,
                        style: AppTypography.ibm(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        widget.onDelete?.call();
        Navigator.pop(context, true);
      }
    });
  }

  Widget _buildListRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.44,
            ),
          ),
          Text(
            value,
            style: AppTypography.ibm(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 1.44,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 1,
        color: AppColors.separatorDark,
      ),
    );
  }
}
