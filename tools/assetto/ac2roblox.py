#!/usr/bin/env python3
"""Assetto Corsa track -> Roblox Studio.

    python ac2roblox.py inspect  <track>             what is inside, and how big
    python ac2roblox.py convert  <track> -o out/     Roblox-ready meshes + helper model
    python ac2roblox.py pack     <track> -o upload/  small package to upload/share

<track> is a track folder (assettocorsa/content/tracks/<name>), a single .kn5 file, a .zip
of the track, or the first part (.zip.001) of a package made by `pack`.

Only Python 3.9+ is needed. Pillow (pip install pillow) is optional: with it the converter
also colours buildings from their textures and draws a preview.png of the result.
"""

from __future__ import annotations

import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aclib import (
    __version__,  # noqa: E402
    roblox,  # noqa: E402
)
from aclib import convert as conv  # noqa: E402
from aclib.ailine import AIError, read_ai  # noqa: E402
from aclib.kn5 import KN5Error, read_kn5  # noqa: E402
from aclib.pack import _human, describe, pack_track  # noqa: E402
from aclib.track import open_track  # noqa: E402

LEGAL = (
    "Only convert tracks you made or have permission to use: most Assetto Corsa mods do not allow\n"
    "conversion, and publishing someone else's (or a game's ripped) models on Roblox can get the\n"
    "experience taken down."
)


def cmd_inspect(args) -> int:
    track = open_track(args.track, args.layout)
    try:
        print(f"Track: {track.name}   layout: {track.layout or '-'}   other layouts: {', '.join(track.layouts) or '-'}")
        classifier = conv.Classifier(track.surfaces)
        totals = {}
        grand_tex = 0
        for ref in track.models:
            if not os.path.isfile(ref.path):
                print(f"  missing: {ref.path}")
                continue
            kn5 = read_kn5(ref.path, load_meshes=False)
            try:
                meshes = kn5.meshes()
                tris = sum(n.triangle_count for n in meshes)
                grand_tex += kn5.texture_bytes
                print(
                    f"\n{os.path.basename(ref.path)}  (KN5 v{kn5.version}, {_human(kn5.file_size)}, "
                    f"textures {_human(kn5.texture_bytes)} in {len(kn5.textures)} images)"
                )
                print(f"  {len(kn5.materials)} materials, {len(meshes)} meshes, {tris:,} triangles")
                for node in meshes:
                    mat = kn5.materials[node.material_id] if 0 <= node.material_id < len(kn5.materials) else None
                    cat, _ = classifier.classify(node.name, mat)
                    if node.lod_in > 0:
                        cat = "lod"
                    totals[cat] = totals.get(cat, 0) + node.triangle_count
                    if args.verbose:
                        print(f"    {node.name:40s} {node.triangle_count:8,d} tris  {cat:9s} {mat.shader if mat else ''}")
            finally:
                kn5.close()
        print("\nTriangles by category (Roblox: max 20,000 per MeshPart):")
        for cat, n in sorted(totals.items(), key=lambda kv: -kv[1]):
            note = " (skipped by default)" if cat in conv.SKIPPED_BY_DEFAULT or cat == "lod" else ""
            print(f"  {cat:10s} {n:10,d}{note}")
        kept = sum(n for c, n in totals.items() if c not in conv.SKIPPED_BY_DEFAULT and c != "lod")
        print(f"  => about {kept:,} triangles to convert, roughly {max(1, kept // 15000)}+ MeshParts")
        print(f"\nTexture data: {_human(grand_tex)} (not needed for the default conversion)")
        if track.ai_path:
            try:
                ai = read_ai(track.ai_path)
                print(f"AI line: {len(ai.points)} points, {ai.length / 1000:.2f} km, widths: {'yes' if ai.has_sides else 'no'}")
            except AIError as exc:
                print(f"AI line: unreadable ({exc})")
        else:
            print("AI line: none (buildRoad() needs ai/fast_lane.ai)")
    finally:
        track.cleanup()
    return 0


