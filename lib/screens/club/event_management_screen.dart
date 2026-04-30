import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/club.dart';
import '../../models/club_event.dart';
import '../../models/poker_table.dart';
import '../../services/event_service.dart';
import '../../services/table_service.dart';
import 'event_dashboard_screen.dart';

/// Screen for managing club events (create, edit, view)
class EventManagementScreen extends StatefulWidget {
  final Club club;

  const EventManagementScreen({
    Key? key,
    required this.club,
  }) : super(key: key);

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  List<ClubEvent> _events = [];
  List<PokerTable> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final events = await EventService.getClubEvents(widget.club.id);
      final tables = await TableService.getTables(widget.club.id);

      setState(() {
        _events = events;
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventManagementErrorLoading('$e')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _createEvent() async {
    if (_tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).eventManagementNoTables),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateEventDialog(tables: _tables),
    );

    if (result == null) return;

    try {
      final event = await EventService.createEvent(
        clubId: widget.club.id,
        name: result['name'] as String,
        tableIds: result['tableIds'] as List<String>,
        isPublic: result['isPublic'] as bool,
        accessCode: result['accessCode'] as String?,
      );

      setState(() {
        _events.insert(0, event);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventManagementCreated(event.name)),
            backgroundColor: Colors.green.shade700,
          ),
        );

        // Navigate to dashboard
        _openDashboard(event);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventManagementCreateFailed('$e')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openDashboard(ClubEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDashboardScreen(
          club: widget.club,
          event: event,
          tables: _tables.where((t) => event.tableIds.contains(t.id)).toList(),
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _toggleEventStatus(ClubEvent event) async {
    final newStatus = event.status == EventStatus.active
        ? EventStatus.paused
        : EventStatus.active;

    try {
      await EventService.updateEvent(
        widget.club.id,
        event.id,
        status: newStatus,
      );

      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index >= 0) {
          _events[index] = event.copyWith(status: newStatus);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventManagementFailedUpdateEvent('$e')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _endEvent(ClubEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).eventManagementEndEvent),
        content: Text(AppLocalizations.of(context).eventManagementEndConfirm(event.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).eventManagementEndEvent),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await EventService.updateEvent(
        widget.club.id,
        event.id,
        status: EventStatus.completed,
      );

      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index >= 0) {
          _events[index] = event.copyWith(status: EventStatus.completed);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventManagementEnded(event.name)),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).eventManagementEndFailed('$e')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _shareEvent(ClubEvent event) {
    final url = EventService.getPublicUrl(
      event.id,
      accessCode: event.isPublic ? null : event.accessCode,
    );

    Clipboard.setData(ClipboardData(text: url));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).eventManagementLinkCopied),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).eventManagementClubEvents(widget.club.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEvent,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).eventManagementNewEvent),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? _buildEmptyState()
              : _buildEventList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).eventManagementNoEvents,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).eventManagementNoEventsSubtitle,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final activeEvents = _events.where((e) => e.isOngoing).toList();
    final pastEvents = _events.where((e) => !e.isOngoing).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeEvents.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context).eventManagementActiveEvents),
          ...activeEvents.map((e) => _buildEventCard(e)),
          const SizedBox(height: 24),
        ],
        if (pastEvents.isNotEmpty) ...[
          _buildSectionHeader(AppLocalizations.of(context).eventManagementPastEvents),
          ...pastEvents.map((e) => _buildEventCard(e)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildEventCard(ClubEvent event) {
    final statusColor = switch (event.status) {
      EventStatus.scheduled => Colors.blue,
      EventStatus.active => Colors.green,
      EventStatus.paused => Colors.orange,
      EventStatus.completed => Colors.grey,
      EventStatus.cancelled => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: event.isOngoing ? () => _openDashboard(event) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      event.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.table_restaurant,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${event.tableCount} table${event.tableCount != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    event.isPublic ? Icons.public : Icons.lock,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.isPublic ? AppLocalizations.of(context).eventManagementPublic : AppLocalizations.of(context).eventManagementPrivate,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (event.isOngoing) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _shareEvent(event),
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(AppLocalizations.of(context).eventManagementShare),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _toggleEventStatus(event),
                      icon: Icon(
                        event.status == EventStatus.active
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(
                        event.status == EventStatus.active ? AppLocalizations.of(context).eventManagementPause : AppLocalizations.of(context).eventManagementResume,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _endEvent(event),
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(AppLocalizations.of(context).eventManagementEnd),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for creating a new event
class _CreateEventDialog extends StatefulWidget {
  final List<PokerTable> tables;

  const _CreateEventDialog({required this.tables});

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _nameController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final Set<String> _selectedTableIds = {};
  bool _isPublic = false;

  @override
  void dispose() {
    _nameController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).eventManagementEnterName),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedTableIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).eventManagementSelectTable),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'tableIds': _selectedTableIds.toList(),
      'isPublic': _isPublic,
      'accessCode': _accessCodeController.text.trim().isEmpty
          ? null
          : _accessCodeController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).eventManagementCreateEvent),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).eventNameLabel,
                hintText: AppLocalizations.of(context).eventManagementEventNameHint,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).eventManagementSelectTables,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...widget.tables.map((table) => CheckboxListTile(
                  title: Text(table.name),
                  subtitle: Text(AppLocalizations.of(context).eventManagementTableNumber(table.tableNumber)),
                  value: _selectedTableIds.contains(table.id),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedTableIds.add(table.id);
                      } else {
                        _selectedTableIds.remove(table.id);
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(AppLocalizations.of(context).eventManagementPublicEvent),
              subtitle: Text(AppLocalizations.of(context).eventManagementPublicSubtitle),
              value: _isPublic,
              onChanged: (value) {
                setState(() => _isPublic = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isPublic) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _accessCodeController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).eventManagementAccessCode,
                  hintText: AppLocalizations.of(context).eventManagementAccessCodeSubtitle,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(AppLocalizations.of(context).eventManagementCreateEvent),
        ),
      ],
    );
  }
}
