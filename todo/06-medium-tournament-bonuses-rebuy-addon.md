# TODO: Tournament Bonuses - Early Reg, Add-on, Rebuy Buttons

**Date:** 2026-02-21
**Branch:** feature/dealer-assisted-logging
**Status:** TODO (Feature Enhancement)
**Priority:** Medium

---

## Feature Description

Club admin can configure tournament bonus structures (early registration, add-on, rebuy) when creating an event. Dealers get quick-action buttons to apply these instead of manually entering stack amounts each time.

---

## Current Behavior

1. Dealer clicks on a seat to manage player
2. Dealer manually enters stack amount every time
3. No standard bonus/rebuy structure
4. No tracking of early registration bonuses

---

## Expected Behavior

1. Club admin configures tournament structure:
   - Starting stack
   - Early registration bonus (+X chips if registered before event starts)
   - Rebuy amount and chips received
   - Add-on amount and chips received
   - Rebuy period (e.g., first 4 levels)
2. Dealer clicks on a seat and sees quick buttons:
   - "Starting Stack" - applies starting stack
   - "Early Reg Bonus" - applies starting + bonus (if eligible)
   - "Rebuy" - adds rebuy chips to current stack
   - "Add-on" - adds add-on chips
   - Manual entry still available for edge cases
3. System tracks player status (early reg, rebuy count, add-on taken)

---

## Implementation Notes

### 1. Tournament Structure Model

**Add to ClubEvent:**
```dart
class TournamentStructure {
  final double startingStack;
  final double? earlyRegBonus;           // Extra chips for early registration
  final DateTime? earlyRegDeadline;       // When early reg bonus expires
  final double? rebuyAmount;              // Cost in $
  final double? rebuyChips;               // Chips received
  final int? maxRebuys;                   // Max rebuys per player (null = unlimited)
  final int? rebuyEndLevel;               // Rebuys allowed until this level
  final double? addonAmount;              // Cost in $
  final double? addonChips;               // Chips received
  final int? addonAtLevel;                // Add-on offered at this level (break)

  TournamentStructure({
    required this.startingStack,
    this.earlyRegBonus,
    this.earlyRegDeadline,
    this.rebuyAmount,
    this.rebuyChips,
    this.maxRebuys,
    this.rebuyEndLevel,
    this.addonAmount,
    this.addonChips,
    this.addonAtLevel,
  });
}

class ClubEvent {
  // ... existing fields
  final TournamentStructure? tournamentStructure;
}
```

### 2. Player Tournament Status

**Track per-player status:**
```dart
class PlayerTournamentStatus {
  final String odPlayerId;
  final DateTime registeredAt;
  final bool isEarlyReg;              // Registered before deadline
  final bool earlyBonusApplied;       // Has received early reg bonus
  final int rebuyCount;               // Number of rebuys taken
  final bool addonTaken;              // Has taken add-on
  final double totalInvested;         // Total $ put in
}
```

**Store in dealer session or event:**
```dart
// In dealer_sessions/{sessionId}
{
  'playerStatuses': {
    'user123': {
      'registeredAt': Timestamp,
      'isEarlyReg': true,
      'earlyBonusApplied': true,
      'rebuyCount': 1,
      'addonTaken': false,
      'totalInvested': 150.0,
    }
  }
}
```

### 3. Dealer Quick Action Buttons

