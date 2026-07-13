# Fix: Spades/Clubs Icon Swap + Unnamed Player Display

**Date**: 2026-07-13
**Branch**: design_v2

## Bug 1: Spades and Clubs Icons Swapped

### Symptom
During board card input, selecting spades showed the clubs icon and vice versa.

### Root Cause
The SVG asset files exported from Figma were mislabeled:
- `Property 1=Clubs.svg` visually contained a **spade** shape
- `Property 1=Spades.svg` visually contained a **club** shape

The code in `suit_icon.dart` mapped `Suit.clubs → Clubs.svg` correctly by name, but the files themselves were swapped.

### Fix
Swapped the asset paths in `lib/design_system/components/cards/suit_icon.dart`:
- `Suit.clubs` → `Property 1=Spades.svg` (file visually = club)
- `Suit.spades` → `Property 1=Clubs.svg` (file visually = spade)

Safer than renaming files (avoids pubspec.yaml updates, cache issues, etc.).

## Bug 2: Unnamed Player Not Showing in Winner Dialog / Hand History

### Symptom
When a player is seated without entering a name:
- Winner selection dialog showed only position (e.g., "(BTN)") instead of "Player 2 (BTN)"
- Hand history winner field was blank

### Root Cause
`SeatConfigSheet._save()` passed `name = ''` (empty string), which was stored directly into `sessionManager.playerNames[seatNumber]`.

- **Winner dialog**: `getPlayerNameWithPosition()` checked `playerName == null` but not `playerName.isEmpty`. Empty string passed through, returning `' (BTN)'`.
- **Hand history**: `_getWinnerText()` used `?? 'P$winnerId'` — key existed with value `''`, so fallback never fired.

### Fix (4 files)

1. **`lib/design_system/components/cards/suit_icon.dart`** — Swapped spades/clubs asset paths
2. **`lib/models/hand_state_machine.dart`** — Added `.isEmpty` check in `getPlayerNameWithPosition()`, changed fallback from "Seat X" to "Player X"
3. **`lib/screens/hand_actions_screen.dart`** — Both `nameOf()` (chopped pot) and single-winner paths now check for empty string, fallback to "Player X"
4. **`lib/screens/poker_hand_screen.dart`** — Changed direct `playerNames[seat] = name` to `sessionManager.setPlayerName(seat, name)` which has built-in empty-name → "Player X" fallback

### Prevention Pattern
- When checking player names, always check **both** `null` and `.isEmpty`
- Use `setPlayerName()` instead of direct map writes to ensure fallback logic applies
- When using Figma-exported SVG assets, visually verify the file contents match the filename
