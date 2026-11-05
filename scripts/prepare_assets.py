"""One-time asset preparation; runtime and rebuilds use bundled assets.

Requires Pillow only for regenerating images.
"""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "KurisuDesktop" / "Resources"
WORK = ROOT / "work" / "AppIcon.iconset"
DEST.mkdir(parents=True, exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path,
                    help="Optional original Petdex sprite sheet; defaults to bundled normalized artwork.")
args = parser.parse_args()
SOURCE = args.source or DEST / "kurisu.png"
sheet = Image.open(SOURCE).convert("RGBA")
if sheet.size != (1536, 1872):
    raise ValueError(f"Expected a 1536x1872 original sheet, got {sheet.size}")
pixels = list(sheet.get_flattened_data())
# Remove residual purple chroma-matte fringes without changing the auburn hair,
# red tie, white coat or cyan eyes. Normalize barely visible alpha noise too.
sheet.putdata([
    (0, 0, 0, 0)
    if a < 16 or (r > 45 and b > 45 and g < min(r, b) * 0.6)
    else (r, g, b, a)
    for r, g, b, a in pixels
])
sheet.save(DEST / "kurisu.png")

frame = sheet.crop((0, 0, 192, 208))
icon = Image.new("RGBA", (1024, 1024), "#cad9e4")
draw = ImageDraw.Draw(icon)
draw.rectangle((48, 48, 975, 975), outline="#243746", width=16)
sprite = frame.resize((768, 832), Image.Resampling.NEAREST)
icon.alpha_composite(sprite, (128, 96))
for logical in [16, 32, 128, 256, 512]:
    for multiplier in [1, 2]:
        px = logical * multiplier
        suffix = "@2x" if multiplier == 2 else ""
        icon.resize((px, px), Image.Resampling.NEAREST).save(
            WORK / f"icon_{logical}x{logical}{suffix}.png"
        )

# Pixel silhouette of a small companion head, authored geometry.
menu = Image.new("RGBA", (36, 36))
d = ImageDraw.Draw(menu)
for box in [(10, 4, 25, 7), (6, 8, 29, 11), (4, 12, 31, 25),
            (8, 26, 27, 29), (12, 30, 23, 31)]:
    d.rectangle(box, fill="black")
d.rectangle((10, 16, 13, 19), fill=(0, 0, 0, 0))
d.rectangle((22, 16, 25, 19), fill=(0, 0, 0, 0))
menu.save(DEST / "menubar.png")

# Deliverable preview, composited on a real neutral background to show alpha.
preview = Image.new("RGBA", (768, 416), "#cad9e4")
preview.alpha_composite(frame.resize((384, 416), Image.Resampling.NEAREST), (0, 0))
wave = sheet.crop((192, 624, 384, 832)).resize((384, 416), Image.Resampling.NEAREST)
preview.alpha_composite(wave, (384, 0))
(ROOT / "outputs").mkdir(parents=True, exist_ok=True)
preview.convert("RGB").save(ROOT / "outputs" / "Kurisu-preview.png")
