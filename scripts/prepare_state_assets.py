"""Normalize whole sprites and load the user's approved pixel-polished face."""
from collections import deque
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "KurisuDesktop/Resources"
OUT = ROOT / "outputs"
SOURCE = ROOT / "assets/source"
WORK = ROOT / "work/scale-alignment"
CELL = (192, 208)
LOGICAL = (96, 104)


def head_width(image, band_end=None):
    """Maximum silhouette width in the scalp/forehead band, not trailing hair."""
    alpha = image.getchannel("A")
    spans = []
    for y in range(band_end if band_end is not None else round(image.height * .45)):
        row = alpha.crop((0, y, image.width, y + 1)).getbbox()
        if row:
            spans.append(row[2] - row[0])
    return max(spans, default=1)


def aligned_head_width(image, ratio):
    # The sprite moves down when scaled around its floor. Follow the same
    # original scalp band rather than accidentally measuring above the forehead.
    offset = image.height - round(image.height * ratio)
    band_end = offset + round(round(image.height * .45) * ratio)
    return head_width(image, min(image.height, band_end))


def align(image, ratio):
    """Uniform nearest-neighbor scaling, centered and anchored to the same floor."""
    width = max(1, round(image.width * ratio))
    height = max(1, round(image.height * ratio))
    result = Image.new("RGBA", image.size)
    result.alpha_composite(image.resize((width, height), Image.Resampling.NEAREST),
                           ((image.width - width) // 2, image.height - height))
    return result


def remove_connected_background(image):
    """Only remove border-connected blue backdrop; enclosed eye colors survive."""
    image = image.convert("RGBA")
    w, h = image.size
    pixels = image.load()
    seen = bytearray(w * h)
    queue = deque()
    alpha = Image.new("L", image.size, 255)
    ap = alpha.load()

    def visit(x, y):
        i = y * w + x
        if seen[i]:
            return
        seen[i] = 1
        r, g, b, a = pixels[x, y]
        if a == 0 or (r > 130 and g > 150 and b > 160
                      and b >= r + 6 and g >= r + 4):
            ap[x, y] = 0
            queue.append((x, y))

    for x in range(w):
        visit(x, 0)
        visit(x, h - 1)
    for y in range(h):
        visit(0, y)
        visit(w - 1, y)
    while queue:
        x, y = queue.popleft()
        if x:
            visit(x - 1, y)
        if x + 1 < w:
            visit(x + 1, y)
        if y:
            visit(x, y - 1)
        if y + 1 < h:
            visit(x, y + 1)
    image.putalpha(alpha)
    return image


def prepare():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(RES / "kurisu.png").convert("RGBA")
    idle = sheet.crop((0, 0, 192, 208))
    idle_small = idle.resize(LOGICAL, Image.Resampling.NEAREST)
    target = head_width(idle_small)
    rests, rest_metrics = [], []
    for index in range(8):
        source = sheet.crop((index * 192, 5 * 208, (index + 1) * 192, 6 * 208))
        small = source.resize(LOGICAL, Image.Resampling.NEAREST)
        width = head_width(small)
        ratio = min(1, target / width)
        aligned_small = align(small, ratio)
        normalized = aligned_small.resize(CELL, Image.Resampling.NEAREST)
        rests.append(normalized)
        rest_metrics.append({"frame": index, "head_width_before": width * 2,
                             "scale": round(ratio, 4), "head_width_target": target * 2,
                             "head_width_after": aligned_head_width(aligned_small, ratio) * 2})
    rest_atlas = Image.new("RGBA", (1536, 208))
    for index, frame in enumerate(rests):
        rest_atlas.alpha_composite(frame, (index * 192, 0))
    rest_atlas.save(RES / "kurisu-rest.png")

    chosen = remove_connected_background(Image.open(
        SOURCE / "typing-outfit-02.png"))
    crop = chosen.crop(chosen.getchannel("A").getbbox())
    factor = min(90 / crop.width, 98 / crop.height)
    crop = crop.resize((round(crop.width * factor), round(crop.height * factor)),
                       Image.Resampling.NEAREST)
    base = Image.new("RGBA", LOGICAL)
    base.alpha_composite(crop, ((96 - crop.width) // 2, 102 - crop.height))
    typing_width = head_width(base)
    ratio = min(1, target / typing_width)
    # User approved this exact cheek/chin polish after reviewing A6.
    base = Image.open(SOURCE / "typing-face-approved.png").convert("RGBA")
    aligned = align(base, ratio)
    base.save(WORK / "typing-base-before-scale.png")
    aligned.resize(CELL, Image.Resampling.NEAREST).save(WORK / "typing-reference-scale.png")
    (OUT / "state-scale-details.json").write_text(json.dumps({
        "method": "uniform whole-sprite nearest-neighbor scaling; idle scalp width as reference",
        "idle_head_width": target * 2,
        "typing_head_width_before": typing_width * 2,
        "typing_scale": round(ratio, 4),
        "typing_head_width_after": aligned_head_width(aligned, ratio) * 2,
        "rest_frames": rest_metrics,
        "typing_source": "assets/source/typing-face-approved.png",
        "processing": "approved local cheek/chin polish; whole-image scale kept from outfit 02",
    }, ensure_ascii=False, indent=2) + "\n")
    return base, ratio, idle, rests


if __name__ == "__main__":
    prepare()
