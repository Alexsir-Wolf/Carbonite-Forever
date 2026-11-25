"""Generate Carbonite.Dungeons/Data/*.lua from ForeverDungeonRoutes (#272).

Reads (never writes) a local checkout of ForeverDungeonRoutes by Checkov23
(https://github.com/Checkov23/ForeverDungeonRoutes, MIT) and copies its data
tables: dungeons, default routes, rooms, floors, encounters, entrances, the
minimap pictures of the client and the floors of the new Forever dungeons.

Left out, by license or size:
  * maps/ and every reference to it (Data/Pictures.lua `image`, `credit`):
    art by Santiago Reyes, not under the MIT license;
  * tiles/ and Data/Floors.lua `tiles`: Blizzard map art of another build;
  * the addon's code (everything outside Data/).

The files keep FDR's layout (`local _, DR = ...`); Carbonite.Dungeons/Load.lua
hands the table to Carbonite. Run again whenever FDR's data changes:

    python tools/gen_dungeon_routes.py "<path to ForeverDungeonRoutes repo>"
"""
import os
import re
import shutil
import subprocess
import sys

FILES = ["Dungeons", "Floors", "Encounters", "DefaultRoutes", "Rooms", "Pictures", "Minimaps", "Entrances"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Carbonite.Dungeons")

HEADER = """-- Carbonite.Dungeons | data from ForeverDungeonRoutes {version} ({commit}), Copyright (c) 2026 Checkov23,
-- MIT license (see LICENSE-ForeverDungeonRoutes.txt). Copied by tools/gen_dungeon_routes.py: do not edit by hand.
"""


def addon_dir(repo):
    inner = os.path.join(repo, "ForeverDungeonRoutes")
    return inner if os.path.isdir(os.path.join(inner, "Data")) else repo


def version_of(addon):
    with open(os.path.join(addon, "ForeverDungeonRoutes.toc"), encoding="utf-8") as f:
        m = re.search(r"^## Version:\s*(\S+)", f.read(), re.M)
    return m.group(1) if m else "?"


def commit_of(repo):
    try:
        out = subprocess.run(["git", "-C", repo, "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "?"


def strip_table(text, field):
    """Remove `, field = { ... }` (one level of braces) from every row."""
    return re.sub(r",\s*" + field + r"\s*=\s*\{[^{}]*\}", "", text)


def transform(name, text):
    if name == "Floors":
        text = strip_table(text, "tiles")
        text = re.sub(r"^--\s+tiles\s+.*\n", "", text, flags=re.M)
    elif name == "Pictures":
        text = strip_table(text, "image")
        text = re.sub(r',\s*credit\s*=\s*"[^"]*"', "", text)
    if "maps\\\\" in text or "tiles\\\\" in text:
        raise SystemExit(f"{name}.lua still points at maps/ or tiles/")
    return text


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    repo = os.path.abspath(sys.argv[1])
    addon = addon_dir(repo)
    header = HEADER.format(version=version_of(addon), commit=commit_of(repo))
    data_out = os.path.join(OUT, "Data")
    os.makedirs(data_out, exist_ok=True)
    for name in FILES:
        with open(os.path.join(addon, "Data", name + ".lua"), encoding="utf-8-sig") as f:
            text = transform(name, f.read())
        with open(os.path.join(data_out, name + ".lua"), "w", encoding="utf-8", newline="\n") as f:
            f.write(header + text)
    licence = os.path.join(repo, "LICENSE")
    if not os.path.isfile(licence):
        licence = os.path.join(addon, "LICENSE")
    shutil.copyfile(licence, os.path.join(OUT, "LICENSE-ForeverDungeonRoutes.txt"))
    print(f"ok: {len(FILES)} files from ForeverDungeonRoutes {header.split()[6]}")


if __name__ == "__main__":
    main()
