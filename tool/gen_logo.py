"""Generate the Hisab Master app logo (full icon + adaptive foreground).

Run from the repo root:
    python tool/gen_logo.py

Design: brand-gradient rounded square, white "coin" with a green taka (৳)
symbol and a rising growth chart — a clean fintech-style mark that still
reads at 48dp launcher size. Artwork is drawn at 3x and downscaled for
smooth anti-aliased edges (PIL's ImageDraw is not anti-aliased).
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"

SIZE = 1024
SS = 3  # supersampling factor for the vector-ish artwork

# Brand palette (matches lib/app.dart)
DARK = (11, 61, 46)       # 0xFF0B3D2E
MID = (20, 108, 67)       # 0xFF146C43
LIGHT = (30, 138, 90)     # 0xFF1E8A5A
ACCENT = (111, 227, 176)  # 0xFF6FE3B0
COIN_GREEN = (30, 138, 90)
INK = (11, 61, 46)

FONT_BOLD = "C:/Windows/Fonts/Nirmala.ttc"  # Nirmala UI Bold has ৳


def gradient_background(size: int) -> Image.Image:
    """Diagonal 3-stop brand gradient with soft glow orbs."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    t = np.clip((x / size) * 0.55 + (y / size) * 0.45, 0, 1)

    def stop(c):
        return np.array(c, dtype=np.float32)

    c0, c1, c2 = stop(DARK), stop(MID), stop(LIGHT)
    t3 = t[..., None]
    lower = c0 + (c1 - c0) * np.clip(t3 / 0.55, 0, 1)
    upper = c1 + (c2 - c1) * np.clip((t3 - 0.55) / 0.45, 0, 1)
    rgb = np.where(t3 < 0.55, lower, upper)

    # glow orb: top-right (matches the app header)
    cx, cy, r = size * 0.86, size * 0.10, size * 0.42
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    glow = np.clip(1 - d / r, 0, 1) ** 2 * 0.30
    rgb = rgb + (np.array(ACCENT, dtype=np.float32) - rgb) * glow[..., None]

    # soft light: bottom-left
    cx, cy, r = size * 0.05, size * 0.95, size * 0.50
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    glow = np.clip(1 - d / r, 0, 1) ** 2 * 0.12
    rgb = rgb + (255 - rgb) * glow[..., None]

    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def draw_artwork(size: int) -> Image.Image:
    """White coin + ৳ + growth chart on transparent background."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = s / 2
    coin_r = s * 0.30

    # drop shadow
    sh = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.ellipse(
        [cx - coin_r, cy - coin_r + s * 0.035, cx + coin_r, cy + coin_r + s * 0.035],
        fill=(0, 0, 0, 100),
    )
    sh = sh.filter(ImageFilter.GaussianBlur(s * 0.020))
    img = Image.alpha_composite(img, sh)

    # coin body: clean white with a very subtle vertical shading gradient
    body = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.ellipse(
        [cx - coin_r, cy - coin_r, cx + coin_r, cy + coin_r],
        fill=(255, 255, 255, 255),
    )
    grad = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    steps = 90
    for i in range(steps):
        f = i / (steps - 1)
        a = int(16 * f * f)
        y0 = cy - coin_r + 2 * coin_r * f
        gd.rectangle([cx - coin_r, y0, cx + coin_r, cy + coin_r], fill=(11, 61, 46, a))
    body = Image.composite(
        Image.alpha_composite(body, grad),
        Image.new("RGBA", body.size, (0, 0, 0, 0)),
        body.split()[3],
    )
    img.paste(body, (0, 0), body.split()[3])
    d = ImageDraw.Draw(img)

    # inner ring
    ring = s * 0.255
    d.ellipse(
        [cx - ring, cy - ring, cx + ring, cy + ring],
        outline=(*MID, 210),
        width=max(2, int(s * 0.015)),
    )

    # ৳ symbol, slightly above center
    font = ImageFont.truetype(FONT_BOLD, int(s * 0.295), index=1)
    bbox = d.textbbox((0, 0), "৳", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = cx - tw / 2 - bbox[0]
    ty = cy - th / 2 - bbox[1] - s * 0.065
    # soft shadow for the glyph
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((tx, ty + s * 0.008), "৳", font=font, fill=(11, 61, 46, 55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.005))
    img = Image.alpha_composite(img, shadow)
    d = ImageDraw.Draw(img)
    d.text((tx, ty), "৳", font=font, fill=(*INK, 255))

    # rising growth chart under the symbol
    pts = [
        (cx - s * 0.118, cy + s * 0.132),
        (cx - s * 0.042, cy + s * 0.058),
        (cx + s * 0.028, cy + s * 0.100),
        (cx + s * 0.112, cy - s * 0.010),
    ]
    d.line(pts, fill=(*COIN_GREEN, 255), width=max(2, int(s * 0.023)), joint="curve")
    r = s * 0.0115
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(*COIN_GREEN, 255))

    # arrowhead at the end of the trend line
    x0, y0 = pts[-2]
    x1, y1 = pts[-1]
    ang = math.atan2(y1 - y0, x1 - x0)
    half = math.radians(27)
    length = s * 0.058
    tip = (x1 + length * 0.20 * math.cos(ang), y1 + length * 0.20 * math.sin(ang))
    a1 = (x1 - length * math.cos(ang - half), y1 - length * math.sin(ang - half))
    a2 = (x1 - length * math.cos(ang + half), y1 - length * math.sin(ang + half))
    d.polygon([tip, a1, a2], fill=(*COIN_GREEN, 255))

    return img.resize((size, size), Image.LANCZOS)


def rounded_mask(size: int, radius: int) -> Image.Image:
    # draw the mask at SS too, so the rounded corners stay smooth
    m = Image.new("L", (size * 2, size * 2), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size * 2 - 1, size * 2 - 1], radius=radius * 2, fill=255
    )
    return m.resize((size, size), Image.LANCZOS)


def main() -> None:
    DOCS.mkdir(exist_ok=True)

    # adaptive foreground: artwork only (background colour comes from the
    # launcher theme), kept inside the icon safe zone
    draw_artwork(SIZE).save(DOCS / "logo_foreground.png")

    # full icon: gradient background + artwork, gently rounded for the web
    bg = gradient_background(SIZE).convert("RGBA")
    full = Image.alpha_composite(bg, draw_artwork(SIZE))
    full.putalpha(rounded_mask(SIZE, int(SIZE * 0.18)))
    full.save(DOCS / "logo.png")

    # press / store variant at 2048px
    big = Image.alpha_composite(
        gradient_background(2048).convert("RGBA"), draw_artwork(2048)
    )
    big.putalpha(rounded_mask(2048, int(2048 * 0.18)))
    big.save(DOCS / "logo_2048.png")

    print("Wrote logo.png, logo_foreground.png, logo_2048.png in docs/")


if __name__ == "__main__":
    main()
