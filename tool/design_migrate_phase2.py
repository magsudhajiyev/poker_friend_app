#!/usr/bin/env python3
"""Design-system phase 2 migration — value-identical, one-shot.

1. Fonts: GoogleFonts.<family>( -> AppTypography.<wrapper>( (pure name swap;
   wrappers forward every parameter, so rendering is byte-identical).
2. Colors: remaining hardcoded hexes -> tokens. Multi-alias values resolve
   by role (text / border / other) from the surrounding source context.
3. Radius: (Border)Radius.circular(<n>) -> AppDecorations token for the
   number only (legal in const and non-const contexts alike).

Run once from repo root: python3 tool/design_migrate_phase2.py
Verify locally: flutter analyze && flutter test
"""

import glob
import os
import re

LIB = os.path.join(os.path.dirname(__file__), "..", "lib")

FONT_SWAP = {
    "GoogleFonts.ibmPlexSans(": "AppTypography.ibm(",
    "GoogleFonts.robotoMono(": "AppTypography.mono(",
    "GoogleFonts.familjenGrotesk(": "AppTypography.grotesk(",
    "GoogleFonts.inter(": "AppTypography.interLegacy(",
    "GoogleFonts.ibmPlexMono(": "AppTypography.plexMonoLegacy(",
}

# hex -> (text_token, border_token, other_token)
ROLE_MAP = {
    "FF0C0C0C": ("textInverse", "bgPrimary", "bgPrimary"),
    "FFB9B9B9": ("textSecondary", "borderLight", "contentInactive"),
    "FF161719": ("bgSurface", "borderDefault", "bgSurface"),
    "FF2C2C2E": ("bgElevated", "borderOnInverse", "bgElevated"),
    "FF3A3A3C": ("contentDisabled", "borderStrong", "bgOverlay"),
}

# single-alias values (public token = private primitive)
DIRECT = {
    "FFFDFDFD": "bgInputOnInverse",
    "FFEFEFEF": "borderOnInverseSubtle",
    "FF4CDE78": "accentPrimary",
    "FFA3FF78": "accentSecondary",
    "FFFF3B30": "accentDanger",
    "FF007AFF": "accentInfo",
    "FFFF8A54": "accentTertiary",
    "FF763EED": "accentPurple",
    # variant tokens added 2026-07
    "FF161618": "surfaceVariant1",
    "FF1F1F23": "surfaceVariant2",
    "FF2A2A2E": "surfaceVariant3",
    "FF1A1A1E": "surfaceVariant4",
    "FFCB5242": "errorRedVariant",
}

RADIUS = {
    "8": "radiusSm", "10": "radius10", "12": "radiusMd", "14": "radius14",
    "16": "radiusLg", "18": "radius18", "20": "radius20", "24": "radiusXl",
    "40": "pillRadius", "60": "buttonRadius", "70": "navBarRadius",
    "999": "radiusFull",
}

TEXT_CUES = ("TextStyle(", "AppTypography.", "GoogleFonts.", "fontSize",
             "fontWeight", "decorationColor")
BORDER_CUES = ("Border.all(", "BorderSide(", "border: Border")


def role_of(src, i):
    w = src[max(0, i - 150):i]
    last_text = max((w.rfind(c) for c in TEXT_CUES), default=-1)
    last_border = max((w.rfind(c) for c in BORDER_CUES), default=-1)
    if last_text < 0 and last_border < 0:
        return "other"
    return "text" if last_text > last_border else "border"


def fix_colors(src):
    out, pos, n = [], 0, 0
    for m in re.finditer(r"(const )?Color\(0x([0-9A-Fa-f]{8})\)", src):
        h = m.group(2).upper()
        if h in DIRECT:
            name = DIRECT[h]
        elif h in ROLE_MAP:
            text_t, border_t, other_t = ROLE_MAP[h]
            name = {"text": text_t, "border": border_t,
                    "other": other_t}[role_of(src, m.start())]
        else:
            continue
        out.append(src[pos:m.start()])
        out.append(f"AppColors.{name}")
        pos = m.end()
        n += 1
    out.append(src[pos:])
    return "".join(out), n


def fix_radius(src):
    n = 0
    def sub(m):
        nonlocal n
        num = m.group(2).rstrip("0").rstrip(".") if "." in m.group(2) else m.group(2)
        if num in RADIUS:
            n += 1
            return f"{m.group(1)}.circular(AppDecorations.{RADIUS[num]})"
        return m.group(0)
    src = re.sub(r"\b(BorderRadius|Radius)\.circular\((\d+(?:\.\d+)?)\)", sub, src)
    return src, n


def ensure_import(src, rel, tail):
    if tail in src:
        return src
    depth = rel.count(os.sep)
    imp = f"import '{'../' * depth}design_system/constants/{tail}';"
    lines = src.split("\n")
    last = max(i for i, l in enumerate(lines) if l.startswith("import "))
    lines.insert(last + 1, imp)
    return "\n".join(lines)


def main():
    tot = {"fonts": 0, "colors": 0, "radius": 0}
    files = 0
    for p in sorted(glob.glob(f"{LIB}/**/*.dart", recursive=True)):
        rel = os.path.relpath(p, LIB)
        if rel.startswith(("design_system", "l10n")) or rel.endswith("_data.dart"):
            continue
        src = orig = open(p).read()
        nf = 0
        for a, b in FONT_SWAP.items():
            nf += src.count(a)
            src = src.replace(a, b)
        src, nc = fix_colors(src)
        src, nr = fix_radius(src)
        if src == orig:
            continue
        if nf:
            src = ensure_import(src, rel, "typography.dart")
            if "GoogleFonts." not in src:
                src = re.sub(
                    r"import 'package:google_fonts/google_fonts\.dart';\n", "", src)
        if nc:
            src = ensure_import(src, rel, "colors.dart")
        if nr:
            src = ensure_import(src, rel, "decorations.dart")
        assert src.count("(") - src.count(")") == orig.count("(") - orig.count(")"), rel
        open(p, "w").write(src)
        files += 1
        tot["fonts"] += nf
        tot["colors"] += nc
        tot["radius"] += nr
    print(f"files changed: {files}")
    for k, v in tot.items():
        print(f"  {k}: {v} replacements")


if __name__ == "__main__":
    main()