**When dealer taps on a player seat:**
```dart
void _showPlayerActionsSheet(int seatNumber, SeatedPlayer player) {
  final structure = _event?.tournamentStructure;
  final status = _playerStatuses[player.playerId];

  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Starting Stack
        _buildQuickActionButton(
          icon: Icons.play_arrow,
          label: 'Starting Stack',
          subtitle: '${formatChips(structure?.startingStack ?? 10000)} chips',
          onTap: () => _setPlayerStack(seatNumber, structure?.startingStack ?? 10000),
        ),

        // Early Reg Bonus (if eligible)
        if (structure?.earlyRegBonus != null && status?.isEarlyReg == true && !status.earlyBonusApplied)
          _buildQuickActionButton(
            icon: Icons.star,
            label: 'Early Reg Bonus',
            subtitle: '${formatChips(structure!.startingStack + structure.earlyRegBonus!)} chips',
            color: PokerFriendColors.gold,
            onTap: () => _applyEarlyRegBonus(seatNumber, player),
          ),

        // Rebuy (if available)
        if (_canRebuy(player, structure, status))
          _buildQuickActionButton(
            icon: Icons.replay,
            label: 'Rebuy',
            subtitle: '+${formatChips(structure!.rebuyChips!)} chips (\$${structure.rebuyAmount})',
            color: PokerFriendColors.blue,
            onTap: () => _applyRebuy(seatNumber, player),
          ),

        // Add-on (if available)
        if (_canAddon(player, structure, status))
          _buildQuickActionButton(
            icon: Icons.add_circle,
            label: 'Add-on',
            subtitle: '+${formatChips(structure!.addonChips!)} chips (\$${structure.addonAmount})',
            color: PokerFriendColors.green,
            onTap: () => _applyAddon(seatNumber, player),
          ),

        Divider(),

        // Manual entry (always available)
        _buildQuickActionButton(
          icon: Icons.edit,
          label: 'Set Stack Manually',
          subtitle: 'Enter custom amount',
          onTap: () => _showManualStackDialog(seatNumber),
        ),
      ],
    ),
  );
}
```

### 4. Apply Actions

```dart
Future<void> _applyEarlyRegBonus(int seatNumber, SeatedPlayer player) async {
  final structure = _event!.tournamentStructure!;
  final newStack = structure.startingStack + structure.earlyRegBonus!;

  await DealerService.updatePlayerStack(
    sessionId: _sessionId,
    seatNumber: seatNumber,
    newStack: newStack,
  );

  await _updatePlayerStatus(player.playerId, {
    'earlyBonusApplied': true,
  });

  Navigator.pop(context);
  _showSnackBar('Early reg bonus applied: ${formatChips(newStack)} chips');
}

Future<void> _applyRebuy(int seatNumber, SeatedPlayer player) async {
  final structure = _event!.tournamentStructure!;
  final currentStack = player.stack;
  final newStack = currentStack + structure.rebuyChips!;
  final status = _playerStatuses[player.playerId];

  await DealerService.updatePlayerStack(
    sessionId: _sessionId,
    seatNumber: seatNumber,
    newStack: newStack,
  );

  await _updatePlayerStatus(player.playerId, {
    'rebuyCount': (status?.rebuyCount ?? 0) + 1,
    'totalInvested': (status?.totalInvested ?? 0) + structure.rebuyAmount!,
  });

  Navigator.pop(context);
  _showSnackBar('Rebuy applied: +${formatChips(structure.rebuyChips!)} chips');
}

Future<void> _applyAddon(int seatNumber, SeatedPlayer player) async {
  final structure = _event!.tournamentStructure!;
  final currentStack = player.stack;
  final newStack = currentStack + structure.addonChips!;

  await DealerService.updatePlayerStack(
    sessionId: _sessionId,
    seatNumber: seatNumber,
    newStack: newStack,
  );

  await _updatePlayerStatus(player.playerId, {
    'addonTaken': true,
    'totalInvested': (_playerStatuses[player.playerId]?.totalInvested ?? 0) + structure.addonAmount!,
  });

  Navigator.pop(context);
  _showSnackBar('Add-on applied: +${formatChips(structure.addonChips!)} chips');
}
```

### 5. Eligibility Checks

