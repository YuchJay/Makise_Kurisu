"""Slightly reduce both running cycles, keeping a consistent pixel scale."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "KurisuDesktop/Resources"
OUT = ROOT / "outputs"
CELL = (192, 208)
RUN_SCALE = 0.97


def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(RES / "kurisu.png").convert("RGBA")
    idle = source.crop((0, 0, *CELL))
    size = tuple(round(value * RUN_SCALE) for value in CELL)
    offset = ((CELL[0] - size[0]) // 2, CELL[1] - size[1])
    atlas = Image.new("RGBA", (1536, 416))
    cycles = []
    originals = []
    for row in range(2):
        frames, old_frames = [], []
        for index in range(8):
            original = source.crop((index * 192, (row + 1) * 208,
                                    (index + 1) * 192, (row + 2) * 208))
            frame = Image.new("RGBA", CELL)
            frame.alpha_composite(original.resize(size, Image.Resampling.NEAREST), offset)
            atlas.alpha_composite(frame, (index * 192, row * 208))
            frames.append(frame)
            old_frames.append(original)
        cycles.append(frames)
        originals.append(old_frames)
    atlas.save(RES / "kurisu-run.png")
    (OUT / "run-scale-details.json").write_text(json.dumps({
        "scale": RUN_SCALE, "content": size, "offset": offset,
        "frames_per_direction": 8,
        "method": "one nearest-neighbor resize from original; same scale for both cycles",
    }, indent=2) + "\n")

    def ground(frame):
        result = Image.new("RGBA", CELL, "#cad9e4")
        result.alpha_composite(frame)
        return result.convert("RGB")

    comparison = Image.new("RGB", (960, 444), "#cad9e4")
    draw = ImageDraw.Draw(comparison)
    samples = [("IDLE", idle), ("RIGHT BEFORE", originals[0][0]),
               ("RIGHT -3%", cycles[0][0]), ("LEFT BEFORE", originals[1][0]),
               ("LEFT -3%", cycles[1][0])]
    for col, (label, frame) in enumerate(samples):
        draw.text((col * 192 + 8, 8), label, fill="#243746")
        comparison.paste(ground(frame), (col * 192, 28))
        head = ground(frame).crop((16, 0, 176, 96))
        comparison.paste(head.resize((192, 115), Image.Resampling.NEAREST),
                         (col * 192, 270))
    comparison.save(OUT / "Kurisu-run-size-comparison.png")

    frames = []
    for index in range(8):
        frame = Image.new("RGB", (576, 208), "#cad9e4")
        for col, image in enumerate([idle, cycles[0][index], cycles[1][index]]):
            frame.paste(ground(image), (col * 192, 0))
        frames.append(frame.resize((864, 312), Image.Resampling.NEAREST))
    frames[0].save(OUT / "Kurisu-run-preview.gif", save_all=True,
                   append_images=frames[1:], duration=180, loop=0, disposal=2)
    print(f"Prepared both running cycles at {size}, offset {offset}.")


if __name__ == "__main__":
    prepare()
