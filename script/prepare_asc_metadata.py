#!/usr/bin/env python3
"""Generate asc canonical metadata files from ImagePet metadata JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


FIELD_LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotionalText": 170,
    "description": 4000,
    "whatsNew": 4000,
    "keywords": 100,
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)
        file.write("\n")


def require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be a non-empty string")
    return value.strip()


def build_description(value: Any) -> str:
    if isinstance(value, list):
        paragraphs = [require_string(item, "description[]") for item in value]
        return "\n\n".join(paragraphs)
    return require_string(value, "description")


def build_keywords(value: Any) -> str:
    if not isinstance(value, list):
        return require_string(value, "keywords")
    keywords = [require_string(item, "keywords[]") for item in value]
    return ",".join(keywords)


def validate_limits(fields: dict[str, str]) -> list[str]:
    errors: list[str] = []
    for field, limit in FIELD_LIMITS.items():
        value = fields.get(field, "")
        if len(value) > limit:
            errors.append(f"{field} is {len(value)} characters; limit is {limit}")
    return errors


def remove_tree(path: Path) -> None:
    if not path.exists():
        return
    if path.is_file() or path.is_symlink():
        path.unlink()
        return
    for child in path.iterdir():
        remove_tree(child)
    path.rmdir()


def generate(
    repo_root: Path,
    output_dir: Path,
    clean: bool,
    asc_version: str | None,
    include_whats_new: bool,
) -> None:
    app = load_json(repo_root / "metadata" / "app.json")
    locale_code = app["product"].get("primaryLocale", "en-US")
    marketing_version = app["product"].get("marketingVersion", "1.0")
    version = asc_version or app["product"].get("appStoreVersion") or marketing_version
    locale = load_json(repo_root / "metadata" / "locales" / f"{locale_code}.json")
    copy = locale["appStoreConnect"]
    links = app["links"]

    fields = {
        "name": require_string(copy.get("name"), "name"),
        "subtitle": require_string(copy.get("subtitle"), "subtitle"),
        "promotionalText": require_string(copy.get("promotionalText"), "promotionalText"),
        "description": build_description(copy.get("description")),
        "keywords": build_keywords(copy.get("keywords")),
    }
    if include_whats_new:
        fields["whatsNew"] = require_string(copy.get("whatsNew"), "whatsNew")

    errors = validate_limits(fields)
    for url_field in ("support", "privacyPolicy", "marketing"):
        if not links.get(url_field):
            errors.append(f"links.{url_field} must be set before ASC submission")
    if errors:
        raise ValueError("metadata validation failed:\n- " + "\n- ".join(errors))

    if clean:
        remove_tree(output_dir / "app-info")
        remove_tree(output_dir / "version" / version)

    app_info = {
        "name": fields["name"],
        "subtitle": fields["subtitle"],
        "privacyPolicyUrl": require_string(links.get("privacyPolicy"), "privacyPolicyUrl"),
    }
    version_info = {
        "description": fields["description"],
        "keywords": fields["keywords"],
        "marketingUrl": require_string(links.get("marketing"), "marketingUrl"),
        "promotionalText": fields["promotionalText"],
        "supportUrl": require_string(links.get("support"), "supportUrl"),
    }
    if include_whats_new:
        version_info["whatsNew"] = fields["whatsNew"]

    write_json(output_dir / "app-info" / f"{locale_code}.json", app_info)
    write_json(output_dir / "version" / version / f"{locale_code}.json", version_info)

    print(f"Wrote ASC metadata to {output_dir}")
    print(f"ASC Version: {version}")
    print(f"Marketing Version: {marketing_version}")
    print(f"Locale: {locale_code}")
    print(f"What's New: {'included' if include_whats_new else 'omitted'}")
    print("Next:")
    print(f"  asc metadata validate --dir {output_dir} --output table")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate asc canonical metadata from metadata/app.json and metadata/locales/*.json."
    )
    parser.add_argument(
        "--repo-root",
        default=Path(__file__).resolve().parents[1],
        type=Path,
        help="ImagePet repository root.",
    )
    parser.add_argument(
        "--output-dir",
        default=Path(".codex/asc-metadata"),
        type=Path,
        help="Output directory for asc canonical metadata.",
    )
    parser.add_argument(
        "--asc-version",
        help="App Store Connect version string. Defaults to metadata/app.json product.appStoreVersion.",
    )
    parser.add_argument(
        "--include-whats-new",
        action="store_true",
        help="Include whatsNew in version metadata. Omit it for first-version ASC states where Apple locks this field.",
    )
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Do not remove the output directory before writing.",
    )
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    output_dir = args.output_dir
    if not output_dir.is_absolute():
        output_dir = repo_root / output_dir

    try:
        generate(
            repo_root,
            output_dir.resolve(),
            clean=not args.no_clean,
            asc_version=args.asc_version,
            include_whats_new=args.include_whats_new,
        )
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
