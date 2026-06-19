#!/usr/bin/env python3
"""Validate an ImagePet desktop pet theme package.

The validator is intentionally independent from Xcode so generated or
designer-provided themes can fail before they reach the app runtime.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


EXPECTED_STATES: dict[str, tuple[str, int]] = {
    "idle": ("loop", 8),
    "eating": ("loop", 6),
    "done": ("once", 12),
    "issues": ("loop", 8),
    "dragHover": ("loop", 4),
    "petting": ("loop", 8),
    "stretch": ("once", 12),
    "yawn": ("once", 10),
    "sleep": ("loop", 8),
}

FRAME_NAME_RE = re.compile(r"^frame_(\d{3})\.png$")
CELL_SIZE = (256, 256)
MAX_THEME_BYTES = 3 * 1024 * 1024
FPS_RANGE = range(8, 13)


@dataclass
class StateFrames:
    name: str
    files: list[Path]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate an ImagePet pet theme package.")
    parser.add_argument("theme_dir", type=Path, help="Path to a theme folder containing theme.json.")
    parser.add_argument("--json-out", type=Path, help="Write machine-readable review JSON.")
    parser.add_argument("--contact-sheet", type=Path, help="Write a PNG contact sheet.")
    parser.add_argument("--preview-dir", type=Path, help="Write per-state GIF previews into this folder.")
    return parser.parse_args()


def add_error(errors: list[str], message: str) -> None:
    errors.append(message)


def add_warning(warnings: list[str], message: str) -> None:
    warnings.append(message)


def load_manifest(theme_dir: Path, errors: list[str]) -> dict[str, Any]:
    manifest_path = theme_dir / "theme.json"
    if not manifest_path.exists():
        add_error(errors, "theme.json is missing")
        return {}

    try:
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        add_error(errors, f"theme.json is not valid JSON: {exc}")
        return {}


def validate_manifest(theme_dir: Path, manifest: dict[str, Any], errors: list[str], warnings: list[str]) -> None:
    if not manifest:
        return

    expected_id = theme_dir.name
    if manifest.get("schemaVersion") != 1:
        add_error(errors, "theme.json schemaVersion must be 1")
    if manifest.get("themeId") != expected_id:
        add_error(errors, f"themeId must match folder name '{expected_id}'")
    if not manifest.get("displayName"):
        add_error(errors, "displayName is required")
    if not manifest.get("description"):
        add_error(errors, "description is required")
    if manifest.get("assetFormat") != "png-sequence":
        add_error(errors, "assetFormat must be 'png-sequence'")

    fps = manifest.get("defaultFPS")
    if not isinstance(fps, int) or fps not in FPS_RANGE:
        add_error(errors, "defaultFPS must be an integer from 8 through 12")

    cell_size = manifest.get("cellSize")
    if cell_size != {"width": CELL_SIZE[0], "height": CELL_SIZE[1]}:
        add_error(errors, "cellSize must be 256 x 256")

    states = manifest.get("states")
    if not isinstance(states, dict):
        add_error(errors, "states must be an object")
        return

    for state_name, (expected_mode, recommended_frames) in EXPECTED_STATES.items():
        state = states.get(state_name)
        if not isinstance(state, dict):
            add_error(errors, f"states.{state_name} is missing")
            continue
        if state.get("mode") != expected_mode:
            add_error(errors, f"states.{state_name}.mode must be '{expected_mode}'")
        if state.get("recommendedFrames") != recommended_frames:
            add_error(errors, f"states.{state_name}.recommendedFrames must be {recommended_frames}")

    extra_states = sorted(set(states.keys()) - set(EXPECTED_STATES.keys()))
    if extra_states:
        add_warning(warnings, f"theme.json contains extra states: {', '.join(extra_states)}")


def visible_pixel_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    data = rgba.tobytes()
    return sum(1 for index in range(3, len(data), 4) if data[index] > 0)


def transparent_residue_count(image: Image.Image) -> int:
    rgba = image.convert("RGBA")
    data = rgba.tobytes()
    residue = 0
    for index in range(0, len(data), 4):
        red, green, blue, alpha = data[index], data[index + 1], data[index + 2], data[index + 3]
        if alpha == 0 and (red or green or blue):
            residue += 1
    return residue


def has_alpha_channel(image: Image.Image) -> bool:
    return "A" in image.getbands() or image.mode == "P" and "transparency" in image.info


def validate_state(theme_dir: Path, state_name: str, expected_frames: int, errors: list[str]) -> StateFrames:
    state_dir = theme_dir / state_name
    if not state_dir.exists():
        add_error(errors, f"{state_name} folder is missing")
        return StateFrames(state_name, [])

    files = sorted(path for path in state_dir.iterdir() if path.suffix.lower() == ".png")
    if len(files) != expected_frames:
        add_error(errors, f"{state_name} must contain {expected_frames} PNG frames, found {len(files)}")

    seen_hashes: set[bytes] = set()
    for index, file_path in enumerate(files):
        expected_name = f"frame_{index:03d}.png"
        if file_path.name != expected_name:
            add_error(errors, f"{state_name}/{file_path.name} should be named {expected_name}")

        if not FRAME_NAME_RE.match(file_path.name):
            add_error(errors, f"{state_name}/{file_path.name} does not match frame_000.png naming")

        try:
            with Image.open(file_path) as image:
                if image.size != CELL_SIZE:
                    add_error(errors, f"{state_name}/{file_path.name} must be 256 x 256, found {image.size[0]} x {image.size[1]}")
                if not has_alpha_channel(image):
                    add_error(errors, f"{state_name}/{file_path.name} must have alpha")
                if visible_pixel_count(image) == 0:
                    add_error(errors, f"{state_name}/{file_path.name} is blank")
                if transparent_residue_count(image) > 0:
                    add_error(errors, f"{state_name}/{file_path.name} has hidden RGB residue in transparent pixels")
        except OSError as exc:
            add_error(errors, f"{state_name}/{file_path.name} cannot be opened as PNG: {exc}")

        try:
            seen_hashes.add(file_path.read_bytes())
        except OSError:
            pass

    if len(files) > 1 and len(seen_hashes) <= 1:
        add_error(errors, f"{state_name} contains duplicated placeholder frames only")

    return StateFrames(state_name, files)


def theme_size_bytes(theme_dir: Path) -> int:
    total = 0
    for path in theme_dir.rglob("*"):
        if path.is_file() and path.name != ".DS_Store":
            total += path.stat().st_size
    return total


def make_contact_sheet(states: list[StateFrames], output: Path) -> None:
    thumbs_per_row = max((len(state.files) for state in states), default=1)
    thumb_size = 64
    label_width = 112
    row_height = thumb_size + 24
    width = label_width + thumbs_per_row * thumb_size
    height = max(1, len(states)) * row_height

    sheet = Image.new("RGBA", (width, height), (250, 250, 250, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for row, state in enumerate(states):
        y = row * row_height
        draw.text((8, y + 24), state.name, fill=(30, 30, 30), font=font)
        for column, file_path in enumerate(state.files):
            with Image.open(file_path) as image:
                thumb = image.convert("RGBA")
                thumb.thumbnail((thumb_size, thumb_size), Image.Resampling.LANCZOS)
                x = label_width + column * thumb_size
                sheet.alpha_composite(thumb, (x + (thumb_size - thumb.width) // 2, y + (thumb_size - thumb.height) // 2))

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def make_previews(states: list[StateFrames], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for state in states:
        frames: list[Image.Image] = []
        for file_path in state.files:
            with Image.open(file_path) as image:
                frame = image.convert("RGBA").resize((128, 128), Image.Resampling.LANCZOS)
                background = Image.new("RGBA", frame.size, (250, 250, 250, 255))
                background.alpha_composite(frame)
                frames.append(background.convert("P", palette=Image.Palette.ADAPTIVE))

        if frames:
            frames[0].save(
                output_dir / f"{state.name}.gif",
                save_all=True,
                append_images=frames[1:],
                duration=100,
                loop=0,
            )


def main() -> int:
    args = parse_args()
    theme_dir = args.theme_dir.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    if not theme_dir.exists() or not theme_dir.is_dir():
        add_error(errors, f"theme directory does not exist: {theme_dir}")
        manifest: dict[str, Any] = {}
    else:
        manifest = load_manifest(theme_dir, errors)
        validate_manifest(theme_dir, manifest, errors, warnings)

    states: list[StateFrames] = []
    if theme_dir.exists():
        for state_name, (_, expected_frames) in EXPECTED_STATES.items():
            states.append(validate_state(theme_dir, state_name, expected_frames, errors))

        total_bytes = theme_size_bytes(theme_dir)
        if total_bytes > MAX_THEME_BYTES:
            add_error(errors, f"theme exceeds 3 MB budget: {total_bytes} bytes")
    else:
        total_bytes = 0

    if args.contact_sheet and not errors:
        make_contact_sheet(states, args.contact_sheet)

    if args.preview_dir and not errors:
        make_previews(states, args.preview_dir)

    result = {
        "ok": not errors,
        "theme_dir": str(theme_dir),
        "theme_id": manifest.get("themeId"),
        "total_bytes": total_bytes,
        "errors": errors,
        "warnings": warnings,
        "outputs": {
            "contact_sheet": str(args.contact_sheet.resolve()) if args.contact_sheet and not errors else None,
            "preview_dir": str(args.preview_dir.resolve()) if args.preview_dir and not errors else None,
        },
    }

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    else:
        print(json.dumps(result, indent=2, ensure_ascii=False))

    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
