#!/usr/bin/env python3
"""Draws the "PIRATE EMPIRE" title lettering: chunky gold letters on a gentle arch, with a dark outline,
a red-brown 3D extrusion and a soft shadow. Writes assets/title/title_logo.png (transparent).

    python3 tools/gen_title_logo.py [out.png]
"""
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FONT = "assets/fonts/LuckiestGuy-Regular.ttf"
TEXT = "PIRATE EMPIRE"
SIZE = 210          # glyph size in px
ARC = 2600.0        # arch radius in px (bigger = flatter)
DEPTH = 22          # extrusion depth in px
LINE = 16           # outline width in px
W, H = 1900, 520

TOP = (255, 226, 84)
BOTTOM = (242, 118, 18)
SIDE = (166, 58, 24)
SIDE_DARK = (110, 34, 14)
OUTLINE = (54, 24, 12)


def letters_mask():
    font = ImageFont.truetype(FONT, SIZE)
    widths = [font.getlength(c) for c in TEXT]
    spacing = 2
    total = sum(widths) + spacing * (len(TEXT) - 1) + SIZE * 0.12
    mask = Image.new("L", (W, H), 0)
    cx, cy = W / 2, H * 0.42 + ARC
    x = -total / 2
    for c, w in zip(TEXT, widths):
        mid = x + w / 2
        ang = mid / ARC
        if c != " ":
            g = Image.new("L", (int(w) + 80, SIZE + 80), 0)
            ImageDraw.Draw(g).text((40, 30), c, font=font, fill=255)
            g = g.rotate(-math.degrees(ang), resample=Image.BICUBIC, expand=True)
            px = cx + math.sin(ang) * ARC
            py = cy - math.cos(ang) * ARC
            mask.paste(255, (int(px - g.width / 2), int(py - g.height / 2)), g)
        x += w + spacing + (SIZE * 0.12 if c == " " else 0)
    return mask


def shifted(m, dy):
    out = Image.new("L", m.size, 0)
    out.paste(m, (0, dy))
    return out


def gradient(mask, top, bottom):
    box = mask.getbbox()
    img = Image.new("RGB", mask.size, top)
    d = ImageDraw.Draw(img)
    for y in range(box[1], box[3] + 1):
        t = (y - box[1]) / max(1, box[3] - box[1])
        t = t * t * (3 - 2 * t)
        d.line([(0, y), (mask.width, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/title/title_logo.png"
    face = letters_mask()
    body = face.copy()
    for k in range(1, DEPTH + 1):
        body = ImageChops.lighter(body, shifted(face, k))
    rim = body.filter(ImageFilter.MaxFilter(LINE * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow = shifted(rim, 14).filter(ImageFilter.GaussianBlur(10)).point(lambda v: v * 0.45)
    img.paste((10, 20, 40, 255), (0, 0), shadow)
    img.paste(OUTLINE + (255,), (0, 0), rim)
    side = gradient(body, SIDE, SIDE_DARK)
    img.paste(side, (0, 0), body)
    img.paste(gradient(face, TOP, BOTTOM), (0, 0), face)
    # a glossy band across the upper half of each letter and a thin light edge along the top
    inner = face.filter(ImageFilter.MinFilter(9))
    gloss = ImageChops.subtract(inner, shifted(inner, int(SIZE * 0.3)))
    img.paste((255, 250, 215, 255), (0, 0), gloss.point(lambda v: v * 0.35))
    edge = ImageChops.subtract(face, shifted(face, 5)).filter(ImageFilter.GaussianBlur(0.8))
    img.paste((255, 255, 235, 255), (0, 0), edge.point(lambda v: v * 0.8))
    img = img.crop(img.getbbox())
    img.save(out)
    print("saved", out, img.size)


if __name__ == "__main__":
    main()
