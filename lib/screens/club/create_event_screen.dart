import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/poker_table.dart';
import '../../services/event_service.dart';
import '../../services/table_service.dart';
import '../../services/club_notification_service.dart';

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
            ? 'Cash Game $stakes'
            : 'Cash Game';
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
      print('Error creating/updating event: $e');
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
                  // Form Card 1 - Basic fields
                  _buildBasicFieldsCard(),
                  const SizedBox(height: 14),
                  // Form Card 2 - Game Type
                  _buildGameTypeCard(),
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
                color: Color(0xFF35373C),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          // Title
          Text(
            _isEditMode ? 'Edit Event' : 'New Event',
            style: GoogleFonts.ibmPlexSans(
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
                        : const Color(0xFF35373C),
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
                        color: _isFormValid ? Colors.black : const Color(0xFF8C8C8C),
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
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // Event Name
            _buildCardTextField(
              controller: _nameController,
              hint: _gameType == 'cash'
                  ? 'Event Name (optional)'
                  : 'Event Name',
              showError: _isFieldEmpty(_nameController),
            ),
            _buildSeparator(),
            // Buy-in / Stakes
            _buildCardTextField(
              controller: _buyInController,
              hint: _gameType == 'cash' ? 'Stakes (e.g. 1/2)' : 'Buy-in amount',
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
              hint: _gameType == 'cash' ? 'Min Buy-in (\$)' : 'Starting stack',
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
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Type',
              style: GoogleFonts.ibmPlexSans(
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
                _buildGameTypePill('Tournament', 'tournament'),
                const SizedBox(width: 8),
                _buildGameTypePill('Cash Game', 'cash'),
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
          color: isSelected ? const Color(0xFF1B1E24) : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected ? const Color(0xFF89F1EC) : const Color(0xFF35373C),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: isSelected ? const Color(0xFF89F1EC) : const Color(0xFF8C8C8C),
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
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Date and Time',
              style: GoogleFonts.ibmPlexSans(
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
                  'Starts',
                  style: GoogleFonts.ibmPlexSans(
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
                      color: const Color(0xFF1B1E24),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      DateFormat('d MMM yyyy').format(_selectedDate),
                      style: GoogleFonts.ibmPlexSans(
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
                      color: const Color(0xFF1B1E24),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      _selectedTime.format(context),
                      style: GoogleFonts.ibmPlexSans(
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
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tables',
                  style: GoogleFonts.ibmPlexSans(
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
                          ? 'Deselect All'
                          : 'Select All',
                      style: GoogleFonts.ibmPlexSans(
                        color: const Color(0xFF89F1EC),
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
                      color: Color(0xFF89F1EC),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (_availableTables.isEmpty)
              Text(
                _totalTablesCount > 0
                    ? 'All tables are in use by running events'
                    : 'No tables configured yet',
                style: GoogleFonts.ibmPlexSans(
                  color: const Color(0xFF8C8C8C),
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
                            ? const Color(0xFF1B4341)
                            : const Color(0xFF1B1E24),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF89F1EC)
                              : const Color(0xFF35373C),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? const Color(0xFF89F1EC)
                                : const Color(0xFF8C8C8C),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            table.name,
                            style: GoogleFonts.ibmPlexSans(
                              color: isSelected ? Colors.white : const Color(0xFF8C8C8C),
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
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildCardTextField(
          controller: _descriptionController,
          hint: 'Description',
          maxLines: 3,
        ),
      ),
    );
  }

  Widget _buildNotifyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Color(0xFF89F1EC),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notify Members',
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    ),
                  ),
                  Text(
                    'Send notification to all club members',
                    style: GoogleFonts.ibmPlexSans(
                      color: const Color(0xFF8C8C8C),
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
              activeColor: const Color(0xFF89F1EC),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF35373C),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool showError = false,
  }) {
    return Container(
      decoration: showError
          ? BoxDecoration(
              border: Border.all(color: const Color(0xFFFF4444), width: 1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      margin: showError ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.ibmPlexSans(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          height: 1.44,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.ibmPlexSans(
            color: showError ? const Color(0xFFFF4444).withValues(alpha: 0.7) : const Color(0xFF8C8C8C),
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
      color: const Color(0xFF1C1F21),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5CD9A4),
              surface: Color(0xFF1B1E24),
            ),
          ),
          child: child!,
        );
      },
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
              surface: Color(0xFF1B1E24),
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
      backgroundColor: Color(0xFF02050B),
      body: SizedBox.shrink(),
    );
  }
}
