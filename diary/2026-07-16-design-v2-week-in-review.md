# design_v2 Week in Review — 2026-07-09 → 2026-07-15

**Date**: 2026-07-16
**Branch**: design_v2
**Status**: Shipped — 37 commits, ~532 files touched, +18,800/−17,303 lines

---

## Overview

A dense week of design-system consolidation and app-feel work on the
`design_v2` branch. The goal was to move the app from "functional but
inconsistent" to "coherent, alive, and iOS-native". Three parallel
tracks:

1. **Design system**: dark-mode palette overhaul, canonical component
   library (pill buttons, top nav, modals, sheets, tabs), and a broad
   consistency sweep across every screen.
2. **Onboarding v2**: completely rebuilt as a themed, gamified flow —
   card-deal page transitions, morphing pill progress bar, pill-based
   selection with icons, and a per-step reveal animation.
3. **App feel**: haptics, count-up numbers, skeleton loaders, hero
   transitions, iOS-style scroll physics, and a bouncy touch-responsive
   bottom nav.

Also fixed a stack of bugs surfaced by heavier tour testing (Google
sign-in loop, spades/clubs icon swap, heads-up pot initialization,
tour phase mismatches). The in-app tour now has a canonical reference
document (`2026-07-15-in-app-tour-complete-reference.md`) that all
future changes must respect — enforced by an updated `CLAUDE.md` rule.

---

## Track 1: Design System

### Palette + canonical primitives (576c99e, 4922212, bba40ff)
- Dark-mode palette overhaul: unified `bgPrimary` / `bgSurface` /
  `bgElevated` tokens, replaced ~100 raw hex literals with semantic
  tokens across the sweep.
- Canonical `TopNavBar` + `BackButtonCircle` used everywhere; modal
  palette unified (dark bg, white text, glass close-X, no more mixed
  light-mode dialogs).
- Followup token-reference fix caught the last few string references
  that broke during the rename.

### Component library additions
- **PrimaryPillButton / SecondaryPillButton / OutlinedPillButton /
  DestructivePillButton** (4f53d01) — the canonical CTA set.
- **AnimatedSegmentedTabs** (3dbfad0) — sliding-pill segmented
  control used on Statistics, Session History, etc.
- **SwipeToDeleteCell** (4f53d01) — iOS-Mail-style swipe reveal for
  session/opponent list rows.
- **AppSheet / SheetHeader / AppDialog** (4922212) — canonical modal
  scaffolds.
- **Skeleton** primitive (existed, now widely used).
- **TweenNumber** (95d722d, later enhanced) — animated numeric text.
- **ScaleTapFeedback, ChipFly, ChartRevealClip, ChipFly** (95d722d) —
  micro-interaction helpers.
- **StepReveal** (5120764) — stagger-in helper for onboarding steps.

### Consistency sweeps (98563df, 5c2d818, 5bdafbc, 36c6652)
- Chevrons unified to `assets/icons/CaretRight.svg` (dropped mixed
  `Icons.chevron_right`).
- Toggles unified to `AppToggle`.
- 44×44 `bgSurface` circles standardised for every top-nav action
  (back, close, menu, refresh, export).
- **Persistent MainShell** — bottom nav no longer animates away on
  detail pushes. Detail screens omit the bottom nav entirely (Apple
  focus-mode pattern).
- Bottom-anchored tour UI so spotlights don't jump around the screen.

### Design Preview screen (9c307bd)
New `/design_preview` route showcasing every dialog / modal / sheet
side-by-side — a living style guide for dev + design QA.

---

## Track 2: Onboarding v2

Rebuilt from scratch under `lib/screens/onboarding/`.

### Structure (5120764, 0426d23)
- **`OnboardingFlow`** owns a `PageController`, collects data
  centrally, and controls step advancement.
- **`OnboardingScaffold`** provides the shared frame: reserved
  progress-bar space at top, content area, canonical CTA + back
  button at the bottom.
- **Persistent progress bar overlay**: hoisted out of the scaffold so
  a single `OnboardingProgressBar` instance tweens between step
  positions (`easeOutBack` morph) instead of being torn down and
  rebuilt every PageView child.

### Step redesigns
- **Welcome** (5120764) — 84px logo, 44/w600 hero title, 17/w400
  subtitle; staggered reveal on mount.
- **Nickname** — existing, cleaned up.
- **Game Type** (5120764, 7fdd8d5) — centered title, icon pill row
  (Cash Game / Tournament / Mix of both) with `bgSurface` +
  `accentSecondary` on selected. "Mix of both" pill added later with
  the arrows-in-horizontal-line icon and localized copy across all 7
  languages.
- **Currency** — big search input, single-card list with hairline
  separators, symbol + name (CODE) + flag layout, green check on the
  selected row. Later flattened further: search on top, title +
  subtitle below, no per-currency chip. 22 currencies now use SVG
  flags from `assets/icons/flags/` (previously 8 fell back to emoji).