```dart
bool _canRebuy(SeatedPlayer player, TournamentStructure? structure, PlayerTournamentStatus? status) {
  if (structure?.rebuyChips == null) return false;

  // Check rebuy period
  if (structure!.rebuyEndLevel != null) {
    final currentLevel = _event!.currentBlindLevelIndex;
    if (currentLevel >= structure.rebuyEndLevel!) return false;
  }

  // Check max rebuys
  if (structure.maxRebuys != null) {
    if ((status?.rebuyCount ?? 0) >= structure.maxRebuys!) return false;
  }

  return true;
}

bool _canAddon(SeatedPlayer player, TournamentStructure? structure, PlayerTournamentStatus? status) {
  if (structure?.addonChips == null) return false;
  if (status?.addonTaken == true) return false;

  // Check if we're at add-on level (usually at break)
  if (structure!.addonAtLevel != null) {
    final currentLevel = _event!.currentBlindLevelIndex;
    if (currentLevel != structure.addonAtLevel) return false;
  }

  return true;
}
```

### 6. Admin Configuration UI

**In create_event_screen.dart (for tournaments):**
```dart
Widget _buildTournamentStructure() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildLabel('Tournament Structure'),
      SizedBox(height: 16),

      // Starting Stack
      _buildTextField(
        controller: _startingStackController,
        label: 'Starting Stack',
        hint: '10000',
        keyboardType: TextInputType.number,
      ),

      // Early Registration
      _buildSectionHeader('Early Registration Bonus'),
      Row(
        children: [
          Expanded(child: _buildTextField(
            controller: _earlyRegBonusController,
            label: 'Bonus Chips',
            hint: '5000',
          )),
          SizedBox(width: 12),
          Expanded(child: _buildDateTimePicker(
            label: 'Deadline',
            value: _earlyRegDeadline,
            onChanged: (dt) => setState(() => _earlyRegDeadline = dt),
          )),
        ],
      ),

      // Rebuy
      _buildSectionHeader('Rebuy'),
      Row(
        children: [
          Expanded(child: _buildTextField(
            controller: _rebuyAmountController,
            label: 'Cost (\$)',
            hint: '50',
          )),
          SizedBox(width: 12),
          Expanded(child: _buildTextField(
            controller: _rebuyChipsController,
            label: 'Chips',
            hint: '10000',
          )),
        ],
      ),
      Row(
        children: [
          Expanded(child: _buildTextField(
            controller: _maxRebuysController,
            label: 'Max Rebuys',
            hint: 'Unlimited',
          )),
          SizedBox(width: 12),
          Expanded(child: _buildTextField(
            controller: _rebuyEndLevelController,
            label: 'Until Level',
            hint: '6',
          )),
        ],
      ),

      // Add-on
      _buildSectionHeader('Add-on'),
      Row(
        children: [
          Expanded(child: _buildTextField(
            controller: _addonAmountController,
            label: 'Cost (\$)',
            hint: '50',
          )),
          SizedBox(width: 12),
          Expanded(child: _buildTextField(
            controller: _addonChipsController,
            label: 'Chips',
            hint: '15000',
          )),
        ],
      ),
    ],
  );
}
```

---

## Automatic Detection

### Early Registration Detection

```dart
// When player RSVPs or joins before deadline
bool isEarlyReg = DateTime.now().isBefore(event.tournamentStructure!.earlyRegDeadline!);
```

### Bust Detection

```dart
// When player stack reaches 0
if (player.stack <= 0) {
  _showBustedDialog(player);
  // Offer rebuy if eligible
}
```

---

## Related Files

- `lib/models/club_event.dart` - Add TournamentStructure
- `lib/models/dealer_session.dart` - Add playerStatuses
- `lib/services/dealer_service.dart` - Stack update methods
- `lib/screens/dealer/dealer_table_screen.dart` - Quick action buttons
- `lib/screens/club/create_event_screen.dart` - Tournament structure editor

---

## Acceptance Criteria

- [ ] Admin can configure starting stack, early reg bonus, rebuy, add-on
- [ ] Early reg bonus auto-detected based on registration time
- [ ] Dealer sees quick action buttons: Starting Stack, Early Reg, Rebuy, Add-on
- [ ] Rebuy button only appears when eligible (within period, under max)
- [ ] Add-on button only appears when eligible (at break, not taken)
- [ ] Manual stack entry still available for edge cases
- [ ] Player status tracked (rebuy count, add-on taken, total invested)
- [ ] Total invested visible for end-of-tournament accounting
