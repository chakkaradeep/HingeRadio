"""Builds the badge and icon artwork (Badge.svg, AppIcon.svg): usage build_badge.py FONT OUT_DIR.

The letters H, i, n, g, e come from Yellowtail Regular (Astigmatic, Apache 2.0; see
App/Resources/Yellowtail-LICENSE.txt), changed: the i has a round station dot. The word RADIO, the
underline and the needle are our own. Needs fontTools; the font itself is not in the repo.

Badge.svg goes to App/Assets.xcassets/Badge.imageset. AppIcon.svg is rendered to the 1024 by 1024
opaque AppIcon.png in App/Assets.xcassets/AppIcon.appiconset (headless Chrome's --screenshot did it).
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
font, out = sys.argv[1], sys.argv[2]
f = TTFont(font); gs = f.getGlyphSet(); cm = f.getBestCmap()
INK, CREAM, NEEDLE = "#161616", "#F3F1EA", "#FF5B1F"
def draw(text, x, base, size):
    k = size / 2048; pen = SVGPathPen(gs, ntos=lambda v: ("%.2f" % v).rstrip("0").rstrip("."))
    at = {}
    for c in text:
        # The i is drawn without its own dot; ours is a round station dot from the dial.
        g = gs["dotlessi"] if c == "i" else gs[cm[ord(c)]]
        at[c] = x
        g.draw(TransformPen(pen, (k, 0, 0, -k, x, base))); x += gs[cm[ord(c)]].width * k
    return pen.getCommands(), at, k
word, at, k = draw("Hinge", 2, 44, 56)
dot = (at["i"] + 612 * k, 44 - 1060 * k)
radio = ("M128 43.5V32.5H131.9A3.2 3.2 0 0 1 131.9 38.9H128M132.2 38.9L135.6 43.5"
         "M141.4 43.5L145.8 32.5L150.2 43.5M143.1 39.9H148.5"
         "M156 43.5V32.5H158.8A5.5 5.5 0 0 1 158.8 43.5ZM170.4 32.5V43.5"
         "M176.6 38A5.5 5.5 0 1 1 187.6 38A5.5 5.5 0 1 1 176.6 38Z")
g0 = at["g"]
badge = f'''<svg xmlns="http://www.w3.org/2000/svg" width="194" height="64" viewBox="4 0 194 64">
<!-- Letters adapted from Yellowtail, copyright (c) 2011 Brian J. Bonislawsky DBA Astigmatic, Apache License 2.0. Changed: see tools/build_badge.py. -->
<path d="{word}" fill="{INK}"/>
<circle cx="{dot[0]:.2f}" cy="{dot[1]:.2f}" r="3.1" fill="{INK}"/>
<path d="{radio}" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="square"/>
<path d="M4 54.2L{g0-6:.1f} 53.6V56L4 54.8ZM{g0+15.5:.1f} 53.5L196 53.2V56.4L{g0+15.5:.1f} 56.1Z" fill="{INK}"/>
<path d="M196 40V62" stroke="{NEEDLE}" stroke-width="3.6" stroke-linecap="round"/>
</svg>
'''
open(out + "/Badge.svg", "w").write(badge)
h, _, _ = draw("H", 172, 640, 626)
icon = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<!-- Letters adapted from Yellowtail, copyright (c) 2011 Brian J. Bonislawsky DBA Astigmatic, Apache License 2.0. Changed: see tools/build_badge.py. -->
<rect width="1024" height="1024" fill="{INK}"/>
<path d="{h}" fill="{CREAM}"/>
<path d="M222 752L800 743V773L222 764Z" fill="{CREAM}"/>
<path d="M800 650V852" stroke="{NEEDLE}" stroke-width="32" stroke-linecap="round"/>
</svg>
'''
open(out + "/AppIcon.svg", "w").write(icon)
