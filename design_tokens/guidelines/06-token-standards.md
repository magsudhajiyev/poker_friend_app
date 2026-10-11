# Token standards audit

Every token in `finaltable_v3` checked on 8 Oct 2026 against the current references: the **W3C Design Tokens Format Module 2025.10** and its Resolver Module (first stable release, 28 Oct 2025), **WCAG 2.2 AA** (4.5:1 text, 3:1 non-text), **Apple HIG** (44 pt targets, Dynamic Type, Increase Contrast) and the common **three-tier token architecture** (primitive → semantic → component).

## Scorecard

| Area | Status | Notes |
| --- | --- | --- |
| Tiering | ● Good | Primitives (61) → Color (82 semantic + 27 component tokens, Light/Dark) → Dimension. Button and Toggle bind only their component tokens. Primitives are now hidden from publishing, so consumers can only pick semantic tokens. Exceptions by design: the logo binds `brand/mark`, Color Swatch binds `tag/*` (data colours). |
| Contrast — text | ● Pass | Every text token clears 4.5:1 on every surface in both themes, except `label-quaternary` (decorative only) and disabled text (exempt). |
| Contrast — non-text | ● Pass | Icons, borders, focus ring, toggles, progress clear 3:1. |
| Colour-blind safety | ◐ Mitigated | Profit vs loss green/red collapse for deuteranopes in Light (1.3:1). Meaning is carried by the mandatory **+ / −** sign. |
| Scopes | ● Good | Every variable is scoped; fill colours (`accent-*`) can no longer be applied to text. |
| Code syntax | ● Good | All 176 variables carry a WEB code name (`var(--label-primary)`). iOS/Flutter names to add once the app code is linked. |
| Descriptions | ● Complete | Every variable has a usage description. |
| Interchange format | ● Added | `dtcg/` holds a 2025.10-conformant export (colour objects, `{value, unit}` dimensions, composite shadows and typography) and a resolver with a `theme` modifier (dark default). Works with Style Dictionary 4, Terrazzo and Tokens Studio. |
| Token families | ◐ Partial | Colour, spacing, radius, size, border width, opacity, typography, shadow. Motion exists only in the export (proposed). Typography lives in text styles, not variables. |
| Naming | ◐ Improved | `misc/` retired into `button/`, `textfield/`, `toggle/`, `focus/` (8 Oct). Still open: status tokens split across five families, opaque "overlay" tokens (decisions 1–2). |
| Accessibility settings | ○ Missing | No Increase Contrast mode, no Dynamic Type scaling. |
| Usage | ◐ | 37 of 82 semantic tokens are unused today (states and statuses no screen has yet). |

## Fixed today (no renames, no visual change outside the noted items)

- **Placeholder text** was 3.5–3.8:1. Now `gray-550` Light / `gray-400` Dark: 4.5:1+ on every surface. Placeholders look slightly stronger.
- **Error border** was 2.9:1 on grey surfaces in Light. Now `red-600` in Light: 3:1+.
- **Scopes**: `accent/*` limited to fills and strokes.
- **Primitives hidden from publishing** (they stay available inside the file).
- **Collection renamed** `Tokens` → `Dimension` (bindings unaffected).
- **New Dimension tokens** taken from values already in the file: `size/icon/xs…2xl` (14–32), `size/hit-target` (44), `border-width/hairline|selected|focus` (1/2/3), `opacity/glass|glass-strong|track-empty`.
- **Code syntax** completed on 26 variables; **descriptions** added to 22.
- **Spacing notes**: `spacing-10` and `spacing-14` flagged as off the 4 pt grid ("avoid in new work"); `20/40/56/72` flagged unused.
- **W3C export** added under `dtcg/` (see Consuming).

## Component tier — applied 8 Oct 2026

1. **`misc/` retired.** `misc/button/*` → `button/primary/*`, `misc/textfield/*` → `textfield/*`, `misc/toggle/*` → `toggle/*`, `misc/focus-ring` → `focus/ring`, `misc/link` → `text/link`, `misc/selection` → `bg/selection`, `misc/textfield/bg-disabled` → `fill/disabled`. Figma bindings were kept (renamed in place).
2. **Components wired.** 26 new `button/*` tokens (bg, border, label, icon per style, destructive and disabled) plus `toggle/state-label`. The Button set's 155 paints and the Toggle now bind only component tokens. Every new token aliases the semantic token it replaced, so nothing changed visually in either theme.
3. **Old names kept one release.** The 19 `misc-*` names stay in `tokens.json` and the DTCG export as deprecated aliases (`$deprecated`), removed in the next release.

## Decisions — breaking or visual, not applied

1. **One status structure.** Today a status is spread over `accent/`, `text/`, `icon/`, `bg/notification/`, `border/notification/`. Standard form: `status/{success|warning|danger|info}/{fill|text|icon|surface|border|on-fill}`.
2. **Remove or repurpose unused tokens** (37): `overlay/*` (opaque greys named "overlay"), `bg/grouped/*`, `label/vibrant/*` (now unused), `bg/scrim` vs `overlay/scrim` (duplicate role), unused statuses and hover states.
3. **Increase Contrast modes** (`Light HC`, `Dark HC`): 7:1 text, 4.5:1 non-text — what iOS users get with *Settings → Accessibility → Increase Contrast*.
4. **Typography as variables** with a Dynamic Type mode (Default / Large) so text styles scale like iOS.
5. **Motion tokens in Figma** (durations, easings) — today only in the export, marked proposed.
6. **Colour-blind–safe results** — optionally shift `text-success` toward teal, or keep green and rely on the sign.

## Consuming

`dtcg/resolver.json` is the entry point: foundation set (`primitives`, `dimension`, `typography`) → `theme` modifier (`dark` default, `light`) → `effects`. Pass `{ "theme": "light" }` to resolve Light. The page's own `tokens.css` remains the quickest way to use the tokens in a web preview.
