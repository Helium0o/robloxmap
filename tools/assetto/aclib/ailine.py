"""Reader for Assetto Corsa AI spline files (ai/fast_lane.ai).

    int32 version (7), int32 pointCount, int32 lapTime, int32 sampleCount
    pointCount x { float3 position, float length, int32 id }
    int32 extraCount, extraCount x 18 floats:
      speed, gas, brake, obsoleteLatG, radius, sideLeft, sideRight, camber, direction,
      normal xyz, length, forward xyz, tag, grade
    (optional grid data follows and is ignored)

sideLeft/sideRight are the distances in metres from the line to the track edges.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass


class AIError(Exception):
    pass


@dataclass
class AIPoint:
    x: float
    y: float
    z: float
    length: float
    side_left: float = 0.0
    side_right: float = 0.0
    speed: float = 0.0


@dataclass
class AILine:
    version: int
    points: list

    @property
    def length(self) -> float:
        return self.points[-1].length if self.points else 0.0

    @property
    def has_sides(self) -> bool:
        return any(p.side_left > 0 or p.side_right > 0 for p in self.points)


def read_ai(path: str) -> AILine:
    with open(path, "rb") as f:
        data = f.read()
    return parse_ai(data, path)


def parse_ai(data: bytes, name: str = "<memory>") -> AILine:
    if len(data) < 16:
        raise AIError(f"{name}: too small to be an AI spline")
    version, count, _lap_time, _samples = struct.unpack_from("<4i", data, 0)
    if version != 7:
        raise AIError(f"{name}: AI spline version {version} is not supported (expected 7)")
    if count <= 1 or 16 + count * 20 > len(data):
        raise AIError(f"{name}: implausible point count {count}")
    pos = 16
    points = []
    for x, y, z, length, _id in struct.iter_unpack("<4fi", data[pos : pos + count * 20]):
        points.append(AIPoint(x, y, z, length))
    pos += count * 20
    if pos + 4 <= len(data):
        (extra,) = struct.unpack_from("<i", data, pos)
        pos += 4
        if extra == count and pos + extra * 72 <= len(data):
            for p, values in zip(points, struct.iter_unpack("<18f", data[pos : pos + extra * 72])):
                p.speed = values[0]
                p.side_left = values[5]
                p.side_right = values[6]
    return AILine(version=version, points=points)


def write_ai(path: str, points: list) -> None:
    """Writes a minimal version-7 spline (used by the tests)."""
    out = bytearray(struct.pack("<4i", 7, len(points), 0, 0))
    length = 0.0
    prev = None
    for i, p in enumerate(points):
        if prev is not None:
            length += ((p.x - prev.x) ** 2 + (p.y - prev.y) ** 2 + (p.z - prev.z) ** 2) ** 0.5
        out += struct.pack("<4fi", p.x, p.y, p.z, length, i)
        prev = p
    out += struct.pack("<i", len(points))
    for p in points:
        out += struct.pack("<18f", p.speed, 1, 0, 0, 0, p.side_left, p.side_right, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0)
    with open(path, "wb") as f:
        f.write(out)
