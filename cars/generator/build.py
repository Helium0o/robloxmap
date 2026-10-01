"""
Build the car meshes:  python3 build.py [--scale METRES_PER_STUD]

Writes cars/<Name>/<Name>.obj + .mtl, ready for Roblox Studio's 3D importer.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import carkit as ck  # noqa: E402
import assemble  # noqa: E402
import r34  # noqa: E402
try:
    import supra  # noqa: E402
except ImportError:
    supra = None
from palette import MATERIALS  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", type=float, default=ck.METRES_PER_STUD,
                    help="metres per stud (default 0.28 = Roblox real-world scale)")
    ap.add_argument("--only", default=None)
    args = ap.parse_args()
    for mod in [m for m in (r34, supra) if m]:
        spec = mod.SPEC
        if args.only and args.only.lower() not in spec["name"].lower():
            continue
        car = assemble.build(spec)
        out_dir = os.path.join(ROOT, spec["name"])
        os.makedirs(out_dir, exist_ok=True)
        mats = MATERIALS(spec["name"])
        car.export_obj(os.path.join(out_dir, spec["name"] + ".obj"), mats, args.scale)
        counts = {k: len(m.F) for k, m in car._split_parts(19000)}
        print(spec["name"], "total tris:", sum(counts.values()))
        for k, v in counts.items():
            flag = "  <-- over Roblox 20k limit" if v > 20000 else ""
            print(f"   {k:20s}{v:7d}{flag}")
        with open(os.path.join(out_dir, "parts.json"), "w") as fh:
            json.dump({k: mats.get(k, ("Default", None))[0] for k in counts}, fh, indent=1)


if __name__ == "__main__":
    main()
