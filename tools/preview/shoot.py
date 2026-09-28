#!/usr/bin/env python3
"""Screenshots of the three.js night preview (viewer.html) from a few camera spots.

Usage (from the repo root, after `lune run scripts/build.luau -- --layout dist/layout.json`
and `npm install` inside tools/preview):

    python3 tools/preview/shoot.py dist/layout.json docs/images

Needs `pip install playwright`; uses the Chromium that Playwright finds, or the one in
the CHROMIUM_PATH environment variable.
"""

import argparse
import functools
import http.server
import os
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent

# name: (camera position, look-at point, field of view)
SHOTS = {
    "overview": ((-3900, 1500, 2500), (-1300, 0, -250), 55),
    "downtown": ((-1934, 11, 600), (-1934, 70, -900), 72),
    "freeway": ((-2560, 46, -1289), (-700, 40, -1280), 62),
    "bridge": ((60, 55, 330), (980, 110, -320), 62),
    "harbor": ((900, 140, 950), (0, 10, 150), 60),
    "airport": ((3500, 320, 250), (2350, 0, -1350), 58),
    "ramp": ((-3150, 45, -120), (-2990, 12, -320), 60),
    "corner": ((-2560, 70, -980), (-2830, 30, -1240), 60),
    "garage": ((-2400, 22, 250), (-2400, 16, 560), 64),
    "shops": ((-2600, 9, -968), (-3100, 22, -960), 66),
    "landing": ((1720, 70, -60), (2150, 15, -320), 60),
    "rampwest": ((-3290, 7, -326), (-2880, 40, -326), 62),
    "rampeast": ((2330, 7, -314), (1900, 40, -314), 62),
}


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(directory):
    handler = functools.partial(QuietHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("layout", help="layout.json written by scripts/build.luau --layout")
    ap.add_argument("outdir")
    ap.add_argument("--only", nargs="*", help="shot names to render")
    ap.add_argument("--size", default="1600x900")
    ap.add_argument("--day", action="store_true", help="flat daylight, for checking geometry")
    args = ap.parse_args()

    width, height = (int(v) for v in args.size.split("x"))
    layout = Path(args.layout).resolve()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    server = serve(REPO)
    base = f"http://127.0.0.1:{server.server_address[1]}"
    layout_url = "/" + os.path.relpath(layout, REPO)

    with sync_playwright() as p:
        launch = {"args": ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]}
        if os.environ.get("CHROMIUM_PATH"):
            launch["executable_path"] = os.environ["CHROMIUM_PATH"]
        browser = p.chromium.launch(**launch)
        page = browser.new_page(viewport={"width": width, "height": height})
        for name, (cam, look, fov) in SHOTS.items():
            if args.only and name not in args.only:
                continue
            url = (
                f"{base}/tools/preview/viewer.html?layout={layout_url}"
                f"&cam={','.join(map(str, cam))}&look={','.join(map(str, look))}&fov={fov}&w={width}&h={height}"
                + ("&mode=day&bloom=0.3" if args.day else "")
            )
            page.goto(url)
            page.wait_for_function("window.__done === true", timeout=300_000)
            error = page.evaluate("window.__error || null")
            if error:
                raise SystemExit(f"{name}: {error}")
            out = outdir / f"preview-{name}{'-day' if args.day else ''}.png"
            page.locator("canvas").screenshot(path=str(out))
            print("wrote", out)
        browser.close()
    server.shutdown()


if __name__ == "__main__":
    main()
