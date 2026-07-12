import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/club.dart';
import '../../models/poker_game_state.dart' show formatBlindValue;
import '../../models/poker_table.dart';
import '../../models/dealer_session.dart';
import '../../services/club_service.dart';
import '../../services/table_service.dart';
import '../../services/dealer_service.dart';
import '../../services/auth_service.dart';
import 'dealer_table_screen.dart';
import '../../design_system/constants/colors.dart';
import '../../design_system/constants/decorations.dart';
import '../../design_system/constants/typography.dart';
import '../../design_system/components/dialogs/app_dialog.dart';
import '../../design_system/components/dialogs/dialog_action_bar.dart';
import '../../utils/user_facing_error.dart';

/// Home screen for dealers to select a club and table
class DealerHomeScreen extends StatefulWidget {
  const DealerHomeScreen({Key? key}) : super(key: key);

  @override
  State<DealerHomeScreen> createState() => _DealerHomeScreenState();
}

class _DealerHomeScreenState extends State<DealerHomeScreen> {
  List<Club> _clubs = [];
  Map<String, List<PokerTable>> _tablesByClub = {};
  List<DealerSession> _activeSessions = [];
  bool _isLoading = true;
  String? _selectedClubId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user is admin
      _isAdmin = await AuthService.isAdmin;

      // Load clubs
      final clubs = await ClubService.getClubs();

      // Load tables for each club
      final tablesByClub = <String, List<PokerTable>>{};
      for (final club in clubs) {
        final tables = await TableService.getTables(club.id);
        tablesByClub[club.id] = tables;
      }

      // Load active sessions
      final activeSessions = await DealerService.getDealerActiveSessions();

      setState(() {
        _clubs = clubs;
        _tablesByClub = tablesByClub;
        _activeSessions = activeSessions;
        if (_clubs.isNotEmpty && _selectedClubId == null) {
          _selectedClubId = _clubs.first.id;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).dealerHomeErrorLoading(UserFacingError.message(e))),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  DealerSession? _getActiveSessionForTable(String tableId) {
    return _activeSessions.where((s) => s.tableId == tableId).firstOrNull;
  }

  Future<void> _startSession(Club club, PokerTable table) async {
    // Show settings dialog
    final settings = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SessionSettingsDialog(
        club: club,
        table: table,
      ),
    );

    if (settings == null) return;

    try {
      final session = await DealerService.startSession(
        clubId: club.id,
        tableId: table.id,
        smallBlind: (settings['smallBlind'] as num?)?.toDouble() ?? 1.0,
        bigBlind: (settings['bigBlind'] as num?)?.toDouble() ?? 2.0,
        hasBBante: settings['hasBBante'] ?? false,
        gameType: settings['gameType'] ?? 'cash',
        buttonPosition: settings['buttonPosition'] ?? 1,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DealerTableScreen(
              session: session,
              club: club,
              table: table,
            ),
          ),
        ).then((_) => _loadData());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).dealerHomeStartFailed(UserFacingError.message(e))),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _resumeSession(DealerSession session) async {
    final club = _clubs.where((c) => c.id == session.clubId).firstOrNull;
    final table = _tablesByClub[session.clubId]
        ?.where((t) => t.id == session.tableId)
        .firstOrNull;

    if (club == null || table == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).dealerHomeCouldNotFind),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DealerTableScreen(
          session: session,
          club: club,
          table: table,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(AppLocalizations.of(context).dealerHomeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _buildBody(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildBody() {
    if (_clubs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dealer info
            _buildDealerInfo(),

            const SizedBox(height: 24),

            // Active sessions
            if (_activeSessions.isNotEmpty) ...[
              _buildSectionHeader(AppLocalizations.of(context).dealerHomeActiveSessions),
              const SizedBox(height: 12),
              ..._activeSessions.map(_buildActiveSessionCard),
              const SizedBox(height: 24),
            ],

            // Club selector
            _buildSectionHeader(AppLocalizations.of(context).dealerHomeClubs),
            const SizedBox(height: 12),
            _buildClubSelector(),

            const SizedBox(height: 24),

            // Tables for selected club
            if (_selectedClubId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(AppLocalizations.of(context).dealerHomeTables),
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: () {
                        final club = _clubs.where((c) => c.id == _selectedClubId).firstOrNull;
                        if (club != null) _showCreateTableDialog(club);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(AppLocalizations.of(context).dealerHomeAddTable),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTablesList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).dealerHomeNoClubs,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isAdmin
                  ? AppLocalizations.of(context).dealerHomeNoClubsOwnerHint
                  : AppLocalizations.of(context).dealerHomeNoClubsMemberHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showCreateClubDialog,
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).dealerHomeCreateClub),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTableDialog(Club club) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          AppLocalizations.of(context).dealerHomeAddTable,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).dealerHomeTableNameLabel,
            hintText: AppLocalizations.of(context).dealerHomeTableNameHint,
            labelStyle: const TextStyle(color: Colors.white54),
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: Text(AppLocalizations.of(context).dealerHomeAddTable),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Calculate next table number
        final existingTables = _tablesByClub[club.id] ?? [];
        final nextTableNumber = existingTables.isEmpty
            ? 1
            : existingTables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;

        await TableService.createTable(
          clubId: club.id,
          tableNumber: nextTableNumber,
          name: result,
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).dealerHomeTableAdded(result, club.name)),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).dealerHomeAddTableFailed(UserFacingError.message(e))),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  Future<void> _showCreateClubDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
          AppLocalizations.of(context).dealerHomeCreateClub,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).dealerHomeClubName,
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            child: Text(AppLocalizations.of(context).dealerHomeCreate),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ClubService.createClub(name: result);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).dealerHomeClubCreated(result)),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).dealerHomeClubCreateFailed(UserFacingError.message(e))),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  Widget _buildDealerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900,
            Colors.green.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AuthService.userDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppLocalizations.of(context).dealerHomeDealer,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDecorations.radius20),
            ),
            child: Text(
              AppLocalizations.of(context).dealerHomeClubCount(_clubs.length),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildActiveSessionCard(DealerSession session) {
    final club = _clubs.where((c) => c.id == session.clubId).firstOrNull;
    final table = _tablesByClub[session.clubId]
        ?.where((t) => t.id == session.tableId)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _resumeSession(session),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.amber,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table?.name ?? 'Table',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${club?.name ?? 'Club'} - Hand #${session.currentHandNumber}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.amber,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubSelector() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _clubs.length,
        itemBuilder: (context, index) {
          final club = _clubs[index];
          final isSelected = club.id == _selectedClubId;
          final tableCount = _tablesByClub[club.id]?.length ?? 0;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedClubId = club.id;
              });
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.green.shade800
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? Colors.green
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.business,
                    color: isSelected ? Colors.white : Colors.white54,
                    size: 24,
                  ),
                  const Spacer(),
                  Text(
                    club.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppLocalizations.of(context).dealerHomeTableCount(tableCount),
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTablesList() {
    final tables = _tablesByClub[_selectedClubId] ?? [];
    final club = _clubs.where((c) => c.id == _selectedClubId).firstOrNull;

    if (tables.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        ),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context).dealerHomeNoTables,
              style: const TextStyle(color: Colors.white54),
            ),
            if (_isAdmin && club != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateTableDialog(club),
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).dealerHomeAddTable),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: tables.map((table) {
        final activeSession = _getActiveSessionForTable(table.id);
        final isActive = activeSession != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDecorations.radius10),
              ),
              child: Icon(
                Icons.table_restaurant,
                color: isActive ? Colors.green : Colors.white54,
              ),
            ),
            title: Text(
              table.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isActive
                  ? AppLocalizations.of(context).dealerHomeActiveHand(activeSession!.currentHandNumber)
                  : AppLocalizations.of(context).dealerHomeInactive,
              style: TextStyle(
                color: isActive ? Colors.green : Colors.white38,
              ),
            ),
            trailing: isActive
                ? ElevatedButton(
                    onPressed: () => _resumeSession(activeSession!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text(AppLocalizations.of(context).dealerHomeResume),
                  )
                : ElevatedButton(
                    onPressed: club != null
                        ? () => _startSession(club, table)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text(AppLocalizations.of(context).dealerHomeStart),
                  ),
          ),
        );
      }).toList(),
    );
  }
}

