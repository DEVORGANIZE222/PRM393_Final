"""Builds tool/fonts/material_icons_subset.ttf for tool/generate_slides_pdf.dart.

The pdf package reads only TrueType outlines, and Flutter ships Material Icons as a
CFF .otf. This converts the glyphs the deck uses to quadratic TrueType outlines and
keeps Flutter's code points (Icons.*), so the Dart code can use the same numbers.

  pip install fonttools
  python tool/make_icon_font.py <flutter>/bin/cache/artifacts/material_fonts/materialicons-regular.otf
"""

import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "fonts" / "material_icons_subset.ttf"


def to_truetype(font: TTFont) -> None:
    order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()
    font["loca"] = newTable("loca")
    font["glyf"] = glyf = newTable("glyf")
    glyf.glyphOrder = order
    glyf.glyphs = {}
    for name in order:
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
        glyf[name] = pen.glyph()
    del font["CFF "]
    font["maxp"] = maxp = newTable("maxp")
    maxp.tableVersion = 0x00010000
    for field in ("maxZones", "maxTwilightPoints", "maxStorage", "maxFunctionDefs", "maxInstructionDefs",
                  "maxStackElements", "maxSizeOfInstructions", "maxComponentElements"):
        setattr(maxp, field, 1 if field == "maxZones" else 0)
    post = font["post"]
    post.formatType, post.extraNames, post.mapping, post.glyphOrder = 2.0, [], {}, order
    font["head"].glyphDataFormat = 0
    font.sfntVersion = "\x00\x01\x00\x00"


def main() -> None:
    source = Path(sys.argv[1])
    # The code points are the `const iXxx = 0x....` lines of the deck generator.
    deck = (ROOT / "generate_slides_pdf.dart").read_text(encoding="utf-8")
    codes = sorted({int(c, 16) for c in re.findall(r"\bi[A-Z]\w* = (0x[0-9a-f]+)", deck)})
    font = TTFont(source)
    options = subset.Options()
    options.layout_features = []  # no ligatures: the deck draws glyphs by code point
    options.name_IDs = ["*"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=codes)
    subsetter.subset(font)
    to_truetype(font)
    OUT.parent.mkdir(exist_ok=True)
    font.save(OUT)
    print(f"{len(codes)} icons -> {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
