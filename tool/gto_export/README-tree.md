# Solver full-tree → authored_spots (Firestore)

Reads a solver "full tree" export Google Sheet and builds the navigable game-tree
JSON the app walks (`lib/models/authored_tree.dart`), optionally uploading it to
`authored_spots/{id}` in Firestore.

## One-time setup

1. **Service account key.** In Firebase Console → Project Settings → Service
   Accounts → *Generate new private key*. Save it as:
   `tool/gto_export/service-account.json`  (gitignored).
2. **Share the sheet** with the service account's `client_email` (read access).
   The same account needs Firestore write access (default for the project
   service account).
3. Install deps (once):
   ```bash
   cd tool/gto_export && npm install
   ```

## Build a spot

```bash
cd tool/gto_export
# Dump JSON only (review first):
node build_tree.js --sheet <SHEET_ID> --hero 99 --id lj-btn-ts9c4d-99 --out tree.local.json
# Then upload when happy:
node build_tree.js --sheet <SHEET_ID> --hero 99 --id lj-btn-ts9c4d-99 --upload
```

- `--sheet`  the Google Sheet ID (from its URL).
- `--hero`   the hero hand class to stamp on the tree (99 / TT / KQs / JTs).
             Omit to leave the tree hand-agnostic.
- `--id`     the Firestore doc id (`authored_spots/<id>`).
- `--out`    local JSON file for review (default `tree.local.json`).
- `--upload` also write the doc to Firestore.
- `--tab`    explicit sheet tab name (defaults to the first tab).

The script prints the node count and how many non-fold edges are terminal
(these are the showdown / hand-over leaves — expected).

## Notes

- Sheet columns expected (from the extraction prompt):
  `Date | Hand | Street | Board | Step | Spot | Actor | Actions available |
  Sizing | Range (hand:raise/call/check/fold/allin)`.
- `bet` is normalized to `raise` so it fits the app's five actions.
- Nodes link by the action-history encoded in the `Spot` column. If a child
  isn't found, that edge is a terminal leaf (hand ends there).

## Scheduling a day

A Daily Challenge day serves up to 5 uploaded trees, in order. The day key is
the player's LOCAL date. Days without a schedule play the RNG challenge.

```bash
node schedule_day.js --day 2026-10-22 --hands id1,id2,id3,id4,id5   # every id must exist in authored_spots
node schedule_day.js --day 2026-10-22 --show
node schedule_day.js --day 2026-10-22 --clear
```

Clients read `authored_days/{day}` only after the Firestore rules are deployed;
until then the bundled `assets/authored/days.json` is the fallback.
