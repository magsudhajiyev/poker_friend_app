# Final Table design system

Final Table is a live poker tracker for iOS: log a hand in three gestures, not three minutes, and study every session afterwards. This system is synced from the Figma file **finaltable_v3** — its variables, text styles, logos and components. Notes and component docs paraphrase the file's own descriptions. Read this page, then `01-table-side-ux.md`, `02-poker-conventions.md`, `03-writing.md`, `04-governance.md`, `05-figma-audit.md`, `06-token-standards.md` and `07-components.md` in this folder. Token names below are the design-system names (`label-primary`); in Flutter they are camelCase on `FtColors`, `FtTextStyles`, `FtSpacing`, `FtRadius` (`context.ftColors.labelPrimary`) — see `design_tokens/README.md`.

## Principles

1. **Three gestures, not three minutes.** A hand-logging flow that needs a fourth tap must justify it in review.
2. **One thumb, bottom half.** In-hand actions live in the bottom of the screen, never smaller than a 44×44 hit target.
3. **Glanceable over complete.** At the table show one figure big (`large-title`), not a dashboard.
4. **Discreet by default.** Dark, quiet, no sound or full-screen flashes — opponents can see the screen.
5. **Never lose a hand.** Inputs save instantly, work offline, and destructive actions have undo.

## Colour

- The app ships in the **Dark** theme; **Light** exists in the file and must keep working. Never hard-code a hex — use the semantic tokens below; primitives (`gray-*`, `green-*`, …) are only for building semantic tokens.
- Paint screens with `bg-primary`. Put cards on `bg-elevated` with a 1px `separator-opaque` border (`SessionCard`), and hero blocks on `bg-secondary` (Bankroll).
- Neutral controls and icon tiles sit on `fill-primary`; tracks use `fill-secondary`.
- Text: `label-primary` for titles and values, `label-tertiary` for metadata (durations, dates, stat values, axes). Text on a green fill is `text-on-accent`; on a red fill `text-on-danger`.
- Green is the brand. The primary button is `button-primary-bg`, progress fills are `accent-primary`, link-style actions are `text-accent`. Use one filled green action per screen.
- Results: profit in `text-success` with **+**, loss in `text-danger` with **−** (U+2212). Never colour alone — green vs red differ by only 1.7:1 in lightness.
- Tournament glyphs use `icon-tournament`; opponent tags use the `tag-*` colours through `ColorSwatch`. The `brand-mark` green is for the logo only.
- Both themes meet contrast: text 4.5:1 and icons, borders and the focus ring 3:1 on every surface. The one exception is `label-quaternary`, which is for placeholders and decoration only.

## Typography

- One family: **42dot Sans** (Google Fonts), falling back to the iOS system font. The scale is Apple's text styles with the file's exact metrics — `large-title` 34/41 down to `caption-2` 11/13, each with an `-emphasized` weight — plus `display` (47/41, the bankroll figure) and `caption-3` (10/12, tab labels only).
- Hero figure: `display` (one per screen). Screen title: `large-title`. Section headers: `headline`. Card titles: `callout-emphasized`. Metadata: `footnote`. Results in rows: `body-emphasized`.
- Button labels: `footnote` (Small), `callout` (Medium), `body-emphasized` (Large).
- Figures that update or align in columns use `font-variant-numeric: tabular-nums`. Chart axes use `caption-2`.

## Space, shape, elevation

- Spacing is a 2/4px scale named by pixel value: `spacing-2` … `spacing-72`. Screen gutter `spacing-16`; between sections `spacing-24`.
- Radii: buttons, chips, swatches, the tab bar and progress bars are `radius-full`; sheets and the Bankroll card `radius-2xl`; cards `radius-lg`; type chips and icon tiles `radius-md`.
- In Dark, elevation is surface shade (`bg-primary` → `bg-elevated` → `bg-elevated-high`). Floating bars (tab bar, top-bar buttons) carry `floating-bar`. Shadows are neutral black; the focus ring is a 3px `focus-ring` ring.

## Components

`Button` (4 styles × 3 sizes × destructive × enabled), `IconButton`, `TopBar`, `SectionHeader`, `SessionCard`, `ProgressBar`, `Bankroll`, `TabBar`, `Chip` and `ColorSwatch` are specified in `07-components.md`, with their Flutter status.

Components read **component tokens**, not semantic ones: `button-*` (26, per style × destructive × disabled, with `-label` and `-icon`), `textfield-*`, `toggle-*` and `focus-ring`. Each one aliases a semantic token, so retheming a component means repointing its tokens, never editing the component. New components get their own group the same way.

## Iconography

- Icons are **Phosphor** (Regular weight, filled outlines) from a linked library: HouseSimple, UsersThree, ChartBar, Clock, QrCode, List, X, CaretLeft, GameController, Numpad.
- Sizes: 28 in the tab bar, 32 in top-bar buttons, 24 in card chips, 14/16/20 in Small/Medium/Large buttons.
- Colour with `icon-*` tokens; in Flutter, set the colour once with `IconTheme` (FtButton does this for its icon). Glyphs on a green fill are `icon-on-accent`; on a red fill `icon-on-danger`.
- Row chevrons are a 1.5px stroked caret in `icon-secondary`, not the Phosphor CaretRight.

## Logo

Six variants live under **Logos**: the horizontal and stacked wordmarks, the app icon (plain and outlined), and the app icon with a plus badge (framed and frameless). The wordmark is lowercase **final table** with a `brand-mark` green square over the "i". In Figma its letters are `label-primary`, so it flips with the theme; the exported files are the Dark (white) version. Use the horizontal wordmark in the top bar; never recolour or redraw it.

## Not covered yet

- Logo files — the six SVGs live in the design system page, not in this repo yet.
- Components in Figma with no spec yet: Toolbar nav (7) and sheet (2) variants, Text Field (24), Radio Button (12), Toggle, Tabs, Alerts and Alert pop-up, Sheets and the eight sheet layouts, Search Input, List items, Grabber, Flags, `Session Card / Empty`, `Progress indicator - set` and the Bankroll Empty state.
- Icons GameController, Numpad and UsersThree as separate files.
