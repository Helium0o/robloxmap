"""Reader for Assetto Corsa KN5 model files.

Layout (little endian), as used by Kunos' tools and the community converters:

    "sc6969"  int32 version  [int32 extra if version > 5]
    int32 textureCount   { int32 active, string name, uint32 size, bytes[size] }
    int32 materialCount  { string name, string shader, uint8 blend, uint8 alphaTested,
                           [int32 depthMode if version > 4],
                           int32 propCount { string name, float a, float2 b, float3 c, float4 d },
                           int32 mapCount  { string sampler, int32 slot, string texture } }
    node tree, depth first: int32 class, string name, int32 childCount, uint8 active, then
      class 1 (dummy):   float[16] local matrix (row-major, translation in the last row)
      class 2 (mesh):    uint8 castShadows, isVisible, isTransparent,
                         int32 vertexCount { float3 pos, float3 normal, float2 uv, float3 tangent },
                         int32 indexCount { uint16 }, int32 materialId, int32 layer,
                         float lodIn, float lodOut, float3 sphereCenter, float sphereRadius,
                         uint8 renderable
      class 3 (skinned): uint8 x3, int32 boneCount { string name, float[16] },
                         int32 vertexCount { float3, float3, float2, float3, float4 weights,
                         float4 boneIds }, int32 indexCount { uint16 }, int32 materialId,
                         int32 layer, 8 unknown bytes
Strings are int32 length + UTF-8 bytes. Mesh vertices live in the space of the parent
node; a node's world matrix is local * parentWorld (row vectors).
"""

from __future__ import annotations

import mmap
import os
import struct
from array import array
from dataclasses import dataclass, field

MAGIC = b"sc6969"
IDENTITY = (1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)


class KN5Error(Exception):
    """The file is not a KN5 file we can read."""


@dataclass
class Texture:
    name: str
    offset: int
    size: int
    active: int = 1

    def read(self, kn5: KN5) -> bytes:
        return bytes(kn5.buffer[self.offset : self.offset + self.size])


@dataclass
class Material:
    name: str
    shader: str
    blend_mode: int
    alpha_tested: bool
    depth_mode: int
    properties: dict = field(default_factory=dict)
    textures: dict = field(default_factory=dict)


@dataclass
class Mesh:
    positions: array  # x, y, z, x, y, z, ... in the parent's space
    normals: array
    uvs: array
    indices: array
    material_id: int
    cast_shadows: bool = True
    visible: bool = True
    transparent: bool = False
    layer: int = 0
    lod_in: float = 0.0
    lod_out: float = 0.0
    renderable: bool = True
    skinned: bool = False

    @property
    def vertex_count(self) -> int:
        return len(self.positions) // 3

    @property
    def triangle_count(self) -> int:
        return len(self.indices) // 3


@dataclass
class Node:
    kind: int  # 1 dummy, 2 mesh, 3 skinned mesh
    name: str
    active: bool
    parent: int
    matrix: tuple = IDENTITY  # local transform (dummies only)
    world: tuple = IDENTITY  # transform of this node's space
    mesh: Mesh | None = None
    children: list = field(default_factory=list)
    # counts are always filled, even when meshes are not loaded
    vertex_count: int = 0
    triangle_count: int = 0
    material_id: int = -1
    visible: bool = True
    renderable: bool = True
    lod_in: float = 0.0


@dataclass
class KN5:
    path: str
    version: int
    header_end: int  # offset of the texture count
    materials_start: int  # offset right after the texture blobs
    textures: list
    materials: list
    nodes: list
    buffer: object = None
    file_size: int = 0

    @property
    def texture_bytes(self) -> int:
        return sum(t.size for t in self.textures)

    def meshes(self):
        return [n for n in self.nodes if n.kind in (2, 3)]

    def close(self):
        buf = self.buffer
        self.buffer = None
        if isinstance(buf, mmap.mmap):
            buf.close()


def mat_mul(a, b):
    """Row-major 4x4 product a * b."""
    return tuple(
        a[i * 4 + 0] * b[0 * 4 + j] + a[i * 4 + 1] * b[1 * 4 + j] + a[i * 4 + 2] * b[2 * 4 + j] + a[i * 4 + 3] * b[3 * 4 + j]
        for i in range(4)
        for j in range(4)
    )


