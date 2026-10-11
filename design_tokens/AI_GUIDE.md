# Building UI in Final Table — guide for AI assistants

Read this before writing or changing any UI in `lib/`. The full rules are in
`design_tokens/guidelines/` (start with `00-overview.md`); this page is the
short version you must follow every time.

## The redesign in one paragraph

The app is moving from the old "Modern Dark" look (teal, IBM Plex Sans, glassy
cards, `AppColors`/`AppTypography`) to **Final Table v3** (green brand ramp,
42dot Sans, solid surfaces, Dark + Light), defined in Figma `finaltable_v3`.
Screens move **one at a time**. A screen is either fully v3 or still old —
never mix v3 components and old `App*` styling on one screen.

## Tokens — the only allowed values in v3 code

| Need | Use | Never |
| --- | --- | --- |
| Colour | `context.ftColors.<token>` (e.g. `labelPrimary`, `bgElevated`, `textSuccess`) | `Color(0x…)`, `Colors.*`, `AppColors.*` |
| Text | `FtTextStyles.<style>.copyWith(color: …)`; `.tabular` for figures | inline `fontSize`/`fontWeight`, `GoogleFonts.*`, `AppTypography.*` |
| Spacing | `FtSpacing.s4 … s72` | numeric padding/gap literals |
| Radius | `FtRadius.md/lg/xxl/full` | `BorderRadius.circular(12)` |
| Sizes | `FtSize.icon*`, `FtSize.hitTarget` (44) | |
| Strokes / opacity / shadows | `FtBorderWidth`, `FtOpacity`, `FtShadows` | |
| Opponent colours | `FtTagColors` | |

Tokens are generated from `design_tokens/tokens.json` by
`python3 tool/gen_design_tokens.py`. Never edit `ft_tokens.g.dart` by hand; a
missing token is a design-system change (see `guidelines/04-governance.md`).

## Components

Use the v3 widgets in `lib/design_system/components/v3/` (`Ft<Name>`). Specs and
build status: `guidelines/07-components.md`. If a screen needs a component
that isn't built yet, build it there first (own branch, tests, gallery entry),
then use it. Components read their **component tokens** (`buttonPrimaryBg`,
`textfieldBorder`, `focusRing`), not semantic ones.

## Rules that are easy to break

- One filled green (`prominent`) action per screen.
- Tap targets ≥ 44pt for anything used at the table.
- Results: profit `textSuccess` with **+**, loss `textDanger` with **−**
  (U+2212, not a hyphen). Never colour alone.
- Text on a green fill: `textOnAccent`; on a red fill: `textOnDanger`.
  `accentPrimary` is a fill colour — green **text** is `textAccent`.
- Must work in Dark and Light (`FtColors.dark` / `FtColors.light`).
- Sizes stay responsive (see CLAUDE.md "Responsive Design"); text scales with
  the system text size — don't clamp it.
- All user-facing strings via `AppLocalizations` — writing rules in
  `guidelines/03-writing.md`, poker notation in `guidelines/02-poker-conventions.md`.
- Destructive actions: confirm with `ConfirmDialog` and offer undo.

## Before you finish

1. `flutter analyze` and `flutter test test/design_system/`
2. `python3 tool/design_lint.py` — the hardcoded count must not go up
3. Add new components to the Design v3 gallery (`lib/screens/design_v3_gallery_screen.dart`)
4. Every change on its own branch from `design_v2`; open a PR into `design_v2`.
   Don't push to `design_v2` or `main` directly.
