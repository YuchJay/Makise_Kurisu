# Kurisu Desktop

<!-- impeccable:product-schema 1 -->

Current baseline: 2026-11-08, local 0.9.0 pending permission/live-input
acceptance. See [STATUS](STATUS.md) and [TRACKER](TRACKER.md).

## Platform

Native macOS desktop application.

## Stack

Swift, AppKit, SwiftUI, Core Graphics and ServiceManagement. The user approved
方案 B, the previously proposed native macOS implementation.

## Users and purpose

A personal desktop companion that remains available independently of Codex and
responds visually to typing, pointer activity, clicks, dragging and inactivity.

## Confirmed commitments

- Reuse the installed Kurisu character and preserve its pixel art.
- Deliver a local application with menu bar controls and optional login startup.
- Work in `/Users/gaokao/Desktop/kurisu`.
- Report progress by implementation stage.
- Process input timing locally; do not store typed content.

## Evidence

The installed pet has a 1536 × 1872 transparent sprite sheet: eight columns,
nine rows, with 192 × 208 cells. Frame counts are 6/8/8/4/5/8/6/6/6.
Original resources come from the user's Petdex installation.

## Current scope and interaction

Chinese controls; standard pet window 192 × 224 points; login startup is an opt-in.
Clicks play the original happy reaction and toggle utility tools; hover reveals
a nonactivating information card. Five utilities cover notes, shelf, clipboard
history, temporary wakefulness and rest reminders with approved character dialogue.

Typing uses the approved generated seated pose, anime outfit 02 and A6 face
polish, looking down at a red laptop behind a wooden desk. Whole-sprite scaling
keeps head sizes visually close to idle; approved pixel art remains authoritative.

The input app conservatively classifies key behavior without extracting text.
0.9.0 moves permission into a fixed independent input app, with automatic
reconnection after the user's macOS confirmation. System consent remains manual.

The former happy-plus-keyboard typing concept was an early implementation
assumption, superseded by the user's later approved artwork and interaction.
