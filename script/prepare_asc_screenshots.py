#!/usr/bin/env python3
"""Compose Mac App Store screenshots from manually captured ImagePet screenshots.

The source screenshots are user-supplied captures. This script does not launch
the app, run UI tests, or process app-preview videos.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CANVAS = (1440, 900)
SINGLE_SOURCE_SIZE = (1220, 686)
DUO_MAIN_SIZE = (590, 420)
DUO_PET_SIZE = (520, 520)
SUPPORTED_SOURCE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


def hex_color(value: str) -> tuple[int, int, int]:
    color = value.strip().lstrip("#")
    if len(color) != 6:
        raise ValueError(f"Expected #RRGGBB color, got {value!r}")
    return tuple(int(color[index : index + 2], 16) for index in (0, 2, 4))


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    candidates = [
        f"/System/Library/Fonts/SFNS{weight.capitalize()}.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def wrap_text(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        candidate = " ".join([*current, word])
        if draw.textbbox((0, 0), candidate, font=text_font)[2] <= max_width:
            current.append(word)
        else:
            if current:
                lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return lines


def fit_source(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGBA")
    source.thumbnail(max_size, Image.Resampling.LANCZOS)
    return source


def open_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


def rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    scale = 4
    scaled_size = (size[0] * scale, size[1] * scale)
    mask = Image.new("L", scaled_size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, scaled_size[0], scaled_size[1]), radius=radius * scale, fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)


def paste_card(canvas: Image.Image, shot: Image.Image, box: tuple[int, int]) -> None:
    x, y = box
    mask = rounded_rect_mask(shot.size, 16)
    shadow = Image.new("RGBA", shot.size, (0, 0, 0, 180))
    shadow.putalpha(mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(shadow, (x, y + 16))

    card = Image.new("RGBA", (shot.width + 10, shot.height + 10), (255, 255, 255, 245))
    card_mask = rounded_rect_mask(card.size, 20)
    card.putalpha(card_mask)
    canvas.alpha_composite(card, (x - 5, y - 5))
    canvas.paste(shot, (x, y), mask)


def load_deck(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"Missing deck config: {path}")
    with path.open("r", encoding="utf-8") as file:
        deck = json.load(file)
    if "slides" not in deck or not isinstance(deck["slides"], list):
        raise ValueError(f"{path} must contain a slides array")
    if not deck["slides"]:
        raise ValueError(f"{path} must contain at least one slide")
    return deck


def validate_deck(deck: dict[str, Any], source_dir: Path) -> None:
    if not source_dir.exists():
        raise FileNotFoundError(f"Missing manual screenshot directory: {source_dir}")

    for index, slide in enumerate(deck["slides"], start=1):
        for key in ("sources", "output", "headline", "subhead", "accent"):
            if key not in slide:
                raise ValueError(f"Slide {index} is missing required key: {key}")

        sources = slide["sources"]
        if not isinstance(sources, list) or not sources:
            raise ValueError(f"Slide {index} sources must be a non-empty array")

        layout = str(slide.get("layout", "single"))
        expected_count = {"single": 1, "duo-main": 2, "duo-pet": 2}.get(layout)
        if expected_count is None:
            raise ValueError(f"Slide {index} has unknown layout: {layout}")
        if len(sources) != expected_count:
            raise ValueError(f"Slide {index} layout {layout} expects {expected_count} source(s)")

        output = str(slide["output"])
        if Path(output).suffix.lower() != ".png":
            raise ValueError(f"Slide {index} output must be a .png file: {output}")

        for source in sources:
            source_path = source_dir / str(source)
            fallback = slide.get("fallback")
            if not source_path.exists() and fallback is not None:
                source_path = source_dir / str(fallback)
            if source_path.suffix.lower() not in SUPPORTED_SOURCE_EXTENSIONS:
                raise ValueError(
                    f"Slide {index} source must be PNG, JPG, JPEG, or WebP: {source_path.name}"
                )
            if not source_path.exists():
                raise FileNotFoundError(f"Slide {index} is missing manual screenshot: {source_path}")


def resolve_source(source_dir: Path, source_name: str, fallback: str | None = None) -> Path:
    source = source_dir / source_name
    if not source.exists() and fallback is not None:
        source = source_dir / fallback
    if not source.exists():
        raise FileNotFoundError(f"Missing manual screenshot: {source}")
    return source


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGBA")
    source_ratio = source.width / source.height
    target_ratio = size[0] / size[1]
    if source_ratio > target_ratio:
        height = size[1]
        width = round(height * source_ratio)
    else:
        width = size[0]
        height = round(width / source_ratio)
    source = source.resize((width, height), Image.Resampling.LANCZOS)
    left = (width - size[0]) // 2
    top = (height - size[1]) // 2
    return source.crop((left, top, left + size[0], top + size[1]))


def draw_background(canvas: Image.Image, source: Image.Image, background: dict[str, Any]) -> None:
    blur_radius = int(background.get("blurRadius", 28))
    tint = hex_color(str(background.get("tint", "#F7F4EF")))
    tint_alpha = int(background.get("tintAlpha", 172))

    blurred = cover(source, CANVAS).filter(ImageFilter.GaussianBlur(blur_radius))
    canvas.alpha_composite(blurred)
    canvas.alpha_composite(Image.new("RGBA", CANVAS, (*tint, tint_alpha)))

    top_scrim = Image.new("RGBA", CANVAS, (255, 255, 255, 0))
    scrim_draw = ImageDraw.Draw(top_scrim)
    for y in range(0, 260):
        alpha = max(0, 132 - int(y * 0.45))
        scrim_draw.line((0, y, CANVAS[0], y), fill=(255, 255, 255, alpha))
    canvas.alpha_composite(top_scrim)


def draw_copy(canvas: Image.Image, slide: dict[str, Any], accent: tuple[int, int, int]) -> None:
    draw = ImageDraw.Draw(canvas)
    headline_font = font(48, "bold")
    subhead_font = font(22)
    eyebrow_font = font(18, "bold")

    left = 124
    draw.rounded_rectangle((82, 60, 96, 228), radius=7, fill=accent)
    draw.text((left, 58), str(slide.get("eyebrow", "ImagePet")), font=eyebrow_font, fill=accent)

    y = 100
    for line in wrap_text(draw, str(slide["headline"]), headline_font, 820):
        draw.text((left, y), line, font=headline_font, fill=(35, 35, 32))
        y += 58

    y += 8
    for line in wrap_text(draw, str(slide["subhead"]), subhead_font, 900):
        draw.text((left, y), line, font=subhead_font, fill=(86, 82, 74))
        y += 30


def draw_slide(source_dir: Path, output_dir: Path, slide: dict[str, Any], default_background: dict[str, Any]) -> None:
    sources = [
        resolve_source(source_dir, str(source), slide.get("fallback"))
        for source in slide["sources"]
    ]
    accent = hex_color(str(slide["accent"]))
    background = {**default_background, **slide.get("background", {})}
    images = [open_rgba(source) for source in sources]

    canvas = Image.new("RGBA", CANVAS)
    draw_background(canvas, images[0], background)
    draw_copy(canvas, slide, accent)

    layout = str(slide.get("layout", "single"))
    if layout == "single":
        shot = fit_source(images[0], SINGLE_SOURCE_SIZE)
        paste_card(canvas, shot, ((CANVAS[0] - shot.width) // 2, 196))
    elif layout == "duo-main":
        first = fit_source(images[0], DUO_MAIN_SIZE)
        second = fit_source(images[1], DUO_MAIN_SIZE)
        paste_card(canvas, first, (110, 282))
        paste_card(canvas, second, (740, 282))
    elif layout == "duo-pet":
        first = fit_source(images[0], DUO_PET_SIZE)
        second = fit_source(images[1], DUO_PET_SIZE)
        paste_card(canvas, first, (230 + (360 - first.width) // 2, 320 + (430 - first.height) // 2))
        paste_card(canvas, second, (790 + (420 - second.width) // 2, 300 + (470 - second.height) // 2))
        label_font = font(26, "bold")
        labels = slide.get("labels", ["Mini", "Full"])
        draw = ImageDraw.Draw(canvas)
        draw.text((340, 770), str(labels[0]), font=label_font, fill=(35, 35, 32))
        draw.text((920, 770), str(labels[1]), font=label_font, fill=(35, 35, 32))
    else:
        raise ValueError(f"Unknown layout: {layout}")

    output = output_dir / str(slide["output"])
    canvas.convert("RGB").save(output, quality=96)


def render(deck: dict[str, Any], source_dir: Path, output_dir: Path) -> None:
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    default_background = deck.get("background", {})
    for slide in deck["slides"]:
        draw_slide(source_dir, output_dir, slide, default_background)


def validate(output_dir: Path) -> None:
    outputs = sorted(output_dir.glob("*.png"))
    if not outputs:
        raise RuntimeError(f"No screenshots were written to {output_dir}")
    for png in outputs:
        with Image.open(png) as image:
            if image.size != CANVAS:
                raise RuntimeError(f"{png} is {image.size}, expected {CANVAS}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Compose Mac App Store PNG screenshots from manually supplied ImagePet captures. "
            "This does not run UI tests or create app-preview videos."
        )
    )
    parser.add_argument("--locale", default="en-US", help="Locale code used for default paths.")
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="Directory containing manual PNG/JPG/WebP screenshots. Defaults to screenshots/asc/source/<locale>.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Directory for composed ASC-ready PNG screenshots. Defaults to screenshots/asc/mac/<locale>.",
    )
    parser.add_argument(
        "--deck",
        type=Path,
        help="JSON deck with source filenames, output names, copy, layout, accents, and background settings.",
    )
    args = parser.parse_args()

    source_dir = args.source_dir or ROOT / "screenshots" / "asc" / "source" / args.locale
    output_dir = args.output_dir or ROOT / "screenshots" / "asc" / "mac" / args.locale
    deck_path = args.deck or ROOT / "metadata" / f"asc-screenshot-deck.{args.locale}.json"

    deck = load_deck(deck_path)
    validate_deck(deck, source_dir)
    render(deck, source_dir, output_dir)
    validate(output_dir)
    print(f"Wrote ASC screenshots to {output_dir}")


if __name__ == "__main__":
    main()
