"""Match the original happy/click frames to the ordinary idle head width."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "KurisuDesktop/Resources"
OUT = ROOT / "outputs"
CELL = (192, 208)
SCALP_END = 60  # Above hands and trailing hair in all five source frames.


def scalp_width(image, start=0, end=SCALP_END):
    alpha = image.getchannel("A")
    spans = []
    for y in range(start, end):
        bounds = alpha.crop((0, y, image.width, y + 1)).getbbox()
        if bounds:
            spans.append(bounds[2] - bounds[0])
    return max(spans, default=1)


def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(RES / "kurisu.png").convert("RGBA")
    idle = source.crop((0, 0, *CELL))
    target = scalp_width(idle)
    strip = Image.new("RGBA", (CELL[0] * 5, CELL[1]))
    frames = []
    metrics = []
    for index in range(5):
        original = source.crop((index * 192, 4 * 208, (index + 1) * 192, 5 * 208))
        before = scalp_width(original)
        ratio = min(1.0, target / before)
        size = (round(192 * ratio), round(208 * ratio))
        offset = ((192 - size[0]) // 2, 208 - size[1])
        frame = Image.new("RGBA", CELL)
        frame.alpha_composite(original.resize(size, Image.Resampling.NEAREST), offset)
        strip.alpha_composite(frame, (index * 192, 0))
        frames.append(frame)
        metrics.append({
            "frame": index, "scale": round(ratio, 4),
            "head_width_before": before,
            "head_width_after": scalp_width(frame, offset[1],
                                           offset[1] + round(SCALP_END * ratio)),
        })
    strip.save(RES / "kurisu-happy.png")
    (OUT / "click-scale-details.json").write_text(json.dumps({
        "idle_head_width": target, "frames": metrics,
        "method": "uniform nearest-neighbor scale per frame, centered on a common floor",
    }, indent=2) + "\n")

    # Preview the exact runtime strip beside the reference pose.
    preview = Image.new("RGBA", (6 * 192, 236), "#cad9e4")
    draw = ImageDraw.Draw(preview)
    for index, frame in enumerate([idle] + frames):
        preview.alpha_composite(frame, (index * 192, 28))
        label = "Idle reference" if index == 0 else f"Click {index}"
        draw.text((index * 192 + 10, 8), label, fill="#243746")
    preview.convert("RGB").save(OUT / "Kurisu-click-size-comparison.png")
    animation = []
    for frame in [idle] * 4 + frames * 2 + [idle] * 4:
        background = Image.new("RGBA", CELL, "#cad9e4")
        background.alpha_composite(frame)
        animation.append(background.resize((384, 416), Image.Resampling.NEAREST).convert("RGB"))
    animation[0].save(OUT / "Kurisu-click-preview.gif", save_all=True,
                      append_images=animation[1:], duration=180, loop=0, disposal=2)
    print(json.dumps({"idle_head_width": target, "frames": metrics}, indent=2))


if __name__ == "__main__":
    prepare()
