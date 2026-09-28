"""Makes a small upload package out of a big track folder.

Almost all of a track's size is texture images inside the .kn5 files, which Roblox cannot
use directly anyway. The package keeps the geometry (kn5 files with textures removed), the
AI line, data/ and ui/ files, zips them and splits the zip into parts small enough for
GitHub's web upload (25 MiB per file).
"""

from __future__ import annotations

import os
import re
import tempfile
import zipfile

from .kn5 import KN5Error, strip_textures

KEEP = re.compile(r"(\.ai|\.ini|\.json|\.txt|map\.png|outline\.png|preview\.png)$", re.I)
SKIP_DIRS = {"skins", "texture", "textures", "sfx", "extension_textures"}
MIB = 1024 * 1024


def _human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024
    return f"{n:.1f} GB"


def folder_size(root: str) -> int:
    total = 0
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(dirpath, f))
            except OSError:
                pass
    return total


def pack_track(root: str, out_dir: str, part_mib: float = 24.0, log=print) -> dict:
    root = os.path.abspath(root)
    name = os.path.basename(os.path.normpath(root))
    os.makedirs(out_dir, exist_ok=True)
    zip_path = os.path.join(out_dir, f"{name}_slim.zip")
    original = folder_size(root)
    stripped = []
    with tempfile.TemporaryDirectory(prefix="ac2roblox_pack_") as tmp:
        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for dirpath, dirs, files in os.walk(root):
                dirs[:] = [d for d in dirs if d.lower() not in SKIP_DIRS]
                for f in files:
                    src = os.path.join(dirpath, f)
                    arc = os.path.join(name, os.path.relpath(src, root)).replace(os.sep, "/")
                    if f.lower().endswith(".kn5"):
                        slim = os.path.join(tmp, f)
                        try:
                            before, after = strip_textures(src, slim)
                        except KN5Error as exc:
                            log(f"  ! {f} left out, it cannot be read (so it cannot be converted either): {exc}")
                            continue
                        stripped.append((f, before, after))
                        log(f"  {f}: {_human(before)} -> {_human(after)} without textures")
                        z.write(slim, arc)
                        os.remove(slim)
                    elif KEEP.search(f) and os.path.getsize(src) < 8 * MIB:
                        z.write(src, arc)
    zipped = os.path.getsize(zip_path)
    parts = split_file(zip_path, int(part_mib * MIB))
    return {
        "name": name,
        "original": original,
        "zip": zip_path,
        "zipped": zipped,
        "parts": parts,
        "kn5": stripped,
    }


def split_file(path: str, part_size: int) -> list:
    """Splits a file into path.001, path.002, ... (only when it is larger than part_size)."""
    size = os.path.getsize(path)
    if size <= part_size:
        return [path]
    parts = []
    with open(path, "rb") as src:
        index = 1
        while True:
            chunk = src.read(part_size)
            if not chunk:
                break
            part = f"{path}.{index:03d}"
            with open(part, "wb") as out:
                out.write(chunk)
            parts.append(part)
            index += 1
    os.remove(path)
    return parts


def describe(result: dict) -> str:
    lines = [
        f"Track folder:  {_human(result['original'])}",
        f"Upload package: {_human(result['zipped'])} in {len(result['parts'])} file(s):",
    ]
    for p in result["parts"]:
        lines.append(f"  {p}  ({_human(os.path.getsize(p))})")
    return "\n".join(lines)
