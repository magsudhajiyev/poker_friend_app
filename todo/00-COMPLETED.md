# Completed Tasks

## Done Items

### 01 - Event Finish Global Shutdown
- When event finishes, all dealer sessions are properly ended

### 03 - Live Rankings Lifecycle
- Live rankings properly update and reflect player status changes

### 04 - Winner Dialog Not Closing
- Fixed winner dialog closing issue after pot award

### 05 - Skip Board Cards When Selected
- Skip already selected board cards in card picker

### 07 - Dealer Button Drag & Drop
- Drag and drop dealer button to change position

### 08 - Rankings Color-Coded Stacks
- Stack colors in rankings: green (above avg), yellow (near avg), red (below avg)

### 12 - Dealer Change Handoff
- Dealer can hand off table to another dealer
- Player sessions persist during handoff
- Dealer name updates in real-time

---

## Recently Completed (Not in separate files)

### Compact Number Formatting
- Large numbers display as K/M (e.g., 240K, 1.1M)
- Applied to: live rankings, hand history, live logging, bet amounts

### Session Analytics for Dealer Sessions
- Total Invested now tracked (buyInAmount + rebuys)
- Final Stack saved to player session record
- Stack History captured after each hand for charts
- Rebuy Count properly tracked

### Unified Player Screen for QR Join
- QR code scan and dealer-assisted seating now use same PlayerSessionScreen
- Consistent experience regardless of how player joins table

### Player Session Persistence on Dealer Handoff
- Players stay connected when dealer hands off table
- Session watches both active and paused status

### 13 - Hole Cards Not Appearing in Hand Details
- Fixed: Player hole cards now appear in hand details after session
- Root cause: `getSessionHands()` wasn't fetching player_data subcollection
- Solution: Fetch and merge player's holeCards, notes, tags into hand data

### 09 - Event RSVP "Who's Coming"
- Real-time updates on event detail screen using StreamSubscription
- Going count badge displayed on event cards in home screen
- RSVP system already existed (Going/Maybe/Can't Go buttons, attendee list)

### 14 - Player Can Edit Any Hand During Session
- Player can tap any past hand in hand history to edit
- Edit dialog allows adding/changing hole cards, notes, and tags
- Changes saved immediately to Firestore
- Long press for full hand details view

### 16 - Real-time Event Status Updates
- Event status changes now propagate to all viewers in real-time
- Event detail screen: Uses StreamSubscription on EventService.watchEvent()
- Club dashboard ALL tabs: Uses single StreamSubscription on EventService.watchClubEvents()
  - Upcoming: new events appear immediately
  - Live: started events move here automatically
  - Past: finished/cancelled events move here automatically
- Visual SnackBar notification when status changes (live, ended, cancelled, paused)
- UI updates automatically without manual refresh