class _Reader:
    def __init__(self, buf, size):
        self.buf = buf
        self.size = size
        self.pos = 0

    def need(self, n):
        if n < 0 or self.pos + n > self.size:
            raise KN5Error(f"unexpected end of data at byte {self.pos} (wanted {n} more bytes)")

    def i32(self):
        self.need(4)
        (v,) = struct.unpack_from("<i", self.buf, self.pos)
        self.pos += 4
        return v

    def u8(self):
        self.need(1)
        v = self.buf[self.pos]
        self.pos += 1
        return v

    def f32(self):
        self.need(4)
        (v,) = struct.unpack_from("<f", self.buf, self.pos)
        self.pos += 4
        return v

    def floats(self, n):
        self.need(4 * n)
        v = struct.unpack_from(f"<{n}f", self.buf, self.pos)
        self.pos += 4 * n
        return v

    def string(self, limit=1 << 16):
        n = self.i32()
        if n < 0 or n > limit:
            raise KN5Error(f"implausible string length {n} at byte {self.pos - 4}")
        self.need(n)
        raw = bytes(self.buf[self.pos : self.pos + n])
        self.pos += n
        return raw.decode("utf-8", errors="replace")

    def count(self, what, limit):
        n = self.i32()
        if n < 0 or n > limit:
            raise KN5Error(f"implausible {what} count {n} at byte {self.pos - 4}")
        return n

    def skip(self, n):
        self.need(n)
        self.pos += n


def _read_mesh(r: _Reader, skinned: bool, load: bool) -> tuple:
    cast_shadows = r.u8() != 0
    visible = r.u8() != 0
    transparent = r.u8() != 0
    if skinned:
        bones = r.count("bone", 1 << 12)
        for _ in range(bones):
            r.string()
            r.skip(64)
    vcount = r.count("vertex", 1 << 24)
    stride = 19 if skinned else 11  # floats per vertex
    positions = normals = uvs = None
    if load:
        data = r.floats(vcount * stride)
        px, py, pz = data[0::stride], data[1::stride], data[2::stride]
        nx, ny, nz = data[3::stride], data[4::stride], data[5::stride]
        tu, tv = data[6::stride], data[7::stride]
        positions = array("f", [c for xyz in zip(px, py, pz) for c in xyz])
        normals = array("f", [c for xyz in zip(nx, ny, nz) for c in xyz])
        uvs = array("f", [c for uv in zip(tu, tv) for c in uv])
    else:
        r.skip(vcount * stride * 4)
    icount = r.count("index", 1 << 26)
    if load:
        r.need(icount * 2)
        indices = array("H")
        indices.frombytes(bytes(r.buf[r.pos : r.pos + icount * 2]))
        if struct.pack("<H", 1) != struct.pack("=H", 1):
            indices.byteswap()
        r.pos += icount * 2
    else:
        indices = None
        r.skip(icount * 2)
    material_id = r.i32()
    layer = r.i32()
    lod_in = lod_out = 0.0
    renderable = True
    if skinned:
        r.skip(8)
    else:
        lod_in = r.f32()
        lod_out = r.f32()
        r.skip(16)  # bounding sphere
        renderable = r.u8() != 0
    mesh = None
    if load:
        mesh = Mesh(
            positions=positions,
            normals=normals,
            uvs=uvs,
            indices=indices,
            material_id=material_id,
            cast_shadows=cast_shadows,
            visible=visible,
            transparent=transparent,
            layer=layer,
            lod_in=lod_in,
            lod_out=lod_out,
            renderable=renderable,
            skinned=skinned,
        )
    return mesh, vcount, icount // 3, material_id, visible, renderable, lod_in


def read_kn5(path: str, load_meshes: bool = True) -> KN5:
    """Parses a KN5 file. Texture images are not read (only their offsets are kept).

    With load_meshes=False only names, counts and transforms are read, which is fast
    even for files of several hundred megabytes.
    """
    f = open(path, "rb")
    size = os.fstat(f.fileno()).st_size
    if size < 16:
        f.close()
        raise KN5Error(f"{path}: file is too small to be a KN5 model")
    buf = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    f.close()
    try:
        return _parse(path, buf, size, load_meshes)
    except KN5Error:
        buf.close()
        raise
    except (struct.error, ValueError, OverflowError, MemoryError) as exc:
        buf.close()
        raise KN5Error(f"{path}: could not be read ({exc})") from exc