/// Dialog for configuring session settings before starting
class _SessionSettingsDialog extends StatefulWidget {
  final Club club;
  final PokerTable table;

  const _SessionSettingsDialog({
    required this.club,
    required this.table,
  });

  @override
  State<_SessionSettingsDialog> createState() => _SessionSettingsDialogState();
}

class _SessionSettingsDialogState extends State<_SessionSettingsDialog> {
  late double _smallBlind;
  late double _bigBlind;
  late bool _hasBBante;
  late String _gameType;
  late int _buttonPosition;

  @override
  void initState() {
    super.initState();
    _smallBlind = widget.club.settings.defaultSmallBlind;
    _bigBlind = widget.club.settings.defaultBigBlind;
    _hasBBante = widget.club.settings.defaultHasBBante;
    _gameType = widget.club.settings.defaultGameType;
    _buttonPosition = 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: l10n.dealerHomeSessionSettings,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _blindField(l10n.dealerHomeSmallBlind, _smallBlind, (v) => _smallBlind = v)),
                const SizedBox(width: 16),
                Expanded(child: _blindField(l10n.dealerHomeBigBlind, _bigBlind, (v) => _bigBlind = v)),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _hasBBante,
              onChanged: (v) => setState(() => _hasBBante = v),
              title: Text(
                l10n.dealerHomeBBAnte,
                style: AppTypography.ibm(color: AppColors.textPrimary),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dealerHomeGameType,
              style: AppTypography.ibm(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', label: Text(l10n.dealerHomeCash)),
                ButtonSegment(value: 'tournament', label: Text(l10n.dealerHomeTournament)),
              ],
              selected: {_gameType},
              onSelectionChanged: (v) {
                setState(() => _gameType = v.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.dealerHomeButtonPosition,
              style: AppTypography.ibm(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(9, (i) {
                final seat = i + 1;
                return ChoiceChip(
                  label: Text(seat.toString()),
                  selected: _buttonPosition == seat,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _buttonPosition = seat);
                    }
                  },
                );
              }),
            ),
          ],
        ),
      ),
      actions: DialogActionBar(
        confirmLabel: l10n.dealerHomeStartSession,
        confirmColor: AppColors.accentPrimary,
        confirmTextColor: AppColors.textInverse,
        autoDismiss: false,
        onConfirm: () {
          Navigator.pop(context, {
            'smallBlind': _smallBlind,
            'bigBlind': _bigBlind,
            'hasBBante': _hasBBante,
            'gameType': _gameType,
            'buttonPosition': _buttonPosition,
          });
        },
      ),
    );
  }

  Widget _blindField(String label, double current, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.ibm(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: formatBlindValue(current),
          keyboardType: TextInputType.number,
          style: AppTypography.ibm(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDecorations.radiusSm),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) onChanged(parsed);
          },
        ),
      ],
    );
  }
}
