"""Tests for the Assetto Corsa -> Roblox converter.

python -m unittest discover -s tools/assetto/tests -v
"""

from __future__ import annotations

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(TOOL))
sys.path.insert(0, TOOL)
sys.path.insert(0, HERE)

import ac2roblox  # noqa: E402
import fixtures  # noqa: E402
from aclib import convert as conv  # noqa: E402
from aclib.ailine import read_ai  # noqa: E402
from aclib.kn5 import KN5Error, mat_mul, read_kn5, strip_textures  # noqa: E402
from aclib.roblox import to_luau  # noqa: E402

try:
    import PIL  # noqa: F401

    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False


def run_cli(*args):
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = ac2roblox.main(list(args))
    return code, buf.getvalue()


class TrackTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="ac2roblox_test_")
        self.track = fixtures.make_track(self.tmp)
        self.kn5_path = os.path.join(self.track, "testring.kn5")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)


class KN5Tests(TrackTestCase):
    def test_reads_structure(self):
        kn5 = read_kn5(self.kn5_path)
        try:
            self.assertEqual(kn5.version, 6)
            self.assertEqual([t.name for t in kn5.textures], ["asphalt.png", "bricks.png", "big.dds"])
            self.assertEqual(kn5.textures[2].read(kn5), b"\x00" * 200_000)
            self.assertEqual([m.name for m in kn5.materials], ["road", "grass", "bricks", "leaves", "concrete"])
            self.assertTrue(kn5.materials[3].alpha_tested)
            self.assertEqual(kn5.materials[0].textures["txDiffuse"], "asphalt.png")
            names = [n.name for n in kn5.nodes]
            for expected in ("testring", "1ROAD_main", "GRP_buildings", "pitbuilding", "flag_anim", "AC_START_0"):
                self.assertIn(expected, names)
            road = next(n for n in kn5.nodes if n.name == "1ROAD_main")
            self.assertEqual(road.triangle_count, 240)
            self.assertEqual(road.mesh.vertex_count, 240)
            flag = next(n for n in kn5.nodes if n.name == "flag_anim")
            self.assertTrue(flag.mesh.skinned)
            far = next(n for n in kn5.nodes if n.name == "stand_far")
            self.assertEqual(far.lod_in, 500.0)
            # meshes inherit the parent dummy's transform
            building = next(n for n in kn5.nodes if n.name == "pitbuilding")
            self.assertEqual(building.world, mat_mul(fixtures.GROUP_MATRIX, fixtures.IDENTITY))
        finally:
            kn5.close()

    def test_header_only_mode_is_fast_and_complete(self):
        kn5 = read_kn5(self.kn5_path, load_meshes=False)
        try:
            meshes = kn5.meshes()
            self.assertTrue(all(n.mesh is None for n in meshes))
            self.assertEqual(sum(n.triangle_count for n in meshes), 240 + 2 + 12 * 5)
        finally:
            kn5.close()

    def test_strip_textures_keeps_geometry(self):
        slim = os.path.join(self.tmp, "slim.kn5")
        before, after = strip_textures(self.kn5_path, slim)
        self.assertLess(after, before - 200_000)
        a, b = read_kn5(self.kn5_path), read_kn5(slim)
        try:
            self.assertEqual(b.textures, [])
            self.assertEqual([n.name for n in a.nodes], [n.name for n in b.nodes])
            ra = next(n for n in a.nodes if n.name == "1ROAD_main").mesh
            rb = next(n for n in b.nodes if n.name == "1ROAD_main").mesh
            self.assertEqual(list(ra.positions), list(rb.positions))
            self.assertEqual(list(ra.indices), list(rb.indices))
        finally:
            a.close()
            b.close()

    def test_rejects_non_kn5(self):
        bad = os.path.join(self.tmp, "bad.kn5")
        with open(bad, "wb") as f:
            f.write(b"PK\x03\x04 definitely a zip, not a kn5 file")
        with self.assertRaises(KN5Error):
            read_kn5(bad)

    def test_truncated_file_is_reported(self):
        with open(self.kn5_path, "rb") as f:
            data = f.read()
        kn5 = read_kn5(self.kn5_path, load_meshes=False)
        start = kn5.materials_start
        kn5.close()
        cut = os.path.join(self.tmp, "cut.kn5")
        with open(cut, "wb") as f:
            f.write(data[: start + (len(data) - start) // 2])  # stop in the middle of the meshes
        with self.assertRaises(KN5Error):
            read_kn5(cut)

    def test_ai_line(self):
        ai = read_ai(os.path.join(self.track, "ai", "fast_lane.ai"))
        self.assertEqual(len(ai.points), 241)
        self.assertTrue(ai.has_sides)
        self.assertAlmostEqual(ai.points[10].side_left, 6.0)
        self.assertGreater(ai.length, 900)


class ClassifierTests(unittest.TestCase):
    def test_categories(self):
        c = conv.Classifier(["ROAD", "GRASS", "KERB", "WALL"])
        self.assertEqual(c.classify("1ROAD_main", None), ("road", True))
        self.assertEqual(c.classify("12KERB_t1", None), ("kerb", True))
        self.assertEqual(c.classify("2GRASS", None), ("grass", True))
        self.assertEqual(c.classify("AC_START_0", None)[0], "helper")
        self.assertEqual(c.classify("tree_line_04", None)[0], "foliage")
        self.assertEqual(c.classify("crowd_stand", None)[0], "crowd")
        self.assertEqual(c.classify("armco_left", None)[0], "wall")
        self.assertEqual(c.classify("pit_building", None)[0], "building")


class ConvertTests(TrackTestCase):
    def convert(self, *extra):
        out = os.path.join(self.tmp, "out")
        code, text = run_cli("convert", self.track, "-o", out, "--max-tris", "100", *extra)
        self.assertEqual(code, 0, text)
        with open(os.path.join(out, "manifest.json")) as f:
            return out, json.load(f), text

    def test_outputs(self):
        out, manifest, text = self.convert()
        objects = manifest["objects"]
        cats = {o["category"] for o in objects}
        self.assertEqual(cats, {"road", "grass", "building", "wall"})
        for o in objects:
            self.assertLessEqual(o["triangles"], 100)
            self.assertLessEqual(max(o["size"]), 2048)
            path = os.path.join(out, o["file"])
            with open(path) as f:
                lines = f.read().splitlines()
            faces = [line for line in lines if line.startswith("f ")]
            self.assertEqual(len(faces), o["triangles"])
            self.assertIn(f"o {o['name']}", lines)
        road_tris = sum(o["triangles"] for o in objects if o["category"] == "road")
        self.assertEqual(road_tris, 240)
        # the big grass quad was subdivided to fit the tile size
        grass = [o for o in objects if o["category"] == "grass"]
        self.assertGreater(sum(o["triangles"] for o in grass), 2)
        # road sits at y ~ 0 after centring
        road_min = min(o["center"][1] - o["size"][1] / 2 for o in objects if o["category"] == "road")
        self.assertAlmostEqual(road_min, 0.0, delta=0.05)  # flat road: size is clamped to 0.05
        self.assertTrue(os.path.isfile(os.path.join(out, "testring_AC.rbxmx")))
        for name in ("Tools", "Manifest", "RacingLine"):
            self.assertTrue(os.path.isfile(os.path.join(out, "luau", name + ".luau")))
        root = ET.parse(os.path.join(out, "testring_AC.rbxmx")).getroot()
        modules = [i for i in root.iter("Item") if i.get("class") == "ModuleScript"]
        self.assertEqual(len(modules), 3)

    def test_building_transform_and_scale(self):
        out, manifest, _ = self.convert()
        spm = manifest["studs_per_meter"]
        off = manifest["offset"]
        b = next(o for o in manifest["objects"] if o["category"] == "building")
        # box centre (0,5,0) through GROUP_MATRIX (90 deg about Y + move to 100,0,50) = (100, 5, 50)
        expected = [100 * spm + off[0], 5 * spm + off[1], 50 * spm + off[2]]
        for got, want in zip(b["center"], expected):
            self.assertAlmostEqual(got, want, delta=0.05)
        # 10 x 10 x 20 box turned 90 degrees -> 20 x 10 x 10 metres
        for got, want in zip(b["size"], [20 * spm, 10 * spm, 10 * spm]):
            self.assertAlmostEqual(got, want, delta=0.05)

    def test_winding_follows_normals(self):
        out, manifest, text = self.convert()
        self.assertRegex(text, r"flipped winding on [1-9]")
        wall = next(o for o in manifest["objects"] if o["category"] == "wall")
        with open(os.path.join(out, wall["file"])) as f:
            lines = f.read().splitlines()
        verts = [tuple(map(float, line.split()[1:])) for line in lines if line.startswith("v ")]
        norms = [tuple(map(float, line.split()[1:])) for line in lines if line.startswith("vn ")]
        for line in lines:
            if line.startswith("f "):
                ids = [int(p.split("/")[0]) - 1 for p in line.split()[1:]]
                a, b, c = (verts[i] for i in ids)
                u = [b[k] - a[k] for k in range(3)]
                v = [c[k] - a[k] for k in range(3)]
                g = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
                n = [sum(norms[i][k] for i in ids) for k in range(3)]
                self.assertGreater(sum(g[k] * n[k] for k in range(3)), 0)

    def test_skips(self):
        _, manifest, text = self.convert()
        names = " ".join(o["name"] for o in manifest["objects"])
        self.assertNotIn("foliage", names)
        self.assertNotIn("alpha", names)
        self.assertIn("distant LOD", text)
        self.assertIn("animated mesh", text)
        _, manifest2, _ = self.convert("--keep", "foliage", "--keep-lod", "--drop", "grass")
        cats = {o["category"] for o in manifest2["objects"]}
        self.assertIn("foliage", cats)  # tree_01 is foliage by name
        self.assertNotIn("grass", cats)
        lod = sum(o["triangles"] for o in manifest2["objects"] if o["category"] == "building")
        self.assertEqual(lod, 24)  # pit building + the distant LOD stand

    def test_mirror(self):
        _, a, _ = self.convert()
        _, b, _ = self.convert("--mirror")
        ba = next(o for o in a["objects"] if o["category"] == "building")
        bb = next(o for o in b["objects"] if o["category"] == "building")
        self.assertAlmostEqual(ba["center"][0], -bb["center"][0], delta=0.05)

    def test_racing_line(self):
        _, manifest, _ = self.convert()
        line = manifest["racing_line"]
        self.assertTrue(line["closed"])
        self.assertGreater(len(line["points"]), 20)
        spm = manifest["studs_per_meter"]
        for p in line["points"]:
            self.assertAlmostEqual(p[3], 6 * spm, delta=0.05)
            self.assertAlmostEqual(p[4], 6 * spm, delta=0.05)

    @unittest.skipUnless(HAVE_PIL, "Pillow not installed")
    def test_texture_colours_and_preview(self):
        out, manifest, _ = self.convert()
        b = next(o for o in manifest["objects"] if o["category"] == "building")
        self.assertEqual(b["color"], [180, 60, 40])
        self.assertTrue(os.path.isfile(os.path.join(out, "preview.png")))

    def test_models_ini_layouts_and_zip(self):
        shutil.rmtree(self.track)
        self.track = fixtures.make_track(self.tmp, with_models_ini=True)
        code, text = run_cli("inspect", self.track)
        self.assertEqual(code, 0, text)
        self.assertIn("layout: short", text)
        # pack into small parts, then convert straight from the first part
        upload = os.path.join(self.tmp, "upload")
        code, text = run_cli("pack", self.track, "-o", upload, "--part-size", "0.004")
        self.assertEqual(code, 0, text)
        parts = sorted(p for p in os.listdir(upload) if ".zip." in p)
        self.assertGreater(len(parts), 1)
        out = os.path.join(self.tmp, "from_zip")
        code, text = run_cli("convert", os.path.join(upload, parts[0]), "-o", out)
        self.assertEqual(code, 0, text)
        with open(os.path.join(out, "manifest.json")) as f:
            self.assertGreater(len(json.load(f)["objects"]), 0)

    def test_pack_removes_textures(self):
        upload = os.path.join(self.tmp, "upload")
        code, text = run_cli("pack", self.track, "-o", upload)
        self.assertEqual(code, 0, text)
        zips = [p for p in os.listdir(upload) if p.endswith(".zip")]
        self.assertEqual(len(zips), 1)
        import zipfile

        with zipfile.ZipFile(os.path.join(upload, zips[0])) as z:
            names = z.namelist()
            self.assertIn("testring/ai/fast_lane.ai", names)
            self.assertIn("testring/data/surfaces.ini", names)
            data = z.read("testring/testring.kn5")
        self.assertLess(len(data), os.path.getsize(self.kn5_path) - 200_000)


class LuauTests(unittest.TestCase):
    def test_literals(self):
        self.assertEqual(to_luau({"a": 1, "b": None}), "{\n\ta = 1,\n}")
        self.assertEqual(to_luau([1.5, 2.0, 'x"y'], compact=True), '{ 1.5, 2, "x\\"y" }')
        self.assertEqual(to_luau({"end": True}, compact=True), '{ ["end"] = true }')


@unittest.skipUnless(shutil.which("lune"), "lune not installed")
class StudioScriptTests(TrackTestCase):
    """Runs the generated Tools module in Lune against fake imported MeshParts."""

    def test_tools_module(self):
        out = os.path.join(self.tmp, "out")
        code, text = run_cli("convert", self.track, "-o", out)
        self.assertEqual(code, 0, text)
        script = os.path.join(TOOL, "tests", "run_tools.luau")
        rbxmx = os.path.join(out, "testring_AC.rbxmx")
        result = subprocess.run(["lune", "run", script, rbxmx], cwd=REPO, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("ALL OK", result.stdout)


if __name__ == "__main__":
    unittest.main()