def parse_kn5_bytes(data: bytes, load_meshes: bool = True, name: str = "<memory>") -> KN5:
    return _parse(name, data, len(data), load_meshes)


def _parse(path, buf, size, load_meshes) -> KN5:
    r = _Reader(buf, size)
    r.need(6)
    if bytes(buf[0:6]) != MAGIC:
        raise KN5Error(
            f"{path}: not a standard KN5 file (missing 'sc6969' header). It may be encrypted or "
            "protected by its author, in which case it cannot be converted."
        )
    r.pos = 6
    version = r.i32()
    if version > 5:
        r.i32()  # unknown extra value
    if version < 4 or version > 6:
        raise KN5Error(f"{path}: KN5 version {version} is not supported (expected 5 or 6)")
    header_end = r.pos

    textures = []
    for _ in range(r.count("texture", 1 << 16)):
        active = r.i32()
        name = r.string()
        tsize = r.i32()
        if tsize < 0:
            raise KN5Error(f"{path}: negative texture size for {name!r}")
        textures.append(Texture(name=name, offset=r.pos, size=tsize, active=active))
        r.skip(tsize)
    materials_start = r.pos

    materials = []
    try:
        for _ in range(r.count("material", 1 << 16)):
            name = r.string()
            shader = r.string()
            blend = r.u8()
            alpha_tested = r.u8() != 0
            depth = r.i32() if version > 4 else 0
            props = {}
            for _ in range(r.count("material property", 1 << 12)):
                pname = r.string()
                values = r.floats(10)
                props[pname] = values[0]
            maps = {}
            for _ in range(r.count("texture mapping", 1 << 10)):
                sampler = r.string()
                r.i32()  # slot
                maps[sampler] = r.string()
            materials.append(Material(name, shader, blend, alpha_tested, depth, props, maps))

        nodes = []
        stack = [[-1, 1]]
        while stack:
            if stack[-1][1] == 0:
                stack.pop()
                continue
            stack[-1][1] -= 1
            parent = stack[-1][0]
            kind = r.i32()
            name = r.string()
            children = r.count("child", 1 << 20)
            active = r.u8() != 0
            node = Node(kind=kind, name=name, active=active, parent=parent)
            parent_world = nodes[parent].world if parent >= 0 else IDENTITY
            if kind == 1:
                node.matrix = r.floats(16)
                node.world = mat_mul(node.matrix, parent_world)
            elif kind in (2, 3):
                mesh, vcount, tris, mat_id, visible, renderable, lod_in = _read_mesh(r, kind == 3, load_meshes)
                node.mesh = mesh
                node.world = parent_world
                node.vertex_count = vcount
                node.triangle_count = tris
                node.material_id = mat_id
                node.visible = visible
                node.renderable = renderable
                node.lod_in = lod_in
            else:
                raise KN5Error(f"{path}: unknown node class {kind} for node {name!r} at byte {r.pos}")
            nodes.append(node)
            index = len(nodes) - 1
            if parent >= 0:
                nodes[parent].children.append(index)
            if children:
                stack.append([index, children])
    except KN5Error as exc:
        raise KN5Error(
            f"{exc}. The textures were readable, so the model data itself looks non-standard "
            "(protected/encrypted mods cannot be converted)."
        ) from exc

    return KN5(
        path=path,
        version=version,
        header_end=header_end,
        materials_start=materials_start,
        textures=textures,
        materials=materials,
        nodes=nodes,
        buffer=buf,
        file_size=size,
    )


def strip_textures(src: str, dst: str) -> tuple:
    """Writes a copy of a KN5 without embedded textures (geometry and materials intact).

    Returns (original size, new size)."""
    kn5 = read_kn5(src, load_meshes=False)
    try:
        with open(dst, "wb") as out:
            out.write(kn5.buffer[: kn5.header_end])
            out.write(struct.pack("<i", 0))
            view = memoryview(kn5.buffer)
            chunk = 1 << 24
            for start in range(kn5.materials_start, kn5.file_size, chunk):
                out.write(view[start : min(kn5.file_size, start + chunk)])
            view.release()
        return kn5.file_size, os.path.getsize(dst)
    finally:
        kn5.close()