def cmd_convert(args) -> int:
    started = time.time()
    track = open_track(args.track, args.layout)
    try:
        settings = conv.Settings(
            studs_per_meter=args.studs_per_meter,
            tile=args.tile,
            max_tris=args.max_tris,
            mirror=args.mirror,
            keep=set(args.keep or []),
            drop=set(args.drop or []),
            keep_lod=args.keep_lod,
            exclude=args.exclude or [],
            include=args.include or [],
            colors=not args.no_colors,
            swap_sides=args.swap_sides,
        )
        report = conv.Report()
        out = os.path.abspath(args.out)
        os.makedirs(out, exist_ok=True)
        print(f"Converting {track.name} (layout {track.layout or '-'}) -> {out}")
        geoms = conv.load_geometry(track, settings, report)
        if not geoms:
            print("Nothing to convert: every mesh was skipped. Try --keep building/foliage or check `inspect -v`.")
            return 1
        conv.center_geometry(geoms, settings, report)
        objects = conv.write_tiles(geoms, out, track.name, settings, report)
        line = conv.racing_line(track, settings, report)
        manifest = conv.write_manifest(out, track, settings, report, objects, line)
        rbxmx = roblox.write_roblox_files(out, manifest, line)
        preview = os.path.join(out, "preview.png")
        has_preview = roblox.render_preview(preview, geoms, manifest)

        print("\nKept triangles:")
        for cat, n in sorted(report.kept.items(), key=lambda kv: -kv[1]):
            print(f"  {cat:10s} {n:10,d}")
        if report.skipped:
            print("Skipped triangles:")
            for why, n in sorted(report.skipped.items(), key=lambda kv: -kv[1]):
                print(f"  {why:28s} {n:10,d}")
        x0, y0, z0, x1, y1, z1 = report.bounds
        print(f"\n{len(objects)} meshes in {out}/meshes, flipped winding on {report.flipped} source meshes")
        print(f"Track size in Roblox: {x1 - x0:,.0f} x {z1 - z0:,.0f} studs, height range {y1 - y0:,.0f} studs")
        if line:
            print(f"Racing line: {len(line['points'])} points ({'closed loop' if line['closed'] else 'open'})")
        print(f"Studio helper model: {rbxmx}")
        if has_preview:
            print(f"Preview: {preview} (compare with the track's map.png; if mirrored, add --mirror)")
        for w in report.warnings:
            print(f"warning: {w}")
        print(f"Done in {time.time() - started:.0f}s.\n\nNext steps (see docs/assetto-corsa.md):")
        print("  1. Studio: Import 3D -> select the .obj files in meshes/ (keep default axes, units = studs)")
        print(f"  2. Right-click Workspace > Insert from File > {os.path.basename(rbxmx)}")
        folder = manifest["track"] + "_AC"
        print(f"  3. Command bar: require(workspace.{folder}.Tools).assemble()")
        print(f"     optional:    require(workspace.{folder}.Tools).buildRoad()")
        print("\n" + LEGAL)
    finally:
        track.cleanup()
    return 0


def cmd_pack(args) -> int:
    src = os.path.abspath(args.track)
    if not os.path.isdir(src):
        print("pack needs the track folder (assettocorsa/content/tracks/<name>)")
        return 2
    print(f"Packing {src} (textures are left out) ...")
    result = pack_track(src, args.out, args.part_size)
    print()
    print(describe(result))
    if len(result["parts"]) == 1:
        print(
            "\nUpload: on github.com open your repository > Add file > Upload files, drag the zip in\n"
            "and commit it to a new branch (files up to 25 MB can be uploaded in the browser).\n"
        )
    else:
        print(
            "\nUpload: on github.com open your repository > Add file > Upload files, drag all the\n"
            "parts in (each is under 25 MB), and commit them to a new branch. Joining them again:\n"
            "  Windows:     copy /b name.zip.001+name.zip.002 name.zip\n"
            "  macOS/Linux: cat name.zip.0* > name.zip\n"
            "(ac2roblox.py convert name.zip.001 also works directly.)\n"
        )
    print(LEGAL)
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", action="version", version=f"ac2roblox {__version__}")
    sub = ap.add_subparsers(dest="command", required=True)

    p = sub.add_parser("inspect", help="summarise a track")
    p.add_argument("track")
    p.add_argument("--layout")
    p.add_argument("-v", "--verbose", action="store_true", help="list every mesh")
    p.set_defaults(func=cmd_inspect)

    p = sub.add_parser("convert", help="make Roblox meshes and the helper model")
    p.add_argument("track")
    p.add_argument("-o", "--out", default="ac_output")
    p.add_argument("--layout", help="layout name for tracks with several (see inspect)")
    p.add_argument("--studs-per-meter", type=float, default=1 / 0.28, help="scale (default 3.571: 1 stud = 0.28 m)")
    p.add_argument("--tile", type=float, default=1024.0, help="tile size in studs (max 2000)")
    p.add_argument("--max-tris", type=int, default=19000, help="triangles per mesh (Roblox max 20000)")
    p.add_argument("--mirror", action="store_true", help="flip east/west if the result looks mirrored")
    p.add_argument("--keep", nargs="*", metavar="CAT", help="also keep: foliage alpha crowd sky helper")
    p.add_argument("--drop", nargs="*", metavar="CAT", help="leave out: building ground grass sand wall kerb")
    p.add_argument("--keep-lod", action="store_true", help="keep distant level-of-detail meshes")
    p.add_argument("--exclude", nargs="*", metavar="REGEX", help="skip meshes whose name matches")
    p.add_argument("--include", nargs="*", metavar="REGEX", help="always keep meshes whose name matches")
    p.add_argument("--no-colors", action="store_true", help="do not sample texture colours")
    p.add_argument("--swap-sides", action="store_true", help="swap AI line left/right widths")
    p.set_defaults(func=cmd_convert)

    p = sub.add_parser("pack", help="make a small upload package (no textures)")
    p.add_argument("track")
    p.add_argument("-o", "--out", default="ac_upload")
    p.add_argument("--part-size", type=float, default=24.0, help="MiB per part (GitHub web upload limit is 25)")
    p.set_defaults(func=cmd_pack)

    args = ap.parse_args(argv)
    if getattr(args, "tile", 1024) > 2000:
        ap.error("--tile must be at most 2000 studs (Roblox part size limit is 2048)")
    if getattr(args, "max_tris", 1) > 20000:
        ap.error("--max-tris must be at most 20000 (Roblox mesh limit)")
    try:
        return args.func(args)
    except (KN5Error, AIError, FileNotFoundError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
