import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/poker_table.dart';
import '../../services/event_service.dart';
import '../../services/table_service.dart';
import '../../services/club_notification_service.dart';
import '../../design_system/components/calendar/custom_date_picker.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/constants/decorations.dart';
import '../../utils/user_facing_error.dart';

/// Shows the Create/Edit Event drawer as a modal bottom sheet.
/// Returns true if event was created/updated, null otherwise.
Future<bool?> showCreateEventDrawer(BuildContext context, {
  required Club club,
  ClubEvent? event,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreateEventDrawer(club: club, event: event),
  );
}

/// Drawer for creating or editing a club event.
/// Matches the New Event drawer pattern from calendar_screen.dart.
class CreateEventDrawer extends StatefulWidget {
  final Club club;
  final ClubEvent? event;

  const CreateEventDrawer({
    Key? key,
    required this.club,
    this.event,
  }) : super(key: key);

  @override
  State<CreateEventDrawer> createState() => _CreateEventDrawerState();
}

class _CreateEventDrawerState extends State<CreateEventDrawer> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _buyInController = TextEditingController();
  final _startingStackController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  bool _notifyMembers = true;
  bool _isSubmitting = false;
  bool _showValidationErrors = false;
  String _gameType = 'tournament';

  List<PokerTable> _availableTables = [];
  Set<String> _selectedTableIds = {};
  bool _isLoadingTables = true;
  int _totalTablesCount = 0;

  bool get _isEditMode => widget.event != null;

  bool get _isFormValid {
    if (_nameController.text.trim().isEmpty) return false;
    if (_buyInController.text.trim().isEmpty) return false;
    if (_startingStackController.text.trim().isEmpty) return false;
    return true;
  }

  bool _isFieldEmpty(TextEditingController controller) =>
      _showValidationErrors && controller.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _loadTables();
    _initializeFormFields();
    _nameController.addListener(_onFieldChanged);
    _buyInController.addListener(_onFieldChanged);
    _startingStackController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {
      // Clear validation errors once form becomes valid
      if (_showValidationErrors && _isFormValid) {
        _showValidationErrors = false;
      }
    });
  }

  void _initializeFormFields() {
    if (_isEditMode) {
      final event = widget.event!;
      _nameController.text = event.name;
      _descriptionController.text = event.description ?? '';

      if (event.gameType == 'cash') {
        _buyInController.text = event.stakes ?? '';
        _startingStackController.text = event.startingStack?.toStringAsFixed(0) ?? '';
      } else {
        _buyInController.text = event.buyInAmount?.toString() ?? '';
        _startingStackController.text = event.startingStack?.toString() ?? '';
      }

      _selectedDate = event.startTime;
      _selectedTime = TimeOfDay.fromDateTime(event.startTime);
      _notifyMembers = false;
      _gameType = event.gameType;
      _selectedTableIds = event.tableIds.toSet();
    }
  }

  Future<void> _loadTables() async {
    try {
      final tables = await TableService.getTables(widget.club.id);
      final totalCount = tables.length;

      final allEvents = await EventService.getClubEvents(widget.club.id);
      final runningEvents = allEvents.where((e) =>
        e.status == EventStatus.active || e.status == EventStatus.paused
      );

      final Set<String> usedTableIds = {};
      for (final event in runningEvents) {
        usedTableIds.addAll(event.tableIds);
      }

      final currentEventTableIds = _isEditMode ? widget.event!.tableIds.toSet() : <String>{};
      final availableTables = tables.where((t) =>
        !usedTableIds.contains(t.id) || currentEventTableIds.contains(t.id)
      ).toList();

      if (mounted) {
        setState(() {
          _availableTables = availableTables;
          _totalTablesCount = totalCount;
          _isLoadingTables = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTables = false);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _buyInController.removeListener(_onFieldChanged);
    _startingStackController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _buyInController.dispose();
    _startingStackController.dispose();
    super.dispose();
  }

  DateTime get _eventDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _submitEvent() async {
    // Validate tournament name
    if (_gameType == 'tournament' && _nameController.text.trim().isEmpty) {
      return;
    }

    // Warn if no tables assigned
    if (_selectedTableIds.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.neutral800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDecorations.radius18),
          ),
          title: Text(
            AppLocalizations.of(context).eventNoTablesAssigned,
            style: AppTypography.ibm(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).eventNoTablesAssignedDesc,
            style: AppTypography.ibm(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppLocalizations.of(context).eventGoBack,
                style: AppTypography.ibm(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.buttonPrimary,
              ),
              child: Text(
                AppLocalizations.of(context).eventContinue,
                style: AppTypography.ibm(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      double? buyIn;
      double? startingStack;
      String? stakes;

      if (_gameType == 'cash') {
        stakes = _buyInController.text.trim().isNotEmpty
            ? _buyInController.text.trim()
            : null;
        startingStack = _startingStackController.text.isNotEmpty
            ? double.tryParse(_startingStackController.text)
            : null;
      } else {
        buyIn = _buyInController.text.isNotEmpty
            ? double.tryParse(_buyInController.text)
            : null;
        startingStack = _startingStackController.text.isNotEmpty
            ? double.tryParse(_startingStackController.text)
            : null;
      }

      String eventName = _nameController.text.trim();
      if (_gameType == 'cash' && eventName.isEmpty) {
        eventName = stakes != null && stakes.isNotEmpty
            ? AppLocalizations.of(context).createEventDefaultCashGame(stakes)
            : AppLocalizations.of(context).createEventDefaultCashGameNoStakes;
      }

      if (_isEditMode) {
        await EventService.updateEvent(
          widget.club.id,
          widget.event!.id,
          name: eventName,
          startTime: _eventDateTime,
          description: description ?? '',
          buyInAmount: buyIn ?? 0,
          startingStack: startingStack ?? 0,
          stakes: stakes,
          tableIds: _selectedTableIds.toList(),
          gameType: _gameType,
          notifyMembers: _notifyMembers,
        );

        // Send edit notification in background — don't block the drawer close
        if (_notifyMembers) {
          EventService.getEvent(widget.club.id, widget.event!.id).then((updatedEvent) {
            if (updatedEvent != null) {
              ClubNotificationService.notifyEventUpdated(
                clubId: widget.club.id,
                event: updatedEvent,
              );
            }
          }).catchError((_) {});
        }
      } else {
        await EventService.createEventWithDetails(
          clubId: widget.club.id,
          name: eventName,
          startTime: _eventDateTime,
          description: description,
          buyInAmount: buyIn,
          startingStack: startingStack,
          stakes: stakes,
          notifyMembers: _notifyMembers,
          tableIds: _selectedTableIds.toList(),
          gameType: _gameType,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      debugPrint('Error creating/updating event: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: const Color(0xFF262626), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E5A59),
            blurRadius: 64,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (fixed at top)
          _buildDrawerHeader(),
          const SizedBox(height: 24),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom + 32,
              ),
              child: Column(
                children: [
                  // Form Card 1 - Game Type (chosen first, changes field labels below)
                  _buildGameTypeCard(),
                  const SizedBox(height: 14),
                  // Form Card 2 - Basic fields
                  _buildBasicFieldsCard(),
                  const SizedBox(height: 14),
                  // Form Card 3 - Date/Time
                  _buildDateTimeCard(),
                  const SizedBox(height: 14),
                  // Form Card 4 - Tables
                  _buildTablesCard(),
                  const SizedBox(height: 14),
                  // Form Card 5 - Description
                  _buildDescriptionCard(),
                  const SizedBox(height: 14),
                  // Notify toggle
                  _buildNotifyCard(),
                  // Delete button (edit mode only)
                  if (_isEditMode) ...[
                    const SizedBox(height: 24),
                    _buildDeleteEventButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.neutral700,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Title
          Text(
            _isEditMode ? AppLocalizations.of(context).eventEditTitle : AppLocalizations.of(context).eventNewTitle,
            style: AppTypography.ibm(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.43,
            ),
          ),
          // Confirm button
          GestureDetector(
            onTap: _isSubmitting
                ? null
                : () {
                    if (!_isFormValid) {
                      setState(() => _showValidationErrors = true);
                      return;
                    }
                    _submitEvent();
                  },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _isSubmitting
                    ? const Color(0xFF54E98A).withValues(alpha: 0.5)
                    : _isFormValid
                        ? const Color(0xFF54E98A)
                        : AppColors.neutral700,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Icon(Icons.check,
                        color: _isFormValid ? Colors.black : AppColors.textDisabled,
                        size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFieldsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // Event Name
            _buildCardTextField(
              controller: _nameController,
              hint: _gameType == 'cash'
                  ? AppLocalizations.of(context).eventNameOptional
                  : AppLocalizations.of(context).eventNameLabel,
              showError: _isFieldEmpty(_nameController),
            ),
            _buildSeparator(),
            // Buy-in / Stakes
            _buildCardTextField(
              controller: _buyInController,
              hint: _gameType == 'cash' ? AppLocalizations.of(context).eventStakesHint : AppLocalizations.of(context).eventBuyInAmount,
              keyboardType: _gameType == 'cash'
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _gameType == 'cash'
                  ? null
                  : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              showError: _isFieldEmpty(_buyInController),
            ),
            _buildSeparator(),
            // Starting Stack / Min Buy-in
            _buildCardTextField(
              controller: _startingStackController,
              hint: _gameType == 'cash' ? AppLocalizations.of(context).eventMinBuyIn : AppLocalizations.of(context).eventStartingStack,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              showError: _isFieldEmpty(_startingStackController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTypeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).eventGameType,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.43,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 0.5, color: const Color(0xFF545458)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildGameTypePill(AppLocalizations.of(context).eventTournament, 'tournament'),
                const SizedBox(width: 8),
                _buildGameTypePill(AppLocalizations.of(context).eventCashGame, 'cash'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTypePill(String label, String value) {
    final isSelected = _gameType == value;
    return GestureDetector(
      onTap: () => setState(() => _gameType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.neutral800 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
          border: Border.all(
            color: isSelected ? AppColors.buttonPrimary : AppColors.neutral700,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.ibm(
            color: isSelected ? AppColors.buttonPrimary : AppColors.textDisabled,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).eventDateAndTime,
              style: AppTypography.ibm(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.43,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 0.5, color: const Color(0xFF545458)),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  AppLocalizations.of(context).eventStarts,
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.44,
                  ),
                ),
                const Spacer(),
                // Date Pill
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.neutral800,
                      borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                    ),
                    child: Text(
                      DateFormat('d MMM yyyy').format(_selectedDate),
                      style: AppTypography.ibm(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Time Pill
                GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.neutral800,
                      borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                    ),
                    child: Text(
                      _selectedTime.format(context),
                      style: AppTypography.ibm(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
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
  }

  Widget _buildTablesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).eventTables,
                  style: AppTypography.ibm(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.43,
                  ),
                ),
                if (_availableTables.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedTableIds.length == _availableTables.length) {
                          _selectedTableIds.clear();
                        } else {
                          _selectedTableIds = _availableTables.map((t) => t.id).toSet();
                        }
                      });
                    },
                    child: Text(
                      _selectedTableIds.length == _availableTables.length
                          ? AppLocalizations.of(context).eventDeselectAll
                          : AppLocalizations.of(context).eventSelectAll,
                      style: AppTypography.ibm(
                        color: AppColors.buttonPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 0.5, color: const Color(0xFF545458)),
            const SizedBox(height: 12),
            if (_isLoadingTables)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.buttonPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (_availableTables.isEmpty)
              Text(
                _totalTablesCount > 0
                    ? AppLocalizations.of(context).eventAllTablesInUse
                    : AppLocalizations.of(context).eventNoTablesConfigured,
                style: AppTypography.ibm(
                  color: AppColors.textDisabled,
                  fontSize: 15,
                  height: 1.44,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTables.map((table) {
                  final isSelected = _selectedTableIds.contains(table.id);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTableIds.remove(table.id);
                        } else {
                          _selectedTableIds.add(table.id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.mint900
                            : AppColors.neutral800,
                        borderRadius: BorderRadius.circular(AppDecorations.pillRadius),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.buttonPrimary
                              : AppColors.neutral700,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? AppColors.buttonPrimary
                                : AppColors.textDisabled,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            table.name,
                            style: AppTypography.ibm(
                              color: isSelected ? Colors.white : AppColors.textDisabled,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildCardTextField(
          controller: _descriptionController,
          hint: AppLocalizations.of(context).eventDescriptionLabel,
          maxLines: null,
          minLines: 3,
        ),
      ),
    );
  }

  Widget _buildNotifyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.neutral800,
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: AppColors.buttonPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).eventNotifyMembers,
                    style: AppTypography.ibm(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).eventNotifyMembersSubtitle,
                    style: AppTypography.ibm(
                      color: AppColors.textDisabled,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _notifyMembers,
              onChanged: (value) => setState(() => _notifyMembers = value),
              activeColor: AppColors.buttonPrimary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.neutral700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteEventButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
      onTap: _deleteEvent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.lossRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
          border: Border.all(
            color: AppColors.lossRed.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delete_outline,
              color: AppColors.lossRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).eventDeleteEvent,
              style: AppTypography.ibm(
                fontSize: 17,
                color: AppColors.lossRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.neutral800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius18),
        ),
        title: Text(
          AppLocalizations.of(context).eventDeleteConfirmTitle,
          style: AppTypography.ibm(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          AppLocalizations.of(context).eventDeleteConfirmBody,
          style: AppTypography.ibm(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalizations.of(context).commonCancel,
              style: AppTypography.ibm(
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lossRed,
            ),
            child: Text(
              AppLocalizations.of(context).commonDelete,
              style: AppTypography.ibm(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await EventService.deleteEvent(widget.club.id, widget.event!.id);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).eventDeleteFailed('${UserFacingError.message(e)}')),
              backgroundColor: AppColors.lossRed,
            ),
          );
        }
      }
    }
  }

  Widget _buildCardTextField({
    required TextEditingController controller,
    required String hint,
    int? maxLines = 1,
    int? minLines,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool showError = false,
  }) {
    return Container(
      decoration: showError
          ? BoxDecoration(
              border: Border.all(color: AppColors.lossRed, width: 1),
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
            )
          : null,
      margin: showError ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: AppTypography.ibm(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          height: 1.44,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.ibm(
            color: showError ? AppColors.lossRed.withValues(alpha: 0.7) : AppColors.textDisabled,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.44,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: AppColors.separatorDark,
    );
  }

  Future<void> _selectDate() async {
    // Use the shared custom date picker (same one used by the calendar
    // screen for adding a calendar event) instead of Flutter's default.
    final now = DateTime.now();
    final initial = _selectedDate.isBefore(DateTime(now.year, now.month, now.day))
        ? now
        : _selectedDate;
    final picked = await showCustomDatePicker(
      context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5CD9A4),
              surface: AppColors.neutral800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }
}

/// Legacy wrapper — keeps the old CreateEventScreen API working.
/// Internally shows the drawer when built.
class CreateEventScreen extends StatelessWidget {
  final Club club;
  final ClubEvent? event;

  const CreateEventScreen({
    Key? key,
    required this.club,
    this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Immediately show drawer and pop this screen when done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCreateEventDrawer(context, club: club, event: event).then((result) {
        Navigator.pop(context, result);
      });
    });

    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: SizedBox.shrink(),
    );
  }
}
