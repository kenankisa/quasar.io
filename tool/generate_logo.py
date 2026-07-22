"""Generate a professional transparent Quasar.io logo."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "assets" / "icon" / "app_icon.png"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def color_lerp(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
    )


def draw_glow_ring(
    draw: ImageDraw.ImageDraw,
    bbox: tuple[float, float, float, float],
    width: int,
    color: tuple[int, int, int],
    glow: int = 8,
) -> None:
    for i in range(glow, 0, -1):
        alpha = int(90 / (i * 1.1))
        draw.arc(
            bbox,
            0,
            360,
            fill=(*color, alpha),
            width=width + i * 4,
        )
    draw.arc(bbox, 0, 360, fill=(*color, 255), width=width)


def main() -> None:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = SIZE / 2, SIZE / 2
    cyan = (0, 240, 255)
    magenta = (255, 0, 170)
    white = (255, 255, 255)

    # Outer Q ring
    draw_glow_ring(draw, (210, 210, 814, 814), 26, cyan, glow=10)

    # Inner accent ring
    draw_glow_ring(draw, (285, 285, 739, 739), 9, magenta, glow=6)

    # Q tail with glow
    tail_start = (690, 690)
    tail_end = (805, 805)
    for i in range(8, 0, -1):
        alpha = int(70 / i)
        draw.line([tail_start, tail_end], fill=(*magenta, alpha), width=18 + i * 3)
    draw.line([tail_start, tail_end], fill=(*magenta, 255), width=20)

    # Accretion disk
    disk1 = (295, 395, 729, 575)
    disk2 = (320, 420, 704, 550)
    draw.ellipse(disk1, outline=(*cyan, 210), width=7)
    draw.ellipse(disk2, outline=(*magenta, 170), width=4)

    # Core glow layers
    for radius in range(78, 16, -8):
        alpha = int(35 + (78 - radius) * 1.2)
        bbox = (cx - radius, cy - radius, cx + radius, cy + radius)
        draw.ellipse(bbox, fill=(*white, alpha))

    draw.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=(*white, 255))

    # Subtle Q letter
    try:
        font = ImageFont.truetype("segoeui.ttf", 168)
    except OSError:
        try:
            font = ImageFont.truetype("arial.ttf", 168)
        except OSError:
            font = ImageFont.load_default()

    text = "Q"
    text_bbox = draw.textbbox((0, 0), text, font=font)
    tw = text_bbox[2] - text_bbox[0]
    th = text_bbox[3] - text_bbox[1]
    tx = cx - tw / 2 - text_bbox[0]
    ty = cy - th / 2 - text_bbox[1] - 8

    draw.text((tx + 2, ty + 2), text, font=font, fill=(0, 0, 0, 45))
    draw.text((tx, ty), text, font=font, fill=(240, 252, 255, 235))

    # Soft outer bloom
    bloom = img.filter(ImageFilter.GaussianBlur(radius=1.2))
    img = Image.alpha_composite(img, bloom)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG")
    print(f"Saved {OUT} ({SIZE}x{SIZE}, RGBA)")


if __name__ == "__main__":
    main()
