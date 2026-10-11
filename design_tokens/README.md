# Design tokens — Final Table v3

- `tokens.json` — token values (source for the generated Flutter tokens)
- `guidelines/` — the design system rules: overview, table-side UX, poker conventions, writing, governance, Figma audit, token standards, component specs
- `AI_GUIDE.md` — the short version AI assistants follow (Cursor loads it via `.cursor/rules/final-table-design.mdc`)

`tokens.json` is the source of truth for the v3 redesign. It is exported from
the Final Table design system, which is synced from the Figma file
[finaltable_v3](https://www.figma.com/design/jSjfO86nt4bd9Vhkc9q7d9/finaltable_v3).

```bash
python3 tool/gen_design_tokens.py          # regenerate lib/design_system/tokens/ft_tokens.g.dart
python3 tool/gen_design_tokens.py --check  # fails if the Dart file is stale
```

## Updating a token

1. Change it in Figma (both modes), re-sync the design system.
2. Replace `tokens.json` here with the new export.
3. Run the generator and commit both files together.

Never edit `ft_tokens.g.dart` by hand.

## What gets generated

| Dart | From | Notes |
| --- | --- | --- |
| `FtColors` (`.dark`, `.light`) | semantic + component colour tokens | `ThemeExtension`; read with `context.ftColors`. Primitives stay private. |
| `FtTagColors`, `FtBrand.mark` | `tag-*`, `brand-mark` | Data/logo colours, same in both themes. |
| `FtTextStyles` | iOS text styles in 42dot Sans | No colour baked in; `.tabular` for figures. |
| `FtSpacing` (`s16`…), `FtRadius`, `FtSize`, `FtBorderWidth`, `FtOpacity` | Dimension collection | |
| `FtShadows` | effect styles | `FtShadows.focusRing(colors)` follows the theme. |

Deprecated `misc-*` aliases in `tokens.json` are skipped — they were never in
the app.

## Font

`assets/fonts/42dot_sans/` holds static Regular/Medium/SemiBold/Bold
instances of the OFL variable font from google/fonts, subset to Latin,
punctuation, currency, arrows, maths and card suits (≈36 KB each). 42dot Sans
has no Cyrillic, so Russian and Ukrainian text falls back to the system font.
