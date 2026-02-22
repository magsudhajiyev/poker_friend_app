import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design_system/poker_friend_theme.dart';
import '../../models/club.dart';
import '../../models/poker_table.dart';
import '../../services/event_service.dart';
import '../../services/table_service.dart';

/// Screen for creating a new club event
class CreateEventScreen extends StatefulWidget {
  final Club club;

  const CreateEventScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _buyInController = TextEditingController();
  final _startingStackController = TextEditingController();
  final _maxPlayersController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  bool _notifyMembers = true;
  bool _isSubmitting = false;
  String _gameType = 'cash';  // 'cash' or 'tournament'

  // Table selection
  List<PokerTable> _availableTables = [];
  Set<String> _selectedTableIds = {};
  bool _isLoadingTables = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    try {
      final tables = await TableService.getTables(widget.club.id);
      setState(() {
        _availableTables = tables;
        _isLoadingTables = false;
      });
    } catch (e) {
      print('Error loading tables: $e');
      setState(() => _isLoadingTables = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _buyInController.dispose();
    _startingStackController.dispose();
    _maxPlayersController.dispose();
    super.dispose();
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
              primary: PokerFriendColors.purple,
              onPrimary: Colors.white,
              surface: PokerFriendColors.dark3,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: PokerFriendColors.purple,
              onPrimary: Colors.white,
              surface: PokerFriendColors.dark3,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
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

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final buyIn = _buyInController.text.isNotEmpty
          ? double.tryParse(_buyInController.text)
          : null;
      final startingStack = _startingStackController.text.isNotEmpty
          ? double.tryParse(_startingStackController.text)
          : null;
      final maxPlayers = _maxPlayersController.text.isNotEmpty
          ? int.tryParse(_maxPlayersController.text)
          : null;

      await EventService.createEventWithDetails(
        clubId: widget.club.id,
        name: _nameController.text.trim(),
        startTime: _eventDateTime,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        buyInAmount: buyIn,
        startingStack: startingStack,
        maxPlayers: maxPlayers,
        notifyMembers: _notifyMembers,
        tableIds: _selectedTableIds.toList(),
        gameType: _gameType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event name
                      _buildLabel('Event Name *'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'e.g., Friday Night Poker',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an event name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Date and Time
                      _buildLabel('Date & Time *'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateTimePicker(
                              icon: Icons.calendar_today,
                              label: DateFormat('EEE, MMM d').format(_selectedDate),
                              onTap: _selectDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateTimePicker(
                              icon: Icons.access_time,
                              label: _selectedTime.format(context),
                              onTap: _selectTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Game Type
                      _buildLabel('Game Type *'),
                      const SizedBox(height: 8),
                      _buildGameTypeSelector(),
                      const SizedBox(height: 24),

                      // Location
                      _buildLabel('Location'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _locationController,
                        hint: 'e.g., 123 Main St or Online',
                      ),
                      const SizedBox(height: 24),

                      // Buy-in and Starting Stack
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Buy-in (\$)'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _buyInController,
                                  hint: '0',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Starting Stack'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _startingStackController,
                                  hint: 'e.g., 10000',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Max Players
                      _buildLabel('Max Players'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _maxPlayersController,
                        hint: 'No limit',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),

                      // Description
                      _buildLabel('Description'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: 'Tell members what to expect...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      // Table selection
                      _buildLabel('Tables'),
                      const SizedBox(height: 8),
                      _buildTableSelection(),
                      const SizedBox(height: 24),

                      // Notify members toggle
                      _buildNotifyToggle(),

                      const SizedBox(height: 40),

                      // Create button
                      _buildCreateButton(),

                      const SizedBox(height: 24),
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
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Create Event',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: PokerFriendColors.dark9,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: PokerFriendColors.dark9),
        filled: true,
        fillColor: PokerFriendColors.dark3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PokerFriendColors.purple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PokerFriendColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PokerFriendColors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: PokerFriendColors.purple, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSelection() {
    if (_isLoadingTables) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: PokerFriendColors.purple,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_availableTables.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PokerFriendColors.dark3,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: PokerFriendColors.dark9,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No tables configured',
                    style: TextStyle(
                      color: PokerFriendColors.dark11,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tables can be assigned later when starting the event',
                    style: TextStyle(
                      color: PokerFriendColors.dark9,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PokerFriendColors.dark3,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_restaurant,
                color: PokerFriendColors.purple,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedTableIds.isEmpty
                      ? 'No tables selected (all tables available)'
                      : '${_selectedTableIds.length} table${_selectedTableIds.length == 1 ? '' : 's'} selected',
                  style: TextStyle(
                    color: PokerFriendColors.dark11,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_selectedTableIds.length == _availableTables.length) {
                    setState(() => _selectedTableIds.clear());
                  } else {
                    setState(() => _selectedTableIds = _availableTables.map((t) => t.id).toSet());
                  }
                },
                child: Text(
                  _selectedTableIds.length == _availableTables.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: const TextStyle(
                    color: PokerFriendColors.purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? PokerFriendColors.purple.withOpacity(0.2)
                      : PokerFriendColors.dark3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? PokerFriendColors.purple
                        : PokerFriendColors.dark5,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: PokerFriendColors.purple,
                        size: 16,
                      )
                    else
                      Icon(
                        Icons.circle_outlined,
                        color: PokerFriendColors.dark9,
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      table.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : PokerFriendColors.dark11,
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
    );
  }

  Widget _buildGameTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _gameType = 'cash'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _gameType == 'cash'
                    ? PokerFriendColors.purple.withOpacity(0.2)
                    : PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _gameType == 'cash'
                      ? PokerFriendColors.purple
                      : PokerFriendColors.dark5,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.attach_money,
                    color: _gameType == 'cash'
                        ? PokerFriendColors.purple
                        : PokerFriendColors.dark9,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cash Game',
                    style: TextStyle(
                      color: _gameType == 'cash'
                          ? Colors.white
                          : PokerFriendColors.dark11,
                      fontSize: 15,
                      fontWeight: _gameType == 'cash'
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _gameType = 'tournament'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _gameType == 'tournament'
                    ? PokerFriendColors.purple.withOpacity(0.2)
                    : PokerFriendColors.dark3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _gameType == 'tournament'
                      ? PokerFriendColors.purple
                      : PokerFriendColors.dark5,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: _gameType == 'tournament'
                        ? PokerFriendColors.purple
                        : PokerFriendColors.dark9,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tournament',
                    style: TextStyle(
                      color: _gameType == 'tournament'
                          ? Colors.white
                          : PokerFriendColors.dark11,
                      fontSize: 15,
                      fontWeight: _gameType == 'tournament'
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotifyToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PokerFriendColors.dark3,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PokerFriendColors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: PokerFriendColors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notify Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Send notification to all club members',
                  style: TextStyle(
                    color: PokerFriendColors.dark9,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _notifyMembers,
            onChanged: (value) => setState(() => _notifyMembers = value),
            activeColor: PokerFriendColors.purple,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: PokerFriendColors.dark5,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _createEvent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _isSubmitting
              ? PokerFriendColors.purple.withOpacity(0.5)
              : PokerFriendColors.purple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Create Event',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
