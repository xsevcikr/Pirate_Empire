#!/usr/bin/env python3
"""Draws the game's UI skin in the style of Kenney's UI packs: chunky pirate wood panels with gold rivets,
parchment cards, gold buttons with a 3D lip, rope-edged bars, key caps, a few flat symbols (heart, skull,
anchor, sail, star, gear) and the particle sprites (smoke puff, foam ring, spark, droplet).
Everything is drawn at 4x and scaled down, so the edges are smooth. Writes PNGs to assets/ui/.

    python3 tools/gen_ui_skin.py [out_dir]

The textures are 9-sliced by Look.ui_theme(); the margins it uses are in Look.SKIN_MARGIN.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui"
S = 4  # supersampling

INK = (59, 36, 20, 255)          # dark brown outline, the Kenney pirate kit's line colour
WOOD = (176, 112, 62, 255)
WOOD_DARK = (138, 84, 44, 255)
WOOD_LIGHT = (204, 140, 84, 255)
GOLD = (244, 185, 66, 255)
GOLD_LIGHT = (255, 220, 120, 255)
GOLD_DARK = (196, 132, 34, 255)
PAPER = (248, 234, 198, 255)
PAPER_EDGE = (222, 190, 128, 255)
WHITE = (255, 255, 255, 255)


def canvas(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def save(img, name, w, h):
    os.makedirs(OUT, exist_ok=True)
    img.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def rrect(d, box, r, fill, outline=None, width=0):
    x0, y0, x1, y1 = [v * S for v in box]
    d.rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=r * S, fill=fill, outline=outline, width=width * S)


def rivet(d, cx, cy, r):
    d.ellipse(((cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S), fill=INK)
    r2 = r - 1.6
    d.ellipse(((cx - r2) * S, (cy - r2) * S, (cx + r2) * S, (cy + r2) * S), fill=GOLD)
    r3 = r2 * 0.45
    d.ellipse(((cx - r2 * 0.55) * S, (cy - r2 * 0.6) * S, (cx - r2 * 0.55 + r3 * 2) * S, (cy - r2 * 0.6 + r3 * 2) * S), fill=GOLD_LIGHT)


def wood_panel():
    w = h = 96
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 18, INK)
    rrect(d, (4, 4, w - 4, h - 4), 14, WOOD)
    # planks: dark seams and a light top edge on each board
    inner = Image.new("RGBA", img.size, (0, 0, 0, 0))
    di = ImageDraw.Draw(inner)
    for i, y in enumerate(range(4, h - 4, 22)):
        di.rectangle((4 * S, y * S, (w - 4) * S, (y + 22) * S), fill=WOOD if i % 2 == 0 else WOOD_DARK[:3] + (255,))
        di.rectangle((4 * S, y * S, (w - 4) * S, (y + 2) * S), fill=WOOD_LIGHT)
        di.rectangle((4 * S, (y + 20) * S, (w - 4) * S, (y + 22) * S), fill=(110, 66, 34, 255))
        for gx in (18 + i * 13, 52 + i * 7):  # grain streaks
            gx = 8 + gx % (w - 24)
            di.rounded_rectangle((gx * S, (y + 8) * S, (gx + 14) * S, (y + 10) * S), radius=S, fill=(150, 92, 50, 255))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((4 * S, 4 * S, (w - 4) * S - 1, (h - 4) * S - 1), radius=14 * S, fill=255)
    img.paste(inner, (0, 0), mask)
    # gold trim line inside the border
    d.rounded_rectangle((7 * S, 7 * S, (w - 7) * S, (h - 7) * S), radius=11 * S, outline=(232, 170, 70, 180), width=int(1.5 * S))
    for cx, cy in ((13, 13), (w - 13, 13), (13, h - 13), (w - 13, h - 13)):
        rivet(d, cx, cy, 5)
    save(img, "panel_wood", w, h)


def parchment(name="panel_paper", w=96, h=96):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 14, INK)
    rrect(d, (3, 3, w - 3, h - 3), 11, PAPER_EDGE)
    paper = canvas(w, h)
    ImageDraw.Draw(paper).rounded_rectangle((7 * S, 7 * S, (w - 7) * S, (h - 7) * S), radius=8 * S, fill=PAPER)
    paper = paper.filter(ImageFilter.GaussianBlur(3 * S))
    img.alpha_composite(paper)
    save(img, name, w, h)


def dark_panel():
    """See-through dark wood for HUD cards over the sea: readable, but the sea still shows."""
    w = h = 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 14, (59, 36, 20, 235))
    rrect(d, (3, 3, w - 3, h - 3), 11, (92, 58, 34, 215))
    d.rounded_rectangle((5 * S, 5 * S, (w - 5) * S, (h - 5) * S), radius=9 * S, outline=(232, 170, 70, 150), width=S)
    save(img, "panel_dark", w, h)


def button(name, fill, light, dark, lip, pressed=False):
    w, h = 64, 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    top = 3 if pressed else 0
    rrect(d, (0, top, w, h), 14, INK)
    rrect(d, (3, top + 3, w - 3, h - 3), 11, dark)              # the lip
    rrect(d, (3, top + 3, w - 3, h - 3 - lip), 11, fill)        # the face
    rrect(d, (8, top + 6, w - 8, top + 13), 4, light)           # shine
    save(img, name, w, h)


def buttons():
    button("button_normal", GOLD, GOLD_LIGHT, GOLD_DARK, 7)
    button("button_hover", (255, 204, 92, 255), (255, 236, 160, 255), (214, 150, 46, 255), 7)
    button("button_pressed", GOLD_DARK, GOLD, (160, 104, 26, 255), 3, pressed=True)
    button("button_disabled", (170, 156, 140, 255), (196, 184, 170, 255), (128, 116, 104, 255), 7)
    button("button_wood", WOOD, WOOD_LIGHT, WOOD_DARK, 7)
    button("button_wood_hover", WOOD_LIGHT, (226, 170, 112, 255), WOOD, 7)
    button("button_wood_pressed", WOOD_DARK, WOOD, (110, 66, 34, 255), 3, pressed=True)


def bars():
    w, h = 32, 24
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 10, INK)
    rrect(d, (3, 3, w - 3, h - 3), 7, (40, 26, 16, 255))
    save(img, "bar_back", w, h)
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 9, (225, 225, 225, 255))             # tinted by the theme per bar
    rrect(d, (3, 3, w - 3, 9), 3, WHITE)
    save(img, "bar_fill", w, h)


def keycap():
    w, h = 48, 52
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 10, INK)
    rrect(d, (3, 3, w - 3, h - 3), 8, PAPER_EDGE)
    rrect(d, (3, 3, w - 3, h - 9), 8, PAPER)
    save(img, "keycap", w, h)


def field():
    w, h = 48, 48
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h), 10, INK)
    rrect(d, (3, 3, w - 3, h - 3), 7, PAPER)
    rrect(d, (3, 3, w - 3, 8), 4, PAPER_EDGE)
    save(img, "field", w, h)


def tab(name, fill, light):
    w, h = 48, 40
    img = canvas(w, h + 12)
    d = ImageDraw.Draw(img)
    rrect(d, (0, 0, w, h + 12), 12, INK)
    rrect(d, (3, 3, w - 3, h + 12), 9, fill)
    rrect(d, (7, 6, w - 7, 11), 3, light)
    img = img.crop((0, 0, w * S, h * S))
    save(img, name, w, h)


# ---------------------------------------------------------------- flat symbols (white with a dark outline)


def outlined(shape_fn, name, size=64, color=WHITE):
    """shape_fn(draw, scale, fill) draws the shape on a 64-unit grid."""
    big = canvas(size, size)
    shape_fn(ImageDraw.Draw(big), 1.0, color)
    a = big.split()[3]
    ring = a.filter(ImageFilter.MaxFilter(4 * S + 1))
    out = Image.new("RGBA", big.size, (0, 0, 0, 0))
    out.paste(INK, (0, 0), ring)
    out.alpha_composite(big)
    save(out, name, size, size)


def heart(d, k, fill):
    s = S
    d.ellipse((10 * s, 12 * s, 34 * s, 36 * s), fill=fill)
    d.ellipse((30 * s, 12 * s, 54 * s, 36 * s), fill=fill)
    d.polygon([(12 * s, 30 * s), (52 * s, 30 * s), (32 * s, 54 * s)], fill=fill)


def skull(d, k, fill):
    s = S
    d.ellipse((12 * s, 8 * s, 52 * s, 44 * s), fill=fill)
    d.rounded_rectangle((20 * s, 36 * s, 44 * s, 54 * s), radius=4 * s, fill=fill)
    hole = (0, 0, 0, 0)
    d.ellipse((19 * s, 22 * s, 30 * s, 33 * s), fill=INK)
    d.ellipse((34 * s, 22 * s, 45 * s, 33 * s), fill=INK)
    d.polygon([(32 * s, 34 * s), (29 * s, 40 * s), (35 * s, 40 * s)], fill=INK)
    for x in (25, 31, 37):
        d.rectangle((x * s, 46 * s, (x + 2) * s, 54 * s), fill=INK)


def anchor(d, k, fill):
    s = S
    d.ellipse((26 * s, 6 * s, 38 * s, 18 * s), outline=fill, width=4 * s)
    d.rectangle((30 * s, 16 * s, 34 * s, 54 * s), fill=fill)
    d.rectangle((20 * s, 22 * s, 44 * s, 26 * s), fill=fill)
    d.arc((12 * s, 28 * s, 52 * s, 58 * s), 20, 160, fill=fill, width=5 * s)
    d.polygon([(8 * s, 40 * s), (16 * s, 36 * s), (16 * s, 46 * s)], fill=fill)
    d.polygon([(56 * s, 40 * s), (48 * s, 36 * s), (48 * s, 46 * s)], fill=fill)


def sail(d, k, fill):
    s = S
    d.rectangle((30 * s, 6 * s, 34 * s, 58 * s), fill=fill)
    d.polygon([(36 * s, 10 * s), (54 * s, 44 * s), (36 * s, 44 * s)], fill=fill)
    d.polygon([(28 * s, 14 * s), (10 * s, 40 * s), (28 * s, 40 * s)], fill=fill)
    d.polygon([(8 * s, 48 * s), (56 * s, 48 * s), (48 * s, 58 * s), (16 * s, 58 * s)], fill=fill)


def star(d, k, fill):
    s = S
    pts = []
    for i in range(10):
        r = 26 if i % 2 == 0 else 11
        a = -math.pi / 2 + i * math.pi / 5
        pts.append(((32 + r * math.cos(a)) * s, (34 + r * math.sin(a)) * s))
    d.polygon(pts, fill=fill)


def gear(d, k, fill):
    s = S
    for i in range(8):
        a = i * math.pi / 4
        cx, cy = 32 + 20 * math.cos(a), 32 + 20 * math.sin(a)
        d.ellipse(((cx - 6) * s, (cy - 6) * s, (cx + 6) * s, (cy + 6) * s), fill=fill)
    d.ellipse((12 * s, 12 * s, 52 * s, 52 * s), fill=fill)
    d.ellipse((24 * s, 24 * s, 40 * s, 40 * s), fill=INK)


def speed(d, k, fill):
    s = S
    d.pieslice((6 * s, 12 * s, 58 * s, 64 * s), 180, 360, fill=fill)
    d.ellipse((26 * s, 32 * s, 38 * s, 44 * s), fill=INK)
    d.line((32 * s, 38 * s, 48 * s, 20 * s), fill=INK, width=4 * s)


def flag(d, k, fill):
    s = S
    d.rectangle((12 * s, 6 * s, 16 * s, 58 * s), fill=fill)
    d.polygon([(16 * s, 8 * s), (54 * s, 14 * s), (44 * s, 24 * s), (54 * s, 34 * s), (16 * s, 34 * s)], fill=fill)


def info(d, k, fill):
    s = S
    d.ellipse((6 * s, 6 * s, 58 * s, 58 * s), fill=fill)
    d.ellipse((28 * s, 14 * s, 36 * s, 22 * s), fill=INK)
    d.rounded_rectangle((28 * s, 26 * s, 36 * s, 50 * s), radius=2 * s, fill=INK)


def symbols():
    outlined(heart, "icon_heart", color=(232, 74, 74, 255))
    outlined(skull, "icon_skull")
    outlined(anchor, "icon_anchor", color=(86, 180, 233, 255))
    outlined(sail, "icon_sail")
    outlined(star, "icon_star", color=GOLD)
    outlined(gear, "icon_gear", color=(210, 210, 220, 255))
    outlined(speed, "icon_speed", color=(240, 228, 66, 255))
    outlined(flag, "icon_flag", color=(232, 74, 74, 255))
    outlined(info, "icon_info", color=(86, 180, 233, 255))


# ---------------------------------------------------------------- particle sprites (white, tinted in game)


def puff():
    """A cartoon smoke puff: a few overlapping circles, flat white with a soft grey underside."""
    n = 64
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    blobs = [(32, 36, 20), (20, 38, 13), (44, 38, 13), (26, 26, 13), (40, 26, 12)]
    for cx, cy, r in blobs:
        d.ellipse(((cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S), fill=(214, 220, 232, 255))
    for cx, cy, r in blobs:
        r2 = r - 3
        d.ellipse(((cx - r2) * S, (cy - r2 - 3) * S, (cx + r2) * S, (cy + r2 - 3) * S), fill=WHITE)
    save(img, "fx_puff", n, n)


def ring():
    n = 64
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    d.ellipse((4 * S, 4 * S, 60 * S, 60 * S), outline=WHITE, width=7 * S)
    d.ellipse((14 * S, 14 * S, 50 * S, 50 * S), outline=(255, 255, 255, 120), width=3 * S)
    save(img, "fx_ring", n, n)


def spark():
    n = 32
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(8):
        r = 15 if i % 2 == 0 else 4
        a = i * math.pi / 4
        pts.append(((16 + r * math.cos(a)) * S, (16 + r * math.sin(a)) * S))
    d.polygon(pts, fill=WHITE)
    save(img, "fx_spark", n, n)


def droplet():
    n = 32
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    d.ellipse((8 * S, 12 * S, 24 * S, 28 * S), fill=WHITE)
    d.polygon([(9 * S, 18 * S), (23 * S, 18 * S), (16 * S, 3 * S)], fill=WHITE)
    save(img, "fx_drop", n, n)


def foam():
    """A blob of sea foam for wakes: a cluster of round bubbles, soft at the edges."""
    n = 64
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    for cx, cy, r in [(32, 32, 16), (18, 30, 10), (46, 30, 10), (26, 18, 9), (40, 20, 8), (24, 44, 9), (42, 44, 8), (12, 40, 5), (52, 42, 5)]:
        d.ellipse(((cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S), fill=(255, 255, 255, 235))
    img = img.filter(ImageFilter.GaussianBlur(1.2 * S))
    save(img, "fx_foam", n, n)


if __name__ == "__main__":
    wood_panel()
    parchment()
    dark_panel()
    buttons()
    bars()
    keycap()
    field()
    tab("tab_selected", GOLD, GOLD_LIGHT)
    tab("tab_unselected", WOOD, WOOD_LIGHT)
    symbols()
    puff()
    ring()
    spark()
    droplet()
    foam()
