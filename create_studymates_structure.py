#!/usr/bin/env python3
"""Create the agreed StudyMates folders in an existing Android Flutter project.

Run from the Flutter project root:
    python3 create_studymates_structure.py
Or specify it explicitly:
    python3 create_studymates_structure.py --root /path/to/studymates

Uses Python 3's standard library. Creates folders and empty .gitkeep files only.
Does not modify Dart code, pubspec.yaml, dependencies, Git configuration or assets.
Safe to rerun. Use --dry-run to preview the missing folders.
"""

import argparse
from pathlib import Path
import sys


FEATURES = (
    "auth", "profile", "home", "communities",
    "rooms", "sessions", "progress", "invites",
)

FOLDERS = (
    "lib/app",
    "lib/core/theme",
    "lib/core/widgets",
    "lib/core/models",
    "lib/preview",
    "assets/rooms",
    "assets/avatars",
    "assets/decorations",
    "docs/design/references",
    "test",
) + tuple(
    "lib/features/{}/{}".format(feature, subfolder)
    for feature in FEATURES
    for subfolder in (
        "presentation/screens",
        "presentation/widgets",
        "presentation/controllers",
        "data",
    )
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(),
                        help="Flutter project folder; defaults to current directory")
    parser.add_argument("--dry-run", action="store_true",
                        help="List missing folders without writing anything")
    args = parser.parse_args()
    root = args.root.expanduser().resolve()

    if not (root / "pubspec.yaml").is_file() or not (root / "android").is_dir():
        parser.error(
            "Choose an existing Android Flutter project containing pubspec.yaml "
            "and android/. Run flutter create first, or supply --root."
        )

    targets = [root / folder for folder in FOLDERS]
    # Check every target before creating anything, including conflicting parents.
    for target in targets:
        resolved = target.resolve()
        if root not in resolved.parents:
            parser.error("Folder resolves outside the project: {}".format(target))
        for candidate in (target,) + tuple(target.parents):
            if candidate == root:
                break
            if candidate.exists() and not candidate.is_dir():
                parser.error("Expected a folder, found a file: {}".format(candidate))

    created = 0
    markers = 0
    for target in targets:
        missing = not target.exists()
        if args.dry_run:
            if missing:
                print("Would create: {}".format(target.relative_to(root)))
            continue

        target.mkdir(parents=True, exist_ok=True)
        if missing:
            created += 1
            print("Created: {}".format(target.relative_to(root)))

        # Git does not track empty directories. Never replace an existing file.
        if next(target.iterdir(), None) is None:
            try:
                with (target / ".gitkeep").open("x"):
                    pass
                markers += 1
            except FileExistsError:
                pass

    if args.dry_run:
        print("Preview complete. No files changed.")
    else:
        print("Done: {} folders created, {} .gitkeep files added.".format(created, markers))
        print("Existing files preserved. Dart implementations are the next step.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except OSError as exc:
        print("Cannot complete folder setup: {}".format(exc), file=sys.stderr)
        sys.exit(1)
