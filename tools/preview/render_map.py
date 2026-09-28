#!/usr/bin/env python3
"""Top-down render of a Neon Bay build, for previews and a minimap.

Usage:
    lune run scripts/build.luau -- --layout dist/layout.json
    python3 tools/preview/render_map.py dist/layout.json docs/images/map.png --size 2400

Needs Pillow and numpy (pip install pillow numpy).
"""

import argparse
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# unit box corners, scaled by half-size per part
CORNERS = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)], dtype=np.float64) * 0.5


def load(path):
    with open(path) as f:
        data = json.load(f)
    parts = data["parts"]
    size = np.array([p["z"] for p in parts], dtype=np.float64)
    frame = np.array([p["f"] for p in parts], dtype=np.float64)
    color = np.array([p["k"] for p in parts], dtype=np.float64)
    material = [p["m"] for p in parts]
    transparency = np.array([p.get("t", 0) for p in parts], dtype=np.float64)
    shape = [p["s"] for p in parts]
    names = [p["n"] for p in parts]
    return parts, size, frame, color, material, transparency, shape, names, data.get("lights", [])


def world_corners(size, frame):
    pos = frame[:, 0:3]
    rot = frame[:, 3:12].reshape(-1, 3, 3)  # rows: R0x R0y R0z ...
    local = CORNERS[None, :, :] * size[:, None, :]  # (n, 8, 3)
    world = np.einsum("nij,nkj->nki", rot, local) + pos[:, None, :]
    return world


def convex_hull(points):
    pts = sorted(set(map(tuple, points)))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def render(layout, out, size_px, bounds=None, glow=True, style="night"):
    parts, size, frame, color, material, transparency, shape, names, lights = load(layout)
    corners = world_corners(size, frame)
    top = corners[:, :, 1].max(axis=1)

    # map bounds: everything except the ocean tiles
    keep = np.array([n not in ("Water", "Seabed") for n in names])
    xs = corners[keep][:, :, 0]
    zs = corners[keep][:, :, 2]
    if bounds is None:
        pad = 120
        bounds = (xs.min() - pad, zs.min() - pad, xs.max() + pad, zs.max() + pad)
    x0, z0, x1, z1 = bounds
    scale = size_px / (x1 - x0)
    w, h = size_px, int((z1 - z0) * scale)

    background = (8, 18, 34) if style == "night" else (40, 90, 140)
    img = Image.new("RGB", (w, h), background)
    draw = ImageDraw.Draw(img)
    glow_layer = Image.new("RGB", (w, h), (0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)

    order = np.argsort(top, kind="stable")
    for idx in order:
        name = names[idx]
        if name in ("Water", "Seabed"):
            continue
        if transparency[idx] >= 0.95:
            continue
        pts = [((c[0] - x0) * scale, (c[2] - z0) * scale) for c in corners[idx]]
        r, g, b = color[idx]
        neon = material[idx] == "Neon"
        # height shading: taller things a bit lighter
        k = 1.0 + min(top[idx], 400) / 900.0
        if style == "night" and not neon:
            k *= 0.9
        fill = (int(min(255, r * k)), int(min(255, g * k)), int(min(255, b * k)))
        if shape[idx] == "Ball":
            cx = sum(p[0] for p in pts) / 8
            cy = sum(p[1] for p in pts) / 8
            rad = size[idx][0] / 2 * scale
            draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=fill)
            if glow:
                glow_draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(int(r), int(g), int(b)) if neon else (0, 0, 0))
            continue
        hull = convex_hull([(round(p[0], 2), round(p[1], 2)) for p in pts])
        if len(hull) < 3:
            continue
        draw.polygon(hull, fill=fill)
        if glow:
            # painter's algorithm on the glow layer too, so covered neon does not glow
            glow_draw.polygon(hull, fill=(int(r), int(g), int(b)) if neon else (0, 0, 0))

    if glow and style == "night":
        for light in lights:
            px = (light["p"][0] - x0) * scale
            pz = (light["p"][2] - z0) * scale
            rad = max(1.5, light["r"] * scale * 0.5)
            col = tuple(int(255 * c * 0.8) for c in light["k"])
            glow_draw.ellipse([px - rad, pz - rad, px + rad, pz + rad], fill=col)
        blurred = glow_layer.filter(ImageFilter.GaussianBlur(radius=max(2, size_px / 500)))
        img = Image.fromarray(
            np.clip(np.asarray(img, dtype=np.int32) + np.asarray(blurred, dtype=np.int32) * 0.9, 0, 255).astype(np.uint8)
        )
    img.save(out)
    return bounds, (w, h)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("layout")
    ap.add_argument("out")
    ap.add_argument("--size", type=int, default=2400, help="output width in pixels")
    ap.add_argument("--bounds", type=float, nargs=4, metavar=("X0", "Z0", "X1", "Z1"), help="world area to draw")
    ap.add_argument("--no-glow", action="store_true")
    args = ap.parse_args()
    bounds, dims = render(args.layout, args.out, args.size, args.bounds, glow=not args.no_glow)
    print(f"wrote {args.out} {dims[0]}x{dims[1]} covering x {bounds[0]:.0f}..{bounds[2]:.0f} z {bounds[1]:.0f}..{bounds[3]:.0f}")


if __name__ == "__main__":
    main()
