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

## Typing size adjustment (0.8.4)

The user requested a slight increase after comparing with idle. The previous
scalp-width match included lower trailing hair; the visible forehead measured
roughly 98–100 pixels against idle's 108. `prepare_laptop_assets.py` now applies
a 1.05 size multiplier, changing content from 155 × 168 to 163 × 176 pixels
inside the same 192 × 208 cell. It still resizes directly from the approved A6
logical source once with nearest-neighbor sampling, centered on the same floor.
Hand/shoulder regions and the breathing cutoff follow the new size and offset.
All entry, typing, waiting and exit frames use this same adjusted base.
`outputs/Kurisu-typing-size-comparison.png` shows idle, previous and adjusted
typing; `outputs/typing-size-details.json` records the exact geometry.

## Approved A6 face and refined animation (0.7.0)

The user approved `outputs/typing-face-pixel-round/A6-chin-right-restored-logical.png`
after reviewing local cheek/chin contour edits. This is now the typing source.
The 0.6.0 chosen anime outfit, gaze, eyes and catchlights remain the basis.
This step is disclosed local pixel polish, not a new model image.

At 0.7.0, `prepare_laptop_assets.py` scaled that source once directly to
155 × 168 content inside a 192 × 208 cell, exactly as in the accepted preview.
The 0.8.4 adjustment above supersedes that size. The script authors 12 entry,
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

### Click reaction normalization (0.8.3)

`scripts/prepare_click_assets.py` derives `kurisu-happy.png` (960 × 208)
from the original five happy frames. The maximum silhouette width in the top
60 source rows supplies a scalp/forehead reference of 108 pixels from idle;
this band avoids the moving hands and trailing hair. Each whole frame scales
uniformly with nearest-neighbor sampling, centered on the same floor.
The five scale factors are approximately 0.844, 0.973, 0.900, 0.931 and 0.947.
Runtime rendering and alpha hit maps both use this separate normalized strip.
The original source sheet and facial artwork remain intact.

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
