#!/usr/bin/env python3
"""Prevent publishing a release tag whose installer reports a different version."""
from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path

VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
ROOT = Path(__file__).resolve().parents[1]


def validate(project: Path, tag: str | None = None, app: Path | None = None) -> str:
    spec = project.read_text()
    match = re.search(r'^\s*MARKETING_VERSION:\s*"(' + VERSION + r')"\s*$', spec, re.MULTILINE)
    build = re.search(r'^\s*CURRENT_PROJECT_VERSION:\s*"([1-9][0-9]*)"\s*$', spec, re.MULTILINE)
    if not match or not build:
        raise ValueError("project.yml needs a stable major.minor.patch version and a positive build number")
    version = match.group(1)
    if tag is not None and (not re.fullmatch("v" + VERSION, tag) or tag != "v" + version):
        raise ValueError(f"Release tag must be v{version}; update project.yml and regenerate the Xcode project first")
    if app is not None:
        with (app / "Contents/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        if info.get("CFBundleShortVersionString") != version or str(info.get("CFBundleVersion")) != build.group(1):
            raise ValueError("Built app version differs from project.yml; regenerate ChatHub.xcodeproj and rebuild")
    return version


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    try:
        version = validate(ROOT / "project.yml", args.tag, args.app)
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Release validation failed: {error}\n")
    print(f"Release version validated: {version}")


if __name__ == "__main__":
    main()
