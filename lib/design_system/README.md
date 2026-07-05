# Design System — Unification Plan & Rules

**Goal:** every screen builds from the same tokens (`AppColors`,
`AppTypography`, `AppSpacing`, `AppDecorations`) and shared components —
no hardcoded style values in screens/widgets.

## Measuring progress

```bash
python3 tool/design_lint.py         # count hardcoded values
python3 tool/design_lint.py --fix   # auto-replace hexes that exactly match a token
```

Baseline (2026-07-05, before phase 1): **2,379 hardcoded `Color(0x…)` across
96 files, 201 distinct values**. FontSize literals: 15 distinct values used
1,600+ times inline. Radius literals: 12/16/8/18/20/10/999/60/40/14…

## Phase 1 — DONE (mechanical, zero visual change)

- Added missing brand tokens: `tealPrimary` (#62E3BC), `paper` (#02050B),
  `surfaceDark` (#101115), `textMuted` (#9A9A9A), `profitGreen` (#5AC95A),
  `lossRed` (#FF4444).
- Auto-replaced **1,235 hardcoded hexes in 81 files** with their exact
  AppColors token (value-identical).

## Phase 2 — semantic color pass (needs design judgment)

~1,144 hardcoded values remain, in two classes:

1. **Shared-value hexes** the lint deliberately skips because one value has
   several semantic tokens: `#0C0C0C` (bgPrimary vs textInverse, ×102),
   `#B9B9B9` (textSecondary vs borderLight vs contentInactive, ×115),
   `#161719` (bgSurface vs borderDefault, ×74). Migrate by reading each
   usage's role, not its value.
2. **Near-duplicate greys** that should be *consolidated* (visual change,
   review each): `#161618`/`#1F1F23`/`#2A2A2E`/`#1A1A1E` vs the canonical
   `bgSurface`/`bgElevated`; `#CB5242` (×25) vs `errorRed` `#D55A41`.

## Phase 3 — typography & shape

- Inline `GoogleFonts.ibmPlexSans(fontSize: …)` everywhere → adopt
  `AppTypography` styles (extend it with the observed scale:
  10/11/12/13/14/15/16/17/18/20/24/28/32).
- Radius literals → `AppDecorations` (add missing: 8, 10, 16, 18, 20, 999→pill).
- Spacing literals → `AppSpacing`.

## Phase 4 — component adoption & legacy retirement

Top offenders by hardcoded values (migrate these first, one screen per PR):
`dealer/dealer_table_screen` (158), `poker_hand_screen` (154),
`home_screen` (141), `player/player_session_screen` (113),
`club/club_dashboard_screen` (81), `opponent_detail_screen` (68).
Replace bespoke containers with GlassyCard / InfoCard / PrimaryButton /
SectionHeader / ConfirmDialog; retire `PokerFriendTheme` (legacy purple).

## Rules for new code

1. No `Color(0x…)` literals outside `design_system/constants/colors.dart`.
2. No inline `fontSize:`/`fontWeight:` — use/extend `AppTypography`.
3. Reuse components before building bespoke containers.
4. Run `python3 tool/design_lint.py` before committing UI work; the count
   must not go up.
