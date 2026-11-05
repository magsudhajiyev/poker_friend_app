# Web parity goldens

The web dashboard (`final-table-web`) ports these pure Dart modules to
TypeScript: `stats_calculator`, `leak_extractor`, `leak_engine`,
`board_texture`, `flop_strength`, the pure parts of `range_grid_service`,
`pokerstars_export_service`, `csv_export_service`. The TS output must match
Dart exactly. These goldens are generated FROM Dart and are the contract.

## Layout (`test/fixtures/web_parity/`)

- `hands/*.json` input corpus: one Firestore-shaped hand map per file (synthetic, no real user data). Extra key `_tags` lists coverage tags and is ignored by Dart. Extra key `id` is the file name; `sessionId` links to a session.
- `sessions/*.json` session docs the exporters need (blinds, `hasBBante`, `buyInAmount`, `gameType`).
- `expected/{id}.json` per-hand goldens. `expected/_corpus.json` corpus-wide goldens.
- `build_corpus.py` authoring script that wrote `hands/` and `sessions/` (stacks/pots stay consistent). Editing the JSON by hand is fine too.

## Regenerate

```bash
UPDATE_GOLDENS=1 flutter test test/web_parity/generate_goldens_test.dart
```

Without the env var the same test only checks that goldens are current and fails with `stale:`, `missing:` or `orphaned:` entries.

## The rule

Whenever the Dart logic (or the corpus) changes:

1. Run the command above.
2. Copy `test/fixtures/web_parity/{hands,sessions,expected}` to `final-table-web/src/core/__fixtures__/`.
3. Fix the TS port until its tests match.

## Comparison notes for the TS port

- JSON keys are sorted; compare structurally, not textually.
- Dart doubles serialize as `1.0`, JS reads `1`. Compare numbers numerically. Text fields (`pokerstars`, `csv`) are exact strings and DO contain Dart double formatting (`CSV` amounts print `6.0`, never `6`; `_fmtAmt` in PokerStars drops trailing zeros).
- `0.875.toStringAsFixed(2)` style rounding appears in `dec_odd_amounts_showdown`; JS `toFixed` must agree.
- PokerStars timestamps use UTC because corpus times end in `Z`. Hand ids are a 31-bit string hash (`& 0x7FFFFFFF` after each step); reproduce with 32-bit math.
- Leak analyses are replayed at x1 / x6 / x20 corpus size (`leakMultiplicities`); refs get `#k`. This reaches the emerging and confirmed branches that the 74-hand corpus alone cannot.

## Golden shapes

See the generator for exact fields. Outline:

`expected/{id}.json`: `id`, `completeness`, `pokerstars` (string, `""` for non-full), `csv` (string), `stats` {`heroSeat`, `isWalk`, `bigBlindSeat`, `smallBlindSeat`, `hero` (flags | null), `seats` {seat: flags}, `actionFlags[]` {`isBlind`,`isRaise`,`isBet`,`isAggressive`}}, `leakFacts` (object | null), `rangeEntry` (object | null), `rangeLine` {`primaryAction`,`line`,`scenario`,`heroStackBB`} | null.

`expected/_corpus.json`: `handIds`, `leakMultiplicities`, `leakAnalyses` {`x1`,`x6`,`x20`: report}, `sessionExports` {sessionId: {`handIds`,`pokerstars`,`csv`}}, `rangeGrid` {`entriesIndexed`, named aggregates handClass → {allIn,raise,call,fold,check,total}}, `functionCases` {`canonicalHandClass`, `positionGroup`, `classifyFlop`, `flopStrength`, `heroStackBB`, `derivePreflopLine`}.

## Not covered

- `RangeGridService.aggregateByHandClass`/`queryHandClass`/`indexHand`/backfill need SQLite/Firebase. The corpus aggregate replays the SQL (`GROUP BY handClass, primaryAction` + the same filters) in Dart through the real `RangeCellAggregate`.
- `exportAndShare` / `exportSessionAndShare` (file + share sheet), `CSVExportService.generateFilename` (uses `DateTime.now()`), `csvToBytes`.
- `RangeGridCloudBackfill._entryFromCloudHand` is private; the generator mirrors its mapping.
- Side pots: the stored hand format has no side-pot structure, so side-pot hands only exercise the multiway all-in action amounts and `individualShares`.
