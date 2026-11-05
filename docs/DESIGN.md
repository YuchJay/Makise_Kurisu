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

## Overview

The user chose pixel art. The character and typing keyboard use crisp square
pixels, while native macOS settings retain readable Chinese text and standard
controls. A cool blue setting surface separates the auburn character from
whatever desktop appears behind the transparent companion.

## Colors

The setting ground and sidebar form two flat regions. Dark ink carries headings,
muted ink carries explanations, and auburn marks the main permission action.
The keyboard uses its own dark ink, pale keycaps and warm active keys.

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
- Laptop: original idle head and body retain their natural orientation as one
  piece. Working eyes look down at the screen. The character sits behind an opaque wooden table. A plain red laptop back
  faces the viewer. Tiny round hands alternate at its sides; no screen UI or
  keyboard is exposed. Opening and closing use six frames, typing eight, waiting four.
- Computer playback: sit/open over 0.90 seconds; wait after 1.1 seconds of no keys;
  close/rise at 3.2 seconds with 0.96 second duration. Closing reverses on new input.
- Settings: native controls, labeled permission status and recoverable errors.
- Menu bar: monochrome pixel silhouette with accessible label.
- Motion: 12 render ticks per second; sprite frame intervals 0.18, 0.13 or
  0.085 seconds. User or system reduced motion freezes sprite frames.
- Rest: play source frames 0–4 once, hold seated frame 5, use frame 6 for an
  occasional nod. A 4.8-second breathing cycle moves the sprite one source
  pixel. Reduced motion shows seated frame 5 without the entrance or breathing.
- Drag: current horizontal movement chooses run-left or run-right.
- Input status: “监听已开启” does not claim a key has arrived; separate feedback
  confirms keyboard activity or explains secure input.
- Settings offers a permission-free laptop preview and displays the same frames
  as the companion during that sequence.

## Do's and Don'ts

- Do keep nearest-neighbor rendering for all character scales.
- Do keep system Chinese text and native keyboard interaction.
- Do give the user pause, hide and quit controls.
- Don't smooth sprite edges or blur the typing keyboard.
- Don't confuse an ungranted permission with a working event listener.
