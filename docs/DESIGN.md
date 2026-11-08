---
name: Kurisu Desktop
description: A native desktop companion with crisp pixel animation.
colors:
  setting-ground: "rgb(91% 94% 96%)"
  setting-sidebar: "rgb(79% 85% 89%)"
  setting-ink: "rgb(12% 19% 25%)"
  setting-muted: "rgb(28% 36% 42%)"
  setting-accent: "rgb(58% 24% 13%)"
  pixel-ink: "rgb(11% 16% 22%)"
  pixel-key: "rgb(85% 90% 94%)"
  pixel-active: "rgb(88% 46% 28%)"
typography:
  title:
    fontFamily: "system-ui"
    fontSize: "22px"
    fontWeight: 600
  body:
    fontFamily: "system-ui"
    fontSize: "13px"
  caption:
    fontFamily: "system-ui"
    fontSize: "12px"
spacing:
  group: "10px"
  section: "24px"
  content: "28px"
---

# Design System: Kurisu Desktop

Current implementation baseline: 0.9.0 (2026-11-08). Historical visual
experiments and superseded parameters remain in PROGRESS and ASSETS.

## Overview

The user chose pixel art. The character and laptop scene use crisp square
pixels, while native macOS settings retain readable Chinese text and standard
controls. A cool blue setting surface separates the auburn character from
whatever desktop appears behind the transparent companion.

## Colors

The setting ground and sidebar form two flat regions. Dark ink carries headings,
muted ink carries explanations, and auburn marks the main permission action.
The approved laptop scene uses a red rear lid and a wooden desk; no screen UI
or exposed keyboard is added.

## Typography

Settings use system text for Chinese legibility. The character name alone uses
the system monospace at 25 points and bold weight. Native menu typography,
focus rings and disabled states remain supplied by macOS.

## Layout

Settings occupy a 684 × 680 point content region, with a 224 point sidebar and
a 460 point scrollable settings column. Sidebar padding is 24; column padding
is 28. Related controls use 10–12 point gaps and sections use 24.

## Elevation & Depth

The companion is transparent with no window shadow. Settings use flat tonal
separation and native title bar chrome.

## Shapes

The character and accessory keyboard disable interpolation and antialiasing.
Native buttons, switches and segmented pickers retain system shapes.

## Components

- Companion: nonactivating floating panel; alpha-based pointer pass-through.
- Laptop: approved C-derived seated artwork with anime outfit 02 and A6 face,
  downturned gaze and preserved catchlights. A red laptop back faces the viewer;
  the wooden desk hides the lower body. Opening/closing use 12 frames each,
  typing 16 and waiting 12. Current content is 163 × 176 inside 192 × 208.
- Computer playback: sit/open over 0.75 seconds; wait after 1.1 seconds without
  confirmed typing; start closing at 3.2 seconds with 0.80 second duration.
  Closing reverses on new typing. Waiting cycle is 3.6 seconds.
- Settings: native controls, labeled permission status and recoverable errors.
- Menu bar: monochrome pixel silhouette with accessible label.
- Motion: 24 render ticks per second; original sprite frames use 0.18 seconds.
  Typing uses 0.10 seconds per frame, accelerated by 1.55 for rapid input.
  User/system reduced motion uses static state feedback.
- Rest: play source frames 0–4 once, hold seated frame 5, use frame 6 for an
  occasional nod. A 4.8-second breathing cycle moves the sprite one source
  pixel. Reduced motion shows seated frame 5 without the entrance or breathing.
- Drag: current horizontal movement chooses run-left or run-right.
- Input status: “监听已开启” does not claim a key has arrived; separate feedback
  confirms keyboard activity or explains secure input.
- Authorization: one primary permission action, actual system consent for
  “Kurisu 输入监听”, visible connection status and collapsed fallback instructions.
- Hover card: 304 × 270, 0.45-second dwell and 0.32-second departure grace;
  note summary, counts and focus status; no clipboard body or activation on hover.
- Utilities: 440 × 600 content with standard native title-bar buttons,
  no duplicate close control in the content header.
- Settings offers a permission-free laptop preview and displays the same frames
  as the companion during that sequence.

## Do's and Don'ts

- Do keep nearest-neighbor rendering for all character scales.
- Do keep system Chinese text and native keyboard interaction.
- Do give the user pause, hide and quit controls.
- Don't smooth sprite edges or blur the typing keyboard.
- Don't confuse an ungranted permission with a working event listener.
