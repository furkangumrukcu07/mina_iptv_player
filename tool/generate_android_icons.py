#!/usr/bin/env python3
"""Regenerate Android launcher + TV assets from tool/branding sources.

Boyutlar: Android TV simge/banner tabloları
https://developer.android.com/design/ui/tv/guides/system/tv-app-icon-guidelines

Requires: pip install pillow (use a venv).

  python3 tool/generate_android_icons.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
BRAND = ROOT / "tool" / "branding"
UMBRELLA_SRC = BRAND / "umbrella_foreground_source.png"
BANNER_SRC = BRAND / "tv_banner_source.png"

FOREGROUND = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}
# TV başlatıcı tablosu (min. kare) — https://developer.android.com/design/ui/tv/guides/system/tv-app-icon-guidelines
LEGACY_MIPMAP = {
    "mdpi": 80,
    "hdpi": 120,
    "xhdpi": 160,
    "xxhdpi": 240,
    "xxxhdpi": 320,
}

# TV banner tablosu (16:9, mipmap-*)
MIPMAP_BANNER = {
    "mdpi": (160, 90),
    "hdpi": (240, 135),
    "xhdpi": (320, 180),
    "xxhdpi": (480, 270),
    "xxxhdpi": (640, 360),
}

TV_BG = (0x0D, 0x11, 0x17, 255)
PHONE_LEGACY_BG = (255, 255, 255, 255)


def strip_near_black_background(im: Image.Image, thr: int = 32, max_sum: int = 72) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            if r <= thr and g <= thr and b <= thr and (r + g + b) <= max_sum:
                px[x, y] = (0, 0, 0, 0)
    return im


def fit_on_square(canvas_size: int, src: Image.Image, fill_fraction: float) -> Image.Image:
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    max_side = int(canvas_size * fill_fraction)
    iw, ih = src.size
    scale = min(max_side / iw, max_side / ih)
    nw, nh = max(1, int(iw * scale)), max(1, int(ih * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (canvas_size - nw) // 2
    oy = (canvas_size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def fit_on_square_bg(
    canvas_size: int,
    src: Image.Image,
    fill_fraction: float,
    bg: tuple[int, int, int, int],
) -> Image.Image:
    canvas = Image.new("RGBA", (canvas_size, canvas_size), bg)
    max_side = int(canvas_size * fill_fraction)
    iw, ih = src.size
    scale = min(max_side / iw, max_side / ih)
    nw, nh = max(1, int(iw * scale)), max(1, int(ih * scale))
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (canvas_size - nw) // 2
    oy = (canvas_size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def banner_cover(src: Image.Image, tw: int, th: int) -> Image.Image:
    im = src.convert("RGBA")
    sw, sh = im.size
    scale = max(tw / sw, th / sh)
    nw, nh = int(sw * scale + 0.5), int(sh * scale + 0.5)
    im2 = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return im2.crop((left, top, left + tw, top + th))


def main() -> None:
    if not UMBRELLA_SRC.is_file() or not BANNER_SRC.is_file():
        print("Missing tool/branding/*.png — add umbrella_foreground_source.png and tv_banner_source.png", file=sys.stderr)
        sys.exit(1)

    umbrella = strip_near_black_background(Image.open(UMBRELLA_SRC))
    banner_full = Image.open(BANNER_SRC)

    for name, px in FOREGROUND.items():
        out = fit_on_square(px, umbrella, fill_fraction=0.66)
        for sub in ("drawable", "drawable-television"):
            d = RES / f"{sub}-{name}"
            d.mkdir(parents=True, exist_ok=True)
            out.save(d / "ic_launcher_foreground.png", optimize=True)

    for name, px in LEGACY_MIPMAP.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        tile = fit_on_square_bg(px, umbrella, fill_fraction=0.58, bg=PHONE_LEGACY_BG)
        tile.convert("RGB").save(d / "ic_launcher.png", optimize=True)

    for name in ("xhdpi", "xxhdpi", "xxxhdpi"):
        d = RES / f"drawable-{name}"
        d.mkdir(parents=True, exist_ok=True)
        tile = fit_on_square_bg(512, umbrella, fill_fraction=0.78, bg=TV_BG)
        tile.save(d / "ic_launcher_tv.png", optimize=True)
        tile.save(d / "ic_launcher.png", optimize=True)

    for name in ("xhdpi", "xxhdpi", "xxxhdpi"):
        d = RES / f"mipmap-television-{name}"
        d.mkdir(parents=True, exist_ok=True)
        tile = fit_on_square_bg(512, umbrella, fill_fraction=0.78, bg=TV_BG)
        tile.save(d / "ic_launcher.png", optimize=True)

    # drawable-*: Play «drawable-xhdpi 320×180» taraması için aynı merdiven (xhdpi+).
    for name, (bw, bh) in {
        "xhdpi": (320, 180),
        "xxhdpi": (480, 270),
        "xxxhdpi": (640, 360),
    }.items():
        d = RES / f"drawable-{name}"
        d.mkdir(parents=True, exist_ok=True)
        banner_cover(banner_full, bw, bh).save(d / "tv_banner.png", optimize=True)

    # mipmap-*: resmi TV kılavuzu (tüm yoğunluklar); manifest @mipmap/tv_banner
    for name, (bw, bh) in MIPMAP_BANNER.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        banner_cover(banner_full, bw, bh).save(d / "tv_banner.png", optimize=True)

    print("OK:", RES)


if __name__ == "__main__":
    main()
