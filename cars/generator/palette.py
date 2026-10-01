"""Default colours per part (used for the .mtl and mirrored in the Roblox setup script)."""

BODY_COLOURS = {
    "NissanSkylineGTR_R34": ("BaysideBlue", (0.098, 0.290, 0.627)),
    "ToyotaSupra_MK4": ("RenaissanceRed", (0.690, 0.075, 0.090)),
}

COMMON = {
    "Glass": ("Glass", (0.10, 0.13, 0.16)),
    "HeadLights": ("HeadlightGlass", (0.86, 0.88, 0.90)),
    "Lens": ("Lens", (0.95, 0.97, 1.00)),
    "Chrome": ("Chrome", (0.75, 0.76, 0.78)),
    "TailLights": ("TailRed", (0.70, 0.02, 0.03)),
    "TailLightsInner": ("TailInner", (0.95, 0.85, 0.85)),
    "Indicators": ("Amber", (0.98, 0.55, 0.05)),
    "Reflectors": ("TailRed", (0.70, 0.02, 0.03)),
    "Grille": ("BlackPlastic", (0.04, 0.04, 0.045)),
    "Trim": ("BlackTrim", (0.07, 0.07, 0.075)),
    "PanelGaps": ("Gap", (0.02, 0.02, 0.02)),
    "Badge": ("Chrome", (0.75, 0.76, 0.78)),
    "Plate": ("Plate", (0.95, 0.95, 0.92)),
    "MirrorGlass": ("Mirror", (0.70, 0.75, 0.80)),
    "Interior": ("Interior", (0.09, 0.09, 0.10)),
    "Steering": ("Interior", (0.09, 0.09, 0.10)),
    "Undertray": ("Undertray", (0.05, 0.05, 0.05)),
    "Exhaust": ("Titanium", (0.62, 0.60, 0.58)),
}

PREFIX = {
    "Tire_": ("Rubber", (0.06, 0.06, 0.065)),
    "Rim_": ("Alloy", (0.72, 0.73, 0.75)),
    "Brake_": ("Disc", (0.35, 0.35, 0.36)),
    "Caliper_": ("Caliper", (0.80, 0.62, 0.18)),
}


class MATERIALS(dict):
    def __init__(self, car_name):
        super().__init__(COMMON)
        body = BODY_COLOURS[car_name]
        for p in ("Body", "Wing", "Mirrors"):
            self[p] = body
        self.car = car_name

    def get(self, key, default=None):
        base = key.rstrip("0123456789")  # split chunks: Trim2 -> Trim
        if key in self:
            return self[key]
        if base in self:
            return self[base]
        for pre, v in PREFIX.items():
            if key.startswith(pre):
                if pre == "Caliper_" and "Supra" in self.car:
                    return ("Caliper", (0.18, 0.18, 0.19))
                return v
        return default
