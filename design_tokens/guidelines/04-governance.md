# Governance

## Sources of truth

- **Figma `finaltable_v3` owns the values.** Variables (Primitives → Color, holding semantic and component tokens → Dimension), text styles and components are edited there first, then re-synced to the design system and `design_tokens/tokens.json`. The Flutter app consumes the generated `Ft*` tokens (`tool/gen_design_tokens.py`).
- **Rules live in `design_tokens/guidelines/`.** A rule that only exists in a Figma comment or a chat thread is not a rule.
- **One library.** Screens may only use variables, styles and components from `finaltable_v3`. Older libraries (`Final Table_v1`, `Finaltable_v2_new style`, wireframe kits) must be detached — see the audit.

## Naming

- Figma variables use `/` groups (`label/primary`); here and in code they become hyphenated (`label-primary`).
- Name by **role**, not value: `label-tertiary`, not `gray-400`. Primitives keep ramp names (`green-500`).
- Text styles follow Apple's ramp (`Headline`, `Footnote`); a heavier variant is `<Style>/Emphasized`.
- Component variants are `Property=Value` with consistent casing and units (`Value=70%`, not `Value=90`).
- Frames never ship with default names (`Frame 1321315649`) or status words (`(proposed)`) once in a published screen.

## Changing a token

1. Comment on the token in the design system (or in Figma) with the need, the screen and the proposed value.
2. Check it against existing tokens — most new colours are an existing role.
3. Prove contrast in **both** modes: 4.5:1 text, 3:1 for 24px+ text, borders, focus rings and meaningful icons.
4. Change it in Figma, re-sync the design system and `tokens.json`, regenerate (`python3 tool/gen_design_tokens.py`), bump `version` for any rename or removal, and keep the old name as an alias for one release.

## Review checklist (every new screen)

- [ ] Only `finaltable_v3` variables, styles and components — no raw hex, no foreign libraries
- [ ] One filled green action per screen
- [ ] Hit targets 44 pt or more for anything used at the table
- [ ] Results signed with + / − and coloured `text-success` / `text-danger`
- [ ] Works in Dark and Light
- [ ] Works offline; destructive actions undoable
- [ ] Copy follows Writing and Poker conventions
- [ ] Layers named, no `(proposed)` frames in final screens

## Component tokens

- A component binds only its own tokens (`button-*`, `textfield-*`, `toggle-*`, `focus-ring`). Each component token aliases a semantic token — never a primitive, never a hex.
- A new component gets a new group named after it. A token used by only one component belongs in that group, not in the semantic layer.
