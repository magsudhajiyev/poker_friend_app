# Components

The v3 component set from Figma `finaltable_v3`. Each entry is the spec to build against; Flutter widgets live in `lib/design_system/components/v3/` and are named `Ft<Component>`.

| Component | Figma node | Flutter |
| --- | --- | --- |
| Button | `170:626` | `FtButton` — built (PR #12) |
| IconButton | `68:280` | not built yet |
| TopBar | `86:988` | not built yet |
| SectionHeader | `276:130` | not built yet |
| SessionCard | `387:274` | not built yet |
| ProgressBar | `251:3652` | not built yet |
| Bankroll | `251:3529` (figure), `639:3151` (Bankroll Card) | not built yet |
| TabBar | `251:1718` | not built yet |
| Chip | `612:2581` | not built yet |
| ColorSwatch | `612:2634` | not built yet |
| Icon | `—` | not built yet |

Also in Figma, not specified here yet: Toolbar nav and sheet variants, Text Field, Radio Button, Toggle, Tabs, Alerts, Sheets, Search Input, List items, Grabber, Flags.

## Button

States: Enabled, Pressed (Bordered Prominent only — `button-primary-bg-pressed`; other styles press with a 97% scale), Disabled.

Pill button in four styles and three sizes — the file's `Button` set (Size × Style × Destructive × State).

**Use** `prominent` for the one commit action on a screen (green, `button-primary-bg`), `bordered` for a neutral alternative, `secondary` for low-emphasis actions on a tinted fill, `borderless` for link-style actions in `text-accent`.

**Sizes** Small: Footnote label, 14px icon. Medium: Callout, 16px icon. Large: Body/Emphasized, 20px icon.

**Do** use Large for anything tapped at the table; Small only off-table, with a 44pt hit area in code.
**Don't** put two `prominent` buttons on one screen, or use `destructive` without an undo.

All three sizes now share one recipe per style (the Large variants were brought in line in Figma on 8 Oct 2026). Destructive prominent buttons use `text-on-danger` / `icon-on-danger` (black) on `accent-danger` — 6.7:1 Dark, 5.8:1 Light — mirroring black on the green primary.

## IconButton

Round 44pt icon button for top bars and sheets — the file's `Buttons - Top - Sheets`.

Surface `bg-elevated-high`, glyph `icon-primary`, shadow `floating-bar`. Use for QR scan, menu, back and close; never for primary actions.

## TopBar

The home screen's top bar: the horizontal wordmark on the left and up to two `IconButton`s on the right — the file's `Toolbar - Top - homepage`.

In Figma the wordmark ink is now `label-primary`, so it flips with the theme; the Logos assets here are the white (Dark) export. The seven `Toolbar - Top - Nav` and two `Toolbar - Top - Sheet` variants are not built yet.

## SectionHeader

Section title row with optional meta text or action — the file's `Section Header` (Title · TitleWithText · TitleWithButton).

Title is `headline` in `label-primary`; padding `spacing-8` × `spacing-16`. Title Case for the title, sentence case for the action ("View all").

## SessionCard

Recent-session row: type chip, title, duration • date, signed result and chevron. Tapping opens the session detail — the file's `Session Card` (Type × Result).

Card `bg-elevated` + `separator-opaque`, `radius-lg`, 72pt tall; stack cards 12pt apart. Type glyphs: cash in `icon-accent`, tournament in `icon-tournament`. `Session Card / Empty` is not built yet.

## ProgressBar

Goal progress track — the file's `Progress bar` (Value=Empty, 0–100%).

Track `fill-secondary`, fill `accent-primary` (3.5:1 Light, 9.2:1 Dark), both `radius-full`, 6px tall inside a 44pt row with `spacing-16` insets. Print the percentage next to it, as Bankroll does.

## Bankroll

In Figma the full hero card is the **Bankroll Card** set (`Goal=Set`, `Goal=None`), which nests the Bankroll figure (`State=Visible/Hidden/Empty`), the progress indicator and the "Edit bankroll" button.

Home hero card: bankroll figure, goal, progress and an Edit action, with a privacy toggle that blurs the figure — the file's `Bankroll` (Visible · Hidden · Empty).

Card `bg-secondary` with a `separator-opaque` border and `radius-2xl`. The figure is the `display` text style; the empty-state labels are `label-tertiary`. The edit button is a Small prominent `Button` labelled "Edit bankroll".

## TabBar

Floating bottom navigation with four tabs and a separate "+" action — the file's `Tab Bar - Final Table`.

Glass bar: a 3% `label-primary` wash with `floating-bar` shadow, so it reads in both themes. Active tab: `fill-secondary` pill, `label-primary`, `caption-3-emphasized`; inactive `icon-tertiary` / `label-tertiary`, `caption-3`. Insets `spacing-24`.

## Chip

Static label chip used for feature lists and tags — the file's `Chip` (brought into finaltable_v3 from the old v2 library on 8 Oct 2026).

Text `caption-1` in `label-primary`, 1px `separator-opaque` border, `radius-full`. Not interactive — for a selectable pill use `Button` Small Bordered.

## ColorSwatch

Opponent colour picker: a row of round swatches, one selected — the file's `Color Swatch` set (Color × Selected).

Swatch fills are the `tag-*` primitives (data colours, same in both themes); the selected ring is `label-primary`, so it shows in both themes. Each swatch is a radio with the colour name as its label, 36pt target.

## Icon

The Phosphor glyphs used in the file, single-ink and coloured by `currentColor`.

Colour icons with `icon-*` tokens on the parent. `chevron` is the 1.5px stroked caret used at the end of rows. GameController and Numpad (stat tiles) are not included yet.

## Home stat tiles

The four tiles in Home's Recent Activity rows bind `stat-tile-play-style`, `stat-tile-sessions`, `stat-tile-win-rate` and `stat-tile-hours` (Flutter: `statTilePlayStyle`…). They are illustration colours, same in both themes except Win Rate, which follows `accent-primary`. They carry no status meaning — Hours is red but is not a loss.

## Tab bar glass

The tab bar and its "+" button use `tab-bar-glass` (3%) and `tab-bar-glass-strong` (5%). The alpha is part of the token, so apply them at full opacity — don't add an opacity on top.
