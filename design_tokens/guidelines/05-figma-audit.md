# Figma audit

The audit of `finaltable_v3` from 7 Oct 2026 and what was done about it. **Fixed** items were changed in the Figma file on 8 Oct 2026 and re-synced to the design system; **Open** items need a decision.

## Fixed

### Foreign libraries
- Every variable bound from another library (about 190 bindings across Home, Tab Bar, Sheets, Alerts, List items, Toggles, Logos) now points at a finaltable_v3 variable: white/active → `label-primary` / `icon-primary`, inactive greys → `label-tertiary` / `icon-tertiary`, `#2c2c2e` selection → `fill-secondary`, foreign borders → `separator-opaque`, foreign `space/*` and `radius/*` → `spacing-*` and `radius-*`. Only the iOS status bar (a system element) keeps its kit colours.
- The `Body/SM Medium` text style (IBM Plex Sans) on the chart legend → `Footnote/Emphasized`.
- `Chips` and `Color Swatch / On Inverse` came from the v2 library. They are now local components on a new **Chips** page (`Chip`, `Color Swatch` with Color × Selected), with the opponent colours as `tag/*` variables. The 14 instances in the sheets were swapped over.
- The remote `Card icons` tile on Home was detached so the four stat tiles match.

### Contrast (Light mode)
| Token | Was | Now | Worst ratio |
| --- | --- | --- | --- |
| `text-success`, `text-accent`, `misc-link` | green/700, green/600 | green/800 | 3.5 → 6.2:1 |
| `icon-accent`, `icon-success`, `accent-primary`, `accent-success` | green/600, green/500 | green/700 | 2.1 → 3.5:1 |
| `misc-focus-ring`, `misc-textfield-border-focus`, `misc-button-border` | green/500, green/600 | green/700 | 1.4 → 3.5:1 |
| `label-tertiary` | gray/500 | new gray/550 #525252 | 3.8 → 6.2:1 |
| `misc-textfield-border` (both themes, outlines only) | gray/300 · gray/600 | gray/500 | 1.2 → 3.5:1 |
| `text-disabled`, `icon-disabled` (Dark) | gray/600 | gray/500 | 1.2 → 3.5:1 |
| Bankroll / stats values (raw white 45%) | raw | `label-tertiary` | — |

`accent-primary` stays `green/700` in Light: it is a fill/shape colour (3:1 rule, 3.5:1+). Its one text use — "Log a session" in `Session Card / Empty` — now uses `text-accent`, and the variable can no longer be applied to text in Figma.

White on the red `accent-danger` fill was 3.2:1 (Dark) / 3.6:1 (Light). New `text-on-danger` and `icon-on-danger` (black: 6.7:1 / 5.8:1) now sit on every destructive prominent button and the Alert pop-up's destructive action. Two text layers that used the fill colour `accent-danger` as text (the `−$40` loss in Session Result and a "System default" list item) now use `text-danger`.

`misc-textfield-border` was also painting 34 bottom-only row dividers (Home stat rows, list items, language menu, sheet rows), so raising it made those lines too bright. The dividers now use `separator-opaque` (their original Dark look); the token is left on the 23 text-field outlines, where 3:1 applies.

### Variables and styles
- Deleted: the 10 `gray/*` pass-throughs in the Color collection (one stray alias, `overlay/scrim`, was repointed to the primitive), the unused `terracotta/*` ramp, `misc/window/*`.
- Added: `gray/550`, `brand/mark` (logo green, now bound in the logo), `gold/400` + `icon/tournament` (trophy, was hard-coded #ffc800), `tag/*` (6), `radius/2xl` (24).
- Every Color and Primitive variable now has a description.
- Effects: Elevation shadows are neutral black (were brown); `Focus/Ring` is a 3px ring bound to `misc/focus-ring` (was terracotta 40%); new `Elevation/Floating` replaces the unstyled tab-bar/button shadow.
- Text styles added: `Display` (bankroll figure, was raw 47px), `Caption 3` and `Caption 3/Emphasized` (tab labels, were raw 10px). Chart axes (Roboto Mono) → `Caption 2`; bankroll empty-state copy → `Title 3/Emphasized` and `Subheadline`.

### Components
- **Button**: Large/Bordered gained its `bg/elevated` fill; Large/Bordered Secondary is 50pt (was 46); Large/Borderless uses `text/accent` like Small and Medium; Large paddings bound to `spacing/14`; destructive prominent buttons use black `text/on-danger` / `icon/on-danger` on the red fill.
- **Bankroll**: corner radius → `radius/2xl`; Edit button label "Edit bankroll", green on Home like the component.
- **Section Header** paddings, **Progress bar** radii (`radius/full`), **Tab bar** insets (`spacing/24`) and its glass now theme-aware.
- **Wordmark** letters bound to `label/primary`, so the logo shows in Light.
- Pages that previewed in Light by accident (Bottom Nav, Sheets and modals, Tabs, Toggles, Grabber, Status Bar, Flags) are now set to Dark like the rest; 101 nested "force Dark" overrides inside components were removed so components follow the screen's theme.

### Copy and naming
- Typos (Aggressive, aligned, horizontal), `Value=90%/100%`, "(proposed)" frame names, hidden duplicate tab bars (7 Oct).
- True minus everywhere: `−$50`, `−450`, `−$40` (Session Result sheet).
- "Edit bankroll" in sentence case; alert copy "Changes applied" (no exclamation mark).
- The "Log your first session" banner is hidden on Home/Filled.
- **Documentation** page: the Color tokens doc now reads live variables (swatches bound per mode), its counts, ramps and "don't flip" list are current, and gaps 01 and 03 are marked resolved. The Button spec's 46px note is marked resolved.

## Open — need a decision

1. **Purple glow** behind the status bar on Home/Filled (`#4c00a9` ellipse + a `#142635` 11% tint) is outside the palette and missing on Home/Empty. Keep it as a brand moment (then make it a token) or remove it?
2. **Stat tile colours** on Home (blue, purple, green, red tiles) are raw hex. Fine as illustration colours, or should they map to `accent-*`?
3. **App icon ground** is `#101014` (blue-black), not `gray/900`. Intentional for the App Store icon?
4. **Small (26pt) and Medium (37pt) buttons** are below the 44pt iOS minimum. Keep for off-table use with an enlarged hit area in code, or raise them?
5. **Three background roles collapse in Light** (`bg/secondary`, `bg/grouped/primary`, `bg/grouped/tertiary` are all gray/100) — from the file's own Documentation page.
6. **Hover/pressed tokens exist but the Button set has no Pressed state.**
7. **Home Bankroll blocks are detached frames**, not instances of the `Bankroll` component.
8. **Default layer names** (`Frame 1321315649`) remain throughout.
