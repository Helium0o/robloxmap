"""Default colours per part (used for the .mtl and mirrored in the Roblox setup script)."""

ENGINE_COVER = {
    "NissanSkylineGTR_R34": ("CamCover", (0.62, 0.06, 0.06)),
    "ToyotaSupra_MK4": ("CamCover", (0.55, 0.56, 0.58)),
}

BODY_COLOURS = {
    "NissanSkylineGTR_R34": ("BaysideBlue", (0.098, 0.290, 0.627)),
    "ToyotaSupra_MK4": ("RenaissanceRed", (0.690, 0.075, 0.090)),
}

COMMON = {
    "Glass": ("Glass", (0.06, 0.07, 0.08)),
    "DoorGlass": ("Glass", (0.06, 0.07, 0.08)),
    "TrunkGlass": ("Glass", (0.06, 0.07, 0.08)),
    "DoorTrim": ("BlackTrim", (0.07, 0.07, 0.075)),
    "HoodTrim": ("BlackTrim", (0.07, 0.07, 0.075)),
    "Splitter": ("Carbon", (0.05, 0.05, 0.055)),
    "Diffuser": ("Carbon", (0.05, 0.05, 0.055)),
    "EngineBay": ("Undertray", (0.05, 0.05, 0.05)),
    "Engine": ("Engine", (0.30, 0.30, 0.31)),
    "HeadLights": ("HeadlightHousing", (0.16, 0.17, 0.18)),
    "HeadlightGlass": ("ClearGlass", (0.85, 0.90, 0.95)),
    "TailLightsDark": ("TailDark", (0.32, 0.01, 0.02)),
    "Underbody": ("Undertray", (0.05, 0.05, 0.055)),
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
        for p in ("Body", "Wing", "Mirror", "Door", "Hood", "Trunk"):
            self[p] = body
        self["EngineCover"] = ENGINE_COVER[car_name]
        self.car = car_name

    def get(self, key, default=None):
        base = key.rstrip("0123456789")  # split chunks: Trim2 -> Trim
        if base[-2:] in ("_R", "_L"):
            base = base[:-2]
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
