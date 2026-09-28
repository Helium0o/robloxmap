"""Finding the pieces of an Assetto Corsa track: KN5 models, layouts, AI line, surfaces.

A track folder (content/tracks/<name>) usually looks like:

    <name>.kn5 or several kn5 files listed in models.ini / models_<layout>.ini
    ai/fast_lane.ai                (or <layout>/ai/fast_lane.ai)
    data/surfaces.ini, map.ini ... (or <layout>/data/...)
    ui/ui_track.json, map.png, extension/, skins/, texture/ ...

Sources can also be a .zip (including split parts made by `ac2roblox.py pack`).
"""

from __future__ import annotations

import configparser
import glob
import os
import re
import shutil
import tempfile
import zipfile
from dataclasses import dataclass, field

DEFAULT_SURFACES = ["ROAD", "GRASS", "KERB", "SAND", "WALL", "GROUND", "PIT", "GRAVEL"]


@dataclass
class ModelRef:
    path: str
    position: tuple = (0.0, 0.0, 0.0)
    rotation: tuple = (0.0, 0.0, 0.0)


@dataclass
class Track:
    root: str
    name: str
    layout: str | None
    layouts: list
    models: list
    ai_path: str | None
    surfaces: list = field(default_factory=lambda: list(DEFAULT_SURFACES))
    temp_dir: str | None = None

    def cleanup(self):
        if self.temp_dir and os.path.isdir(self.temp_dir):
            shutil.rmtree(self.temp_dir, ignore_errors=True)


def _read_ini(path: str) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(strict=False, interpolation=None, inline_comment_prefixes=(";", "//"))
    parser.optionxform = str
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    # AC ini files sometimes contain lines before the first section
    if not text.lstrip().startswith("["):
        text = "[__top__]\n" + text
    parser.read_string(text)
    return parser


def _floats(text: str, default=(0.0, 0.0, 0.0)) -> tuple:
    try:
        values = tuple(float(v) for v in re.split(r"[,\s]+", text.strip()) if v)
        return values if len(values) == 3 else default
    except ValueError:
        return default


def _find_ci(directory: str, name: str) -> str | None:
    """Case-insensitive file lookup (tracks made on Windows often mix cases)."""
    if not os.path.isdir(directory):
        return None
    for entry in os.listdir(directory):
        if entry.lower() == name.lower():
            return os.path.join(directory, entry)
    return None


def list_layouts(root: str) -> list:
    layouts = []
    for ini in glob.glob(os.path.join(root, "models_*.ini")):
        layouts.append(os.path.basename(ini)[len("models_") : -len(".ini")])
    return sorted(layouts)


def _combine_parts(first_part: str, target_dir: str) -> str:
    """Joins track.zip.001, .002, ... into one zip in target_dir."""
    base = first_part[: -len(".001")]
    parts = sorted(glob.glob(glob.escape(base) + ".[0-9][0-9][0-9]"))
    combined = os.path.join(target_dir, os.path.basename(base))
    with open(combined, "wb") as out:
        for part in parts:
            with open(part, "rb") as src:
                shutil.copyfileobj(src, out, 1 << 20)
    return combined


def _extract_zip(path: str) -> tuple:
    temp = tempfile.mkdtemp(prefix="ac2roblox_")
    if path.endswith(".001"):
        path = _combine_parts(path, temp)
    wanted = re.compile(r"\.(kn5|ai|ini|json|png|txt)$", re.I)
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            if info.is_dir() or not wanted.search(info.filename):
                continue
            target = os.path.normpath(os.path.join(temp, "src", info.filename))
            if not target.startswith(os.path.join(temp, "src")):
                continue  # ignore path traversal entries
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(info) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out, 1 << 20)
    # the track root is the shallowest folder holding a kn5 or models ini
    candidates = []
    for dirpath, _dirs, files in os.walk(os.path.join(temp, "src")):
        if any(f.lower().endswith(".kn5") or re.match(r"models(_.*)?\.ini$", f, re.I) for f in files):
            candidates.append(dirpath)
    if not candidates:
        shutil.rmtree(temp, ignore_errors=True)
        raise FileNotFoundError(f"{path}: no .kn5 files inside the archive")
    candidates.sort(key=lambda p: p.count(os.sep))
    return candidates[0], temp


def open_track(source: str, layout: str | None = None) -> Track:
    """Accepts a track folder, a single .kn5, a .zip or the first part of a split zip."""
    temp = None
    source = os.path.abspath(source)
    if os.path.isfile(source) and source.lower().endswith(".kn5"):
        root = os.path.dirname(source)
        name = os.path.splitext(os.path.basename(source))[0]
        return Track(root=root, name=name, layout=None, layouts=[], models=[ModelRef(source)], ai_path=None)
    if os.path.isfile(source) and (source.lower().endswith(".zip") or source.endswith(".001")):
        root, temp = _extract_zip(source)
    elif os.path.isdir(source):
        root = source
    else:
        raise FileNotFoundError(f"{source}: expected a track folder, a .kn5 file or a .zip")

    name = os.path.basename(os.path.normpath(root))
    if name == "src" and temp:
        kn5s = glob.glob(os.path.join(root, "*.kn5"))
        name = os.path.splitext(os.path.basename(kn5s[0]))[0] if kn5s else "track"
    layouts = list_layouts(root)
    if layout is None and layouts:
        layout = layouts[0]
    if layout is not None and layout not in layouts:
        raise ValueError(f"layout {layout!r} not found; available: {', '.join(layouts) or 'none'}")

    models = []
    ini = os.path.join(root, f"models_{layout}.ini") if layout else _find_ci(root, "models.ini")
    if ini and os.path.isfile(ini):
        parser = _read_ini(ini)
        for section in parser.sections():
            if not section.upper().startswith("MODEL"):
                continue
            file_name = parser.get(section, "FILE", fallback="").strip()
            if not file_name:
                continue
            path = _find_ci(root, file_name) or os.path.join(root, file_name)
            models.append(
                ModelRef(
                    path=path,
                    position=_floats(parser.get(section, "POSITION", fallback="0,0,0")),
                    rotation=_floats(parser.get(section, "ROTATION", fallback="0,0,0")),
                )
            )
    if not models:
        models = [ModelRef(p) for p in sorted(glob.glob(os.path.join(root, "*.kn5")))]
    if not models:
        raise FileNotFoundError(f"{root}: no .kn5 models found")

    ai_path = None
    for base in ([os.path.join(root, layout)] if layout else []) + [root]:
        candidate = os.path.join(base, "ai", "fast_lane.ai")
        if os.path.isfile(candidate):
            ai_path = candidate
            break

    surfaces = list(DEFAULT_SURFACES)
    for base in ([os.path.join(root, layout)] if layout else []) + [root]:
        ini_path = os.path.join(base, "data", "surfaces.ini")
        if os.path.isfile(ini_path):
            parser = _read_ini(ini_path)
            keys = [parser.get(s, "KEY", fallback="").strip().upper() for s in parser.sections()]
            surfaces = sorted({k for k in keys if k} | set(DEFAULT_SURFACES))
            break

    return Track(
        root=root,
        name=name,
        layout=layout,
        layouts=layouts,
        models=models,
        ai_path=ai_path,
        surfaces=surfaces,
        temp_dir=temp,
    )
