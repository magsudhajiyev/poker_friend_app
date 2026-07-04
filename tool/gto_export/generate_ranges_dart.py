#!/usr/bin/env python3
"""Build-time export: poker_friend_engine range data -> Dart chart sets.

Reads the engine repo's app/core/gto_engine/data/mtt/{100bb,60bb,40bb} trees
(real Peak GTO scrapes — the user has authorized using this chart data for
drill calibration) and emits lib/services/drill_gto_ranges_data.dart, which
DrillGtoCharts consumes for the MTT/ante drill format. The app never fetches
anything at runtime — this bakes the numbers into the binary so drills stay
fully offline.

Usage (from poker_friend_app repo root):
    python3 tool/gto_export/generate_ranges_dart.py [path-to-poker_friend_engine]

Membership rules (documented in the generated header too):
- RFI set: raise_pct + allin_pct >= 35 (mixed-frequency opens count as opens
  when raised at least ~1/3 of the time; boundary mixes are handled by the
  grader's close band).
- Defend/vs-3bet: hand continues when raise+allin+call >= 35; it goes in the
  raise set when raise+allin > call, else in the call set.
- vs-3bet charts are averaged across all 3-bettor seats for the hero's seat
  (the app keys these by hero position only).
- SB continue set: fold_pct < 50 in the SB open file (complete-or-raise).
- SB fold-mix set: fold_pct >= 25 — hands the solver genuinely mixes folds
  with, so the grader doesn't punish a fold there.

Position-group -> engine seat mapping: EP=utg+1, MP=hj, CO=co, BTN=btn,
SB=sb, BB=bb.
"""

import json
import os
import sys

APP_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
ENGINE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(APP_ROOT, "..", "poker_friend_engine")
DATA = os.path.join(ENGINE, "app", "core", "gto_engine", "data")
OUT = os.path.join(APP_ROOT, "lib", "services", "drill_gto_ranges_data.dart")

SEAT = {"EP": "utg+1", "MP": "hj", "CO": "co", "BTN": "btn", "SB": "sb", "BB": "bb"}
GROUPS = ["EP", "MP", "CO", "BTN", "SB", "BB"]
DEPTHS = ["100", "60", "40"]
RANKS = "AKQJT98765432"


def hand_sort_key(h):
    return (RANKS.index(h[0]), RANKS.index(h[1]), h[2] if len(h) > 2 else "")


def load(path):
    with open(os.path.join(DATA, path)) as f:
        return json.load(f)


def g(v, k):
    x = v.get(k)
    return 0.0 if x is None else float(x)


sets = {}
approx_keys = set()


def put(key, hands, from_files):
    sets[key] = sorted(hands, key=hand_sort_key)
    for p in from_files:
        meta = load(p).get("metadata", {})
        if meta.get("quality") == "approximation":
            approx_keys.add(key)


for depth in DEPTHS:
    # RFI + SB complete strategy
    for grp in ["EP", "MP", "CO", "BTN", "SB"]:
        p = f"mtt/{depth}bb/open/{SEAT[grp]}.json"
        fr = load(p)["frequencies"]
        put(f"mtt|{depth}|rfi|{grp}",
            {h for h, v in fr.items() if g(v, "raise_pct") + g(v, "allin_pct") >= 35},
            [p])
    p = f"mtt/{depth}bb/open/sb.json"
    fr = load(p)["frequencies"]
    put(f"mtt|{depth}|sbContinue",
        {h for h, v in fr.items() if g(v, "fold_pct") < 50}, [p])
    put(f"mtt|{depth}|sbFoldMix",
        {h for h, v in fr.items() if g(v, "fold_pct") >= 25}, [p])

    # Defend vs open, keyed by both position groups
    for hi, hero in enumerate(GROUPS):
        for opener in GROUPS[:hi]:
            if hero == "EP":
                continue
            p = f"mtt/{depth}bb/vs_open/{SEAT[hero]}_vs_{SEAT[opener]}.json"
            if not os.path.exists(os.path.join(DATA, p)):
                continue
            fr = load(p)["frequencies"]
            three, call = set(), set()
            for h, v in fr.items():
                r, c = g(v, "raise_pct") + g(v, "allin_pct"), g(v, "call_pct")
                if r + c < 35:
                    continue
                (three if r > c else call).add(h)
            put(f"mtt|{depth}|defend3bet|{hero}|{opener}", three, [p])
            put(f"mtt|{depth}|defendCall|{hero}|{opener}", call, [p])

    # Vs 3-bet, averaged across 3-bettor seats, keyed by hero open seat
    for grp in ["EP", "MP", "CO", "BTN", "SB"]:
        d3 = os.path.join(DATA, f"mtt/{depth}bb/vs_3bet")
        files = sorted(n for n in os.listdir(d3)
                       if n.startswith(f"{SEAT[grp]}_vs_") and n.endswith(".json"))
        if not files:
            continue
        acc = {}
        for name in files:
            fr = load(f"mtt/{depth}bb/vs_3bet/{name}")["frequencies"]
            for h, v in fr.items():
                a = acc.setdefault(h, [0.0, 0.0])
                a[0] += g(v, "raise_pct") + g(v, "allin_pct")
                a[1] += g(v, "call_pct")
        n = len(files)
        four, call = set(), set()
        for h, (r, c) in acc.items():
            r, c = r / n, c / n
            if r + c < 35:
                continue
            (four if r > c else call).add(h)
        put(f"mtt|{depth}|vs3bet4bet|{grp}", four,
            [f"mtt/{depth}bb/vs_3bet/{name}" for name in files])
        put(f"mtt|{depth}|vs3betCall|{grp}", call,
            [f"mtt/{depth}bb/vs_3bet/{name}" for name in files])


def dart_set(hands):
    return "{" + ", ".join(f"'{h}'" for h in hands) + "}"


lines = [
    "// GENERATED FILE — do not edit by hand.",
    "// Produced by tool/gto_export/generate_ranges_dart.py from the",
    "// poker_friend_engine repo's gto_engine data (Peak GTO scrapes; the",
    "// user authorized using this chart data to calibrate the drills).",
    "// Regenerate: python3 tool/gto_export/generate_ranges_dart.py",
    "//",
    "// Key format: 'mtt|<depthBB>|<scenario>|<args>' — see the generator",
    "// header for the membership thresholds. Keys in [approximatedKeys]",
    "// were built (fully or partly) from engine files marked",
    "// 'quality: approximation' rather than raw scrape data.",
    "",
    "/// Engine-exported MTT/ante range sets consumed by DrillGtoCharts.",
    "class DrillGtoRangesData {",
    "  DrillGtoRangesData._();",
    "",
    "  static const Map<String, Set<String>> sets = {",
]
for key in sorted(sets):
    lines.append(f"    '{key}': {dart_set(sets[key])},")
lines += [
    "  };",
    "",
    "  static const Set<String> approximatedKeys = {",
]
for key in sorted(approx_keys):
    lines.append(f"    '{key}',")
lines += [
    "  };",
    "}",
    "",
]
with open(OUT, "w") as f:
    f.write("\n".join(lines))
print(f"wrote {OUT}: {len(sets)} sets, {len(approx_keys)} approximated")
