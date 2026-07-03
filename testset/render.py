"""Render a composed letter to a clean A4 page image (the 'flatbed scan' baseline)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# A4 at 150 dpi
PAGE_W, PAGE_H = 1240, 1754
MARGIN_X, MARGIN_Y = 130, 140
BODY_WRAP_WIDTH = PAGE_W - 2 * MARGIN_X

_FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Verdana.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in _FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    raise RuntimeError(f"no usable TrueType font found; tried {_FONT_CANDIDATES}")


def _wrap(draw: ImageDraw.ImageDraw, line: str, font: ImageFont.FreeTypeFont) -> list[str]:
    """Greedy word-wrap to the body width; the letter text stays the ground truth,
    wrapping only changes where line breaks fall on the page."""
    if draw.textlength(line, font=font) <= BODY_WRAP_WIDTH:
        return [line]
    words, out, cur = line.split(" "), [], ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if draw.textlength(trial, font=font) <= BODY_WRAP_WIDTH:
            cur = trial
        else:
            out.append(cur)
            cur = w
    if cur:
        out.append(cur)
    return out


def render_letter(text: str, out_path: Path) -> None:
    img = Image.new("RGB", (PAGE_W, PAGE_H), (252, 251, 248))  # near-white paper
    draw = ImageDraw.Draw(img)
    font = _load_font(30)
    line_height = 44

    y = MARGIN_Y
    for raw_line in text.split("\n"):
        if not raw_line:
            y += line_height
            continue
        for line in _wrap(draw, raw_line, font):
            draw.text((MARGIN_X, y), line, font=font, fill=(25, 25, 30))
            y += line_height

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)
