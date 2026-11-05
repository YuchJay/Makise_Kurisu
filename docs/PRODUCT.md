# Kurisu Desktop

<!-- impeccable:product-schema 1 -->

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

## Implementation assumptions

Chinese controls; initial size 192 × 224 points; login startup is an opt-in.
The existing happy animation plus a pixel keyboard represents typing.
The first release does not invent new character poses.
