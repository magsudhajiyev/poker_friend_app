#!/usr/bin/env python3
"""Design-system lint: counts hardcoded style values outside the design
system so unification progress is measurable.

    python3 tool/design_lint.py            # summary
    python3 tool/design_lint.py --fix      # replace hexes that EXACTLY match
                                           # an AppColors token (value-identical,
                                           # zero visual change) + add imports

--fix intentionally skips 0xFF0C0C0C (used both as background and as
text-on-light — semantically ambiguous, migrate by hand) and any hex that
maps to more than one token.
"""

import collections
import glob
import os
import re
import sys

LIB = os.path.join(os.path.dirname(__file__), "..", "lib")
COLORS_FILE = os.path.join(LIB, "design_system", "constants", "colors.dart")
SKIP_HEX = {"FF0C0C0C", "FFFFFFFF", "FF000000"}  # ambiguous / use Colors.*
IMPORT_TAIL = "design_system/constants/colors.dart"


def token_map():
    src = open(COLORS_FILE).read()
    out = {}
    dupes = set()
    for name, hexv in re.findall(
            r"static const Color (\w+)\s*=\s*Color\(0x([0-9A-Fa-f]{8})\)", src):
        if name.startswith("_"):
            continue
        h = hexv.upper()
        if h in out:
            dupes.add(h)  # two public names for one value → skip, ambiguous
        else:
            out[h] = name
    return {h: n for h, n in out.items() if h not in dupes and h not in SKIP_HEX}


def scan(fix=False):
    tokens = token_map()
    colors = collections.Counter()
    fixable = collections.Counter()
    fixed = 0
    files_fixed = 0
    for p in sorted(glob.glob(f"{LIB}/**/*.dart", recursive=True)):
        rel = os.path.relpath(p, LIB)
        if rel.startswith(("design_system", "l10n")) or rel.endswith("_data.dart"):
            continue
        src = open(p).read()
        hexes = re.findall(r"Color\(0x([0-9A-Fa-f]{8})\)", src)
        for h in hexes:
            h = h.upper()
            colors[h] += 1
            if h in tokens:
                fixable[h] += 1
        if fix:
            new = src
            changed = 0
            for h, name in tokens.items():
                pat_const = re.compile(rf"const Color\(0x{h}\)", re.IGNORECASE)
                pat_plain = re.compile(rf"Color\(0x{h}\)", re.IGNORECASE)
                new, n1 = pat_const.subn(f"AppColors.{name}", new)
                new, n2 = pat_plain.subn(f"AppColors.{name}", new)
                changed += n1 + n2
            if changed:
                if IMPORT_TAIL not in new:
                    depth = rel.count(os.sep)
                    prefix = "../" * depth if depth else ""
                    imp = f"import '{prefix}{IMPORT_TAIL}';"
                    lines = new.split("\n")
                    last = max(i for i, l in enumerate(lines)
                               if l.startswith("import "))
                    lines.insert(last + 1, imp)
                    new = "\n".join(lines)
                open(p, "w").write(new)
                fixed += changed
                files_fixed += 1
    total = sum(colors.values())
    fix_total = sum(fixable.values())
    print(f"hardcoded Color(0x...): {total} ({len(colors)} distinct)")
    print(f"  exactly matching an AppColors token: {fix_total}")
    print(f"  ambiguous/unknown values (need judgment): {total - fix_total}")
    if fix:
        print(f"FIXED: {fixed} replacements in {files_fixed} files")
    else:
        print("top unknown values (candidates for new tokens or consolidation):")
        for h, c in [(h, c) for h, c in colors.most_common(24)
                     if h not in token_map()][:16]:
            print(f"  0x{h}  x{c}")


if __name__ == "__main__":
    scan(fix="--fix" in sys.argv)
