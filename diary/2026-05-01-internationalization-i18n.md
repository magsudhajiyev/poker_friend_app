# Internationalization (i18n) — Full App Localization

**Date**: 2026-05-01
**Status**: Complete

## Summary

Complete internationalization of the app using Flutter's `gen-l10n` with ARB files. Added support for 7 languages with 2,049 localized string keys. Device locale auto-detection + in-app language picker with persistent preference.

## Languages Supported

- English (template)
- German (Deutsch)
- Spanish (Español)
- French (Français)
- Polish (Polski)
- Portuguese (Português)
- Russian (Русский)

## Infrastructure

### New Files
- `l10n.yaml` — gen-l10n config
- `lib/l10n/app_en.arb` — English template (2,049 keys)
- `lib/l10n/app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_pl.arb`, `app_pt.arb`, `app_ru.arb` — translations
- `lib/services/locale_service.dart` — `ValueNotifier<Locale?>` for reactive switching, persisted via SharedPreferences

### Main App Wiring (`lib/main.dart`)
- `ValueListenableBuilder<Locale?>` wraps `MaterialApp`
- `localizationsDelegates`, `supportedLocales`, `locale` configured
- `LocaleService.init()` called in async setup

### Settings Screen
- Language picker row with bottom sheet
- 8 options: System Default + 7 languages (shown as endonyms)
- `isScrollControlled: true` to prevent overflow

## Localization Pattern

```dart
final l10n = AppLocalizations.of(context);
Text(l10n.statsTitle)
```

### Parameterized strings (ARB)
```json
"handNumber": "Hand #{number}",
"@handNumber": { "placeholders": { "number": { "type": "int" } } }
```

### Poker terms kept in English everywhere
VPIP, PFR, 3-Bet, C-Bet, BB, SB, UTG, CO, BTN, Fold, Check, Call, Bet, Raise, All-in, Flop, Turn, River, TAG, LAG, Nit, Cash Game, MTT

## Files Modified (~85 Dart files)

### All Screens
- home_screen, profile_screen, statistics_screen, settings_screen
- session_history_screen, my_opponents_screen, opponent_detail_screen
- poker_hand_screen, hand_actions_screen, seat_setup_screen
- unified_session_setup_screen, logging_mode_selection_screen
- individual_session_setup_screen, individual_session_tracking_screen
- quick_stack_update_screen, earnings_chart_screen, stack_chart_screen
- auth_wrapper, auth_screen, intro_screen, introduction_screen
- paywall_screen, help_support_screen, redeem_invitation_screen
- knowledge_base_screen, notifications_screen, invitations_screen
- calendar_screen, event_detail_screen, session_analytics_screen
- forgot_password_screen, username_setup_screen, debug_hand_viewer

### Club Screens
- club_dashboard_screen, club_settings_screen, club_info_screen
- event_detail_screen, event_dashboard_screen, event_management_screen
- event_attendees_screen, create_event_screen, final_standings_screen
- admin_table_management_screen, admin_event_tables_screen
- grouped_cash_game_screen, member_table_view_screen, member_event_tables_screen

### Dealer Screens
- dealer_home_screen, dealer_table_screen, dealer_qr_scan_screen

### Player Screens
- player_session_screen, qr_join_screen, live_session_screen, qr_scan_screen

### Spectator/Public
- event_rankings_screen, public_leaderboard_screen

### Widgets (~20 files)
- global_bottom_nav_bar, global_loading_spinner, global_top_header
- action_button_grid, board_cards_dialog, hole_cards_dialog
- all_in_board_cards_dialog, showdown_dialog, winner_selection_dialog
- multi_pot_winner_dialog, hand_review_dialog, raise_snap_overlay
- table_management_sheet, seat_config_sheet, seat_management_dialog
- invite_member_dialog, register_club_dialog, event_success_popup
- navigation_drawer, sliding_notification, poker_table_widget, table_selection_dialog

### Onboarding
- onboarding_tour.dart — all 40+ tour step strings
- guided_hand_overlay.dart — all instruction strings
- onboarding_progress_bar.dart — step counter

### Services
- club_notification_service.dart — stores metadata for display-time resolution

## Notification Localization

Notifications are stored in Firestore with English text. At display time, `notifications_screen.dart` resolves localized titles/bodies based on `notification.type` + stored metadata (`eventName`, `memberName`, `clubName` etc. in the `data` map).

For legacy notifications without metadata, `_extractNameFromTitle()` parses event names from stored English title patterns (e.g., "Test Event is now LIVE!" → extracts "Test Event") and feeds into localized templates.

## Key Decisions

1. **Display-time resolution for notifications** — not stored localized, resolved from type + metadata
2. **Model `displayName` extensions left as-is** — `GameType.displayName`, `ClubRole.displayName`, etc. remain English since extensions lack BuildContext. Used in limited places.
3. **Admin/debug screens skipped** — `notification_tester_screen.dart`, `club_requests_screen.dart`, `support_requests_screen.dart`
4. **Hand tags stored as English keys** — "Bluff", "Value", "Mistake" etc. stored in Firestore as-is, displayed localized

## Common Pitfalls Found

1. **`const` removal** — Text widgets using l10n values cannot be const
2. **Method scope** — l10n requires BuildContext; private methods without context need it passed in or use `AppLocalizations.of(context)` locally
3. **Named vs positional params** — Flutter gen-l10n generates positional params, not named
4. **Bottom sheet overflow** — 8+ language options need `isScrollControlled: true`
5. **Onboarding `buildTooltip`** — adding required `context` param requires updating all call sites