- **Journey** (5120764) — centered title, 2×2 label pill grid.
- **Weekly Hours** — Cupertino picker, centered header, tightened
  copy: "How many sessions do you play a month?".
- **Purpose** (5120764) — 9 stacked full-width pills, tinted-fill
  selection (`accentSecondary @ 12%`) + counter on the CTA ("Get
  Started (3)") for multi-select clarity.

### Themed transitions
- **Card-deal** (`_DealTransition` in `onboarding_flow.dart`) — every
  PageView child transforms per-frame on 3D Y-rotation (~20° tilt at
  max), scale (1.0 → 0.92), and opacity (hard fade in last 40%).
  Reads as a card being dealt onto the table instead of a flat
  horizontal slide.
- **520ms `easeOutCubic`** transition timing (up from 300ms
  easeInOut) so the tilt reads before the settle.
- **Haptic selection tick** on every next/back.
- **StepReveal** — content elements rise + fade in with a 70–120ms
  stagger when each step first mounts. Applied to Welcome, Game
  Type, Journey, Weekly Hours, Purpose.

### Copy + l10n
- Every visible string localized across EN / DE / ES / FR / PT / RU /
  PL. Multiple copy passes tightened phrasing.
- "Select currency" (was "What currency do you play in?").
- "How many sessions do you play a month?" (was "How many sessions
  are you approximately playing a month?").
- Game type subtitle reframed to "…are you a cash player, tournament
  player, or a mix?" to match the three-way pill layout.

---

## Track 3: App Feel

### Number animations (d1df4c8)
- `TweenNumber` extended with `animateOnMount` flag.
- Wired on Home: bankroll (1.1s count-up), Recent Activity stat cells
  (Sessions, Win Rate, Hours).
- Wired on Statistics: all 9 top metric cards (Hands Logged, VPIP,
  PFR, 3-Bet, Fold-to-3Bet, C-Bet, Steal, Check-Raise, Win Rate)
  plus every row in General / Cash / Tournament sections including
  Net Profit and Hourly Rate. Cards showing N/A skip the animation.
- Numbers count up from 0 on first paint; sign flips smoothly through
  zero for profit/loss values.

### Skeleton loaders (d1df4c8)
- Opponents list: `GlobalLoadingSpinner` → `_buildOpponentsSkeleton()`
  (6 shimmering rows shaped like the real opponent card).
- Statistics: `LoadingWrapper` overlay → `_buildSkeletonContent()`
  (top nav + tabs + 9 shimmering metric rows).
- Session History was already skeleton-based.

### Hero transitions (d1df4c8)
- Session card → Session Analytics header (tag `sessionCard_$id`).
- Opponent card → Opponent Detail header (tag `opponentCard_$id`).
- Both use a `flightShuttleBuilder` Material shim so the flight
  paints cleanly during the transition.

### Bottom nav (2e21947, c8cbd69, later polished)
- Sliding pill highlight (`AnimatedPositioned`, 450ms easeOutBack).
- Bell wiggle when notifications come in.
- Each icon: press-in 0.82× (90ms easeOut), spring-back with
  easeOutBack overshoot (420ms), active-tab pop to 1.08.
- Whole pill also scales 0.97× on any tap (Listener overlay).
- FAB gets `HapticFeedback.mediumImpact` + a punchier 1.14× press
  scale.
- Icons stay white — selection is communicated by the sliding
  highlight and active pop, not by colour (an earlier
  `accentSecondary` tint experiment was reverted).

### iOS scroll physics (d1df4c8)
- New `AppScrollBehavior` (`lib/design_system/app_scroll_behavior.dart`)
  wired into `MaterialApp.scrollBehavior`.
- `BouncingScrollPhysics` on every scroll surface on both platforms;
  Android overscroll glow suppressed.

### Options-drawer polish (6ff0388)
- Session-details drawer (Rebuy / Add-on / End Session): icons
  16→20px, gap 10→12, `_MenuActionRow` widget with press-in tint
  (bgSurface for normal, accentDanger @ 12% for destructive), 140ms
  confirmation flash after tap-up before the menu closes, haptics
  (selectionClick + mediumImpact for End Session).
- Poker-hand options overlay (Change Table / Skip Hand Scouting /
  Gesture Guide / Stop Session): row height 32→46px, icons 16→20px,
  press-in tint + haptic via a new `_MenuRow` stateful widget.

### Session Analytics flatten
- Removed the two `bgSurface` card containers around Session Overview
  and Stack Chart. Content sits flush on the page bg with a hairline
  separator between sections and a "Profit" or "Loss" eyebrow above
  the hero P/L in the matching accent colour (green/red).

### Seat setup + input polish
- Session-setup dotted table wallpaper hoisted so it covers the full
  card (previously clipped to the middle table area).
- Instruction text split onto two lines across all 7 locales.
- Seat modal: Name input + "Save as opponent" toggle grouped into one
  visually-connected card (hairline between them) so the toggle
  reads as a modifier of the Name field, not another input.

### Session summary card
- Close button changed from `Colors.white @ 8%` (near-invisible) to
  a proper solid `bgElevated` + `borderStrong` secondary button
  treatment.

### Bankroll edit (multiple later commits, not all pushed yet)
- New full-screen `BankrollEditScreen` per Figma spec: rounded card
  with tap-to-edit rows for Current, Goal, and Currency; large 28px
  numeric TextFields with always-visible currency prefix; Save +
  white-outlined Cancel pills at the bottom.
- Home entry: pencil icon removed; the whole "Total Bankroll" card
  is now tappable, with the label bumped to 13/w600 + trailing
  chevron affordance. Long-press kept as legacy shortcut.

---

## Bugfixes and Backends

### Google sign-in conflict loop (6a65fb6)
Two-tap anonymous logout race where re-authenticating with Google
after signing out anonymously would loop; fixed the auth-state
handling.

### Spades / clubs icon swap (4beb3ed)
Winner dialog + hand history were rendering the wrong suit glyph.
Same commit fixed unnamed player display in the same dialogs.

### Heads-up pot initialization (f013dab)
Pot didn't initialize when the hand started heads-up (2 players
only); +6 other critical bugs shipped in the same fix pass.

### In-app tour fixes (e7eb5b3, f013dab)
Multiple guided-overlay robustness issues, phase transition
mismatches, and hub-vs-legacy navigation bugs — see
`2026-07-14-in-app-tour-fixes-and-heads-up-pot-fix.md` and the
canonical reference `2026-07-15-in-app-tour-complete-reference.md`
for the full details.

---

## Simplifications

### One logging flow (9096d1b)
Removed the "individual logging mode" branch. Every session now goes
through the unified full-logging setup screen (redesigned in 3fcecd2
to match the design v2 spec).

### Persistent MainShell (36c6652)
Bottom nav now belongs to a shell that stays alive across detail
pushes rather than being duplicated on each screen. Detail screens
suppress it entirely for Apple-style focus mode.

---

## Files touched most (top 10)

| Rank | File | Commits |
|---|---|---|
| 1 | `lib/screens/home_screen.dart` | 14 |
| 2 | `lib/screens/session_details_screen.dart` | 13 |
| 3 | `lib/screens/poker_hand_screen.dart` | 12 |
| 4 | `lib/screens/session_history_screen.dart` | 10 |
| 5 | `lib/widgets/global_bottom_nav_bar.dart` | 9 |
| 6 | `lib/screens/my_opponents_screen.dart` | 9 |
| 7 | All 7 `.arb` locales | 9 each |
| 8 | `lib/screens/settings_screen.dart` | 8 |
| 9 | `lib/onboarding/onboarding_tour.dart` | 8 |
| 10 | `lib/screens/profile_screen.dart` | 7 |

---

## What this locks in (for future work)

1. **CLAUDE.md updated** — `/diary` folder is now authoritative; any
   change touching the in-app tour must respect
   `2026-07-15-in-app-tour-complete-reference.md`.
2. **Every new screen inherits** `BouncingScrollPhysics`, the
   `AppScrollBehavior`-registered scroll behaviour, and access to
   the canonical pill / dialog / sheet / top-nav components. Don't
   hand-roll these anymore.
3. **`AppSheet` is the canonical bottom-sheet scaffold.** Any new
   modal drawer should use it, not raw `showModalBottomSheet` +
   hand-rolled decoration.
4. **Numbers on primary screens count up** by default via
   `TweenNumber(animateOnMount: true)`. Follow the pattern on any
   new hero-number screens.
5. **Haptic feedback** is standard on nav / drawer / destructive
   actions — `selectionClick` for normal, `mediumImpact` for
   destructive.
6. **Bottom nav is on `MainShell` only.** Never `bottomNavigationBar:
   GlobalBottomNavBar(...)` on a pushed detail screen — that's the
   old pattern.

---

## Follow-ups deferred to next week

- **Skeleton loaders** on Profile / Profile Settings / Session
  Analytics / Opponent Detail — currently still spin.
- **Hero transitions** on event card → event detail (needs branching
  logic for personal vs club variants).
- **Home refresh indicator** — currently platform default. Could be
  swapped for a skeleton overlay while data reloads.
- **Currency picker extraction** — `_CurrencyPickerSheet` now exists
  in `bankroll_edit_screen.dart` and duplicates the one in Settings.
  Extract to `design_system/components/sheets/` and unify.
- **Nickname step** hasn't been redesigned to the v2 pattern yet
  (still uses the old label-above-input layout).
