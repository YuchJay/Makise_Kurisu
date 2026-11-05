# Asset provenance

## Repository layout after cleanup

The current source images live in `assets/source/typing-outfit-02.png` and
`assets/source/typing-face-approved.png`. The current prompts and final polish
record are beside them. Runtime resources remain under `KurisuDesktop/Resources/`.
Asset scripts no longer depend on discarded images under `outputs/`.

The older `outputs/...` paths in historical sections below document the original
review process. Those trial directories have been moved into local
`work/archive/artwork/` and are not required to build or regenerate the app.
Generated previews, app bundles, local archives, caches and logs are ignored.

## Current approved A6 face and refined animation (0.7.0)

The user approved `outputs/typing-face-pixel-round/A6-chin-right-restored-logical.png`
after reviewing local cheek/chin contour edits. This is now the typing source.
The 0.6.0 chosen anime outfit, gaze, eyes and catchlights remain the basis.
This step is disclosed local pixel polish, not a new model image.

`prepare_laptop_assets.py` scales that source once directly to 155 × 168 content
inside a 192 × 208 cell, exactly as in the accepted preview. It authors 12 entry,
16 typing, 12 waiting, and 12 exit frames at final output pixel resolution.
The 3072 × 832 atlas uses 16 columns per row, padding unused cells with the final
frame. Runtime frame loading and alpha click maps use the same 64-cell layout.

The hand and sleeve use one/two output-pixel row remapping with staggered
anticipation, contact, recoil and pauses. The head breathes as one intact piece.
Entry/exit align the crowns while easing into the seat, with a reversible fade.
The timer runs at 24 Hz; typing is 10 fps normally, accelerated for fast input;
waiting is a 12-step 3.6-second cycle. No new eye shape or blink drawing is added.

## Original poses

`KurisuDesktop/Resources/kurisu.png` derives from the installed
`~/.petdex/pets/kurisu/spritesheet.webp`, installed at the user's
request via `npx petdex@latest install kurisu`.

`scripts/prepare_assets.py` decodes RGBA and clears low-alpha pixels and purple
matte fringes. The original sheet has 8 × 9 cells of 192 × 208 pixels.
`AppIcon.icns` uses the original idle frame on a slate blue tile.
`menubar.png` is a locally authored monochrome silhouette.

## Current approved anime outfit 02 and scale alignment (0.6.0)

The user selected `outputs/anime-outfit-generated/anime-outfit-02.png`, a full
model image edit using two input images: the approved C pose and the original
TV anime character-page screenshot. The prompt and raw API records are retained
in that directory. This version replaces the white-coat typing sprite.

`scripts/prepare_state_assets.py` removes only the border-connected blue backdrop,
crops the transparent bounds, and fits the full generated sprite to the logical
96 × 104 authoring canvas using nearest-neighbor sampling. No face, eye, hair,
clothing or hand pixels are repainted or pasted from another source.

The ordinary idle pose supplies the scalp/forehead width reference. Typing scales
uniformly to about 80.6%; settled rest frames scale to about 76–77%. The rest
entry frames receive their own scale as the original head grows during sitting.
Sprites remain centered on the same floor; the head-size measurement band follows
the scale and downward translation. Exact values are in
`outputs/state-scale-details.json`.

`kurisu-rest.png` is a separate 1536 × 208 strip of eight normalized rest frames.
`SpriteAtlas` uses it for `.sleep`, including the same alpha maps used for mouse
hit handling. The original nine-row sheet remains unchanged.

`scripts/prepare_laptop_assets.py` animates the chosen 02 artwork with the existing
small forearm and breathing offsets, then uniformly scales every working frame.
The current `kurisu-laptop.png` keeps the four-row entry/typing/waiting/exit layout.
`outputs/Kurisu-state-size-comparison.png` shows idle, settled rest and typing
on the same-size cells at a common floor.

## Historical approved C laptop pose (0.5.0)

The user selected C among four fully generated concepts, then approved the
palette/pixel-matched C image and its small eye-highlight variant.

- Original full generation: `outputs/C-matched/C-generated-master.png`.
- Successful prompt: `outputs/C-matched/generation-prompt-text-only.txt`.
- Third-party API: geek2api, model alias `gpt-image-2.5-sunburst`.
  This is the provider's alias; the underlying model is not independently verified.
- Preparation: chroma removal, binary alpha, palette mapping and nearest-neighbor
  scaling in `scripts/prepare_C_review.py`.
- Highlight polish: `scripts/prepare_C_gloss_review.py` adjusts eight iris pixels.
- Approved animation source: `outputs/C-matched/C-glossy-logical-96x104.png`.

Version 0.5.0 authored small pixel movements from that approved
source. The eyes moved with the whole head without feature repainting. The visible
forearm lifts by one logical pixel; the head breathes by one logical pixel.
Desk and laptop stay fixed. The transition to and from the original idle pose uses
a short reversible alpha fade with a small downward movement. Premultiplied
alpha blending preserves clean transparent edges; resting/typing frames use
the approved binary alpha.

The transparent `KurisuDesktop/Resources/kurisu-laptop.png` atlas is 1536 × 832,
with four rows: entry (6), typing (8), waiting (4), exit (6). Frames are 192 × 208,
nearest-neighbor doubled from 96 × 104 logical pixels, except original idle
endpoints which retain original pixels.

`outputs/Kurisu-laptop-preview.gif`, `Kurisu-laptop-frames.png`, and
`Kurisu-seated-typing.png` preview the shipping frames on a solid background.
Prior 0.4.x laptop frames were local compositions of the original idle character;
those rejected face/eye edits are no longer the laptop animation source.

The character is Makise Kurisu fan art. This record does not assert ownership
or grant redistribution rights to the character or contributed artwork.
