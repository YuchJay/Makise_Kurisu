"""Author the approved A6 face and refined local pixel animation at final size.

No new model generation. Resize once from the approved logical image; the
0.8.4 size adjustment adds 5% to the previous 155x168 content.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from prepare_state_assets import prepare

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs"
RES = ROOT / "KurisuDesktop/Resources"
CELL = (192, 208)
TYPING_SIZE_MULTIPLIER = 1.05
source, ratio, idle, rests = prepare()
base = Image.new("RGBA", CELL)
reference_content = (round(192 * ratio), round(208 * ratio))
reference_offset = ((192-reference_content[0])//2, 208-reference_content[1])
content = (round(reference_content[0] * TYPING_SIZE_MULTIPLIER),
           round(reference_content[1] * TYPING_SIZE_MULTIPLIER))
offset = ((192-content[0])//2, 208-content[1])
base.alpha_composite(source.resize(content, Image.Resampling.NEAREST),
                     offset)
base.save(OUT / "Kurisu-approved-face-sprite.png")


def mapped_x(x):
    return offset[0] + round((x-reference_offset[0])*content[0]/reference_content[0])


def mapped_y(y):
    return offset[1] + round((y-reference_offset[1])*content[1]/reference_content[1])


HEAD_END = mapped_y(139)
ARM_TOP, ARM_END = mapped_y(155), mapped_y(173)
ARM_LEFT, ARM_END_X = mapped_x(97), mapped_x(126)
WRIST_END_X = mapped_x(109)
SHOULDER_TOP, SHOULDER_BOTTOM = mapped_y(158), mapped_y(170)


def working(press=0, wrist=0, shoulder=0, breath=0):
    frame = base.copy()
    # Subtle whole-head breathing. No facial reshaping or eye repainting:
    # translate the entire head with its approved chin and catchlights intact.
    if breath:
        # Stop above the laptop's top edge; furniture must stay stationary.
        head = base.crop((0, 0, 192, HEAD_END))
        frame.paste((0,0,0,0), (0,0,192,HEAD_END))
        frame.alpha_composite(head, (0, breath))
    # Source-to-destination row remapping of the forearm. Keep the top/bottom
    # rows pinned, with a one-pixel easing step into the two-pixel press.
    if press or wrist or shoulder:
        original = base.load()
        pixels = frame.load()
        for y in range(ARM_TOP, ARM_END):
            for x in range(ARM_LEFT, ARM_END_X):
                # The small hand is left of the sleeve. Shift its interior
                # rows with a softer lead/lag from the sleeve response.
                amount = wrist if x < WRIST_END_X else press
                if y < SHOULDER_TOP or y > SHOULDER_BOTTOM:
                    amount = shoulder
                edge = min(y-ARM_TOP,ARM_END-1-y)
                dy = min(amount, max(0, edge))
                sample_y = min(ARM_END-1, max(ARM_TOP, y-dy))
                pixels[x,y] = original[x,sample_y]
    return frame


def shifted(image, dy):
    result = Image.new("RGBA", CELL)
    result.alpha_composite(image,(0,dy))
    return result


def transition(progress):
    if progress == 0:
        return idle.copy()
    if progress == 1:
        return base.copy()
    # Cubic easing gives the start/end more dwell than the middle. Both
    # directions use exactly the same visual positions when interrupted.
    ease = progress*progress*(3-2*progress)
    # Align the two crowns throughout the settle so the fade does not show
    # two heads at different heights. The whole character travels into the seat.
    crown_delta = base.getbbox()[1] - idle.getbbox()[1]
    old = shifted(idle, round(ease*crown_delta))
    new = shifted(base, -round((1-ease)*crown_delta))
    return Image.blend(old.convert("RGBa"),new.convert("RGBa"),ease).convert("RGBA")


opening = [transition(i/11) for i in range(12)]
# Three unequal keystroke phrases: anticipation, contact, recoil, tiny pause.
# The neutral endpoints make the loop seam and entry/exit quiet.
typing_spec = [
    (0,0,0), (0,1,0), (1,1,0), (2,1,1),
    (1,0,0), (0,0,0), (0,0,0), (1,0,0),
    (2,1,0), (1,1,0), (0,0,0), (0,0,0),
    (0,1,0), (1,1,0), (1,0,0), (0,0,0),
]
typing = [working(press=p,wrist=w,shoulder=s) for p,w,s in typing_spec]
waiting = [working(breath=b) for b in (0,0,0,1,1,1,1,1,0,0,0,0)]
closing = list(reversed(opening))
rows = [opening,typing,waiting,closing]
atlas = Image.new("RGBA",(3072,832))
for row, frames in enumerate(rows):
    for col in range(16):
        atlas.alpha_composite(frames[min(col,len(frames)-1)],(col*192,row*208))
atlas.save(RES / "kurisu-laptop.png")

contact = Image.new("RGBA",(3072,960),"#cad9e4")
draw = ImageDraw.Draw(contact)
for row,(label,frames) in enumerate(zip(("enter","type","wait","exit"),rows)):
    for col,frame in enumerate(frames):
        draw.text((col*192+8,row*240+8),f"{label} {col:02d}",fill="#243746")
        contact.alpha_composite(frame,(col*192,row*240+24))
contact.convert("RGB").save(OUT / "Kurisu-laptop-frames.png")


def ground(image):
    result=Image.new("RGBA",CELL,"#cad9e4")
    result.alpha_composite(image)
    return result.convert("RGB")


sequence, durations = [], []
for frames, duration, repeats in [
    (opening,60,1),(typing,100,3),(waiting,300,1),(closing,70,1),
]:
    for _ in range(repeats):
        for frame in frames:
            sequence.append(ground(frame).resize((384,416),Image.Resampling.NEAREST))
            durations.append(duration)
durations[-1]=900
sequence[0].save(OUT/"Kurisu-laptop-preview.gif",save_all=True,
                 append_images=sequence[1:],duration=durations,loop=0,disposal=2)
ground(base).resize((576,624),Image.Resampling.NEAREST).save(OUT/"Kurisu-seated-typing.png")
comparison=Image.new("RGB",(1152,480),"#cad9e4")
draw=ImageDraw.Draw(comparison)
for col,(label,image) in enumerate([
    ("IDLE / SIZE REFERENCE",idle),("LONG IDLE / MATCHED",rests[5]),
    ("TYPING / A6 +5% SIZE",base),
]):
    draw.text((col*384+12,12),label,fill="#243746")
    comparison.paste(ground(image).resize((384,416),Image.Resampling.NEAREST),(col*384,48))
comparison.save(OUT/"Kurisu-state-size-comparison.png")

previous = Image.new("RGBA", CELL)
previous.alpha_composite(source.resize(reference_content, Image.Resampling.NEAREST),
                         reference_offset)
size_comparison = Image.new("RGB", (1152,480), "#cad9e4")
draw = ImageDraw.Draw(size_comparison)
for col, (label, image) in enumerate([
    ("IDLE / REFERENCE", idle), ("TYPING / BEFORE", previous),
    ("TYPING / +5%", base),
]):
    draw.text((col*384+12,12), label, fill="#243746")
    size_comparison.paste(ground(image).resize((384,416),Image.Resampling.NEAREST),
                          (col*384,48))
size_comparison.save(OUT/"Kurisu-typing-size-comparison.png")
(OUT/"typing-size-details.json").write_text(json.dumps({
    "size_multiplier": TYPING_SIZE_MULTIPLIER,
    "previous_content": reference_content, "content": content,
    "offset": offset,
    "animation_regions": {"head_end": HEAD_END, "arm_top": ARM_TOP,
                          "arm_end": ARM_END, "arm_left": ARM_LEFT,
                          "arm_end_x": ARM_END_X},
    "note": "Same approved A6 source; one nearest-neighbor resize; floor anchored.",
}, indent=2) + "\n")
print(f"Prepared approved A6 at {content}, +5% size, and 12/16/12/12 frames.")
