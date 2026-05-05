#!/usr/bin/env python3
"""Generate all required iOS app icon sizes from AppIcon.svg.

Requires: brew install librsvg  (provides rsvg-convert)
macOS sips is used for resizing (built-in).
"""

import os
import shutil
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SVG_PATH = os.path.join(PROJECT_ROOT, "PackList", "Resources", "AppIcon.svg")
ICON_SET_DIR = os.path.join(
    PROJECT_ROOT, "PackList", "Resources", "Assets.xcassets",
    "AppIcon.appiconset"
)

SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]


def main():
    rsvg = shutil.which("rsvg-convert")
    if not rsvg:
        sys.exit("rsvg-convert not found — run: brew install librsvg")

    os.makedirs(ICON_SET_DIR, exist_ok=True)

    master_path = os.path.join(ICON_SET_DIR, "Icon-1024.png")
    print(f"Rendering master from {SVG_PATH} ...")
    subprocess.run(
        [rsvg, "-w", "1024", "-h", "1024", SVG_PATH, "-o", master_path],
        check=True,
    )
    print("Master rendered at 1024x1024")

    for size in SIZES:
        if size == 1024:
            continue
        out_path = os.path.join(ICON_SET_DIR, f"Icon-{size}.png")
        subprocess.run(
            ["sips", "-z", str(size), str(size), master_path, "--out", out_path],
            check=True,
            capture_output=True,
        )
        print(f"  Saved Icon-{size}.png")

    print(f"\nAll icons written to:\n  {ICON_SET_DIR}")


if __name__ == "__main__":
    main()
