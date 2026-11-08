# Kurisu Desktop

Native macOS pixel companion. Requires an Apple Silicon Mac running macOS 13+
and Command Line Tools for rebuilding.

Current version: **0.9.0**. Input monitoring now lives in a separate, fixed-path
app that ordinary companion builds reuse. First-time permission is guided from
one action, with automatic connection after the system confirmation.
See [the release notes](docs/releases/0.9.0-更新说明.md).

## Project tracking

The 0.9.0 implementation and tracking documents were pushed as `b8a57a0`.
First-permission and live-input acceptance remain pending.
See the [documentation index](docs/README.md), [current status](docs/STATUS.md),
[task tracker](docs/TRACKER.md) and [acceptance plan](docs/ACCEPTANCE.md).

## Build and launch

```sh
zsh scripts/build.sh
open outputs/Kurisu.app
```

The app is self contained after building. It does not need Python, Node,
Petdex, Codex, a terminal or an internet connection to run.

## Controls

- Drag the character to move it. Click to play the happy reaction and toggle
  the native utility panel.
- Right click the character or use the menu bar icon for settings and quit.
- Enable input monitoring from settings to react to typing, clicks and scrolls.
- Two character-key presses within 0.8 seconds make her sit behind a small table
  and open a laptop. Cmd/Ctrl/Option/Fn/Help combinations, navigation, function
  keys and Tab do not trigger typing. Shift and Caps Lock are allowed.
  Typing uses the approved anime-reference outfit 02, with a white shirt,
  red tie and muted light-brown jacket. The red lid's back faces the viewer.
  Rapid input raises the cadence.
- Short pauses keep the laptop open. At 3.2 seconds after the last key she
  closes and stows it. Typing during closing reverses that transition.
- “预览坐下打字” in settings (also in the pose menu) previews the full
  sequence without needing input permission.
- Mouse proximity works without input permission.
- After 90 seconds without observed keyboard/pointer activity, the pet sits down
  once, then breathes gently and occasionally lowers her head while seated.
- Typing and seated rest are scaled uniformly to keep the head close to the
  ordinary idle head size; the window-size preference remains the overall size.
- Dragging left/right uses the corresponding running direction; reversing a
  drag changes direction immediately.
- Pause stops the input listener. Hide removes the pet while keeping menu controls.
- Size, position and behavior settings are saved locally.
- Login startup is optional and controlled by macOS.

Input handling classifies virtual key positions, modifier flags, repeat status
and timing in memory. Only currently held/suppressed key codes and short timing
state are retained temporarily; no input text, key sequences or event logs are
extracted or persisted. Aggregate event counters track general activity only,
and never trigger typing when detailed callbacks are unavailable.

A single held key cannot start typing through auto-repeat. Space, Return and
deletion can continue an established typing sequence but cannot start one.
Shortcuts interrupt typing immediately; a key held through a shortcut must be
released before reuse. Mouse clicks and scrolling also clear typing confirmation.
Fresh typing has priority over transient wave/mouse feedback. During secure input
the app suspends keyboard responses and clears classification state.

This is conservative key-behavior classification, not confirmation that the
foreground app inserted text. It does not inspect focused text fields or request
additional accessibility access. Game/control letter sequences may still look
like typing, and very slow isolated characters may not start the animation.

Settings distinguish enabling the listener from actually receiving a key.
“重新连接” restarts only the input app and reconnects automatically.

## Input permission and stable updates

1. Open Settings and click **“我授权，开启打字响应”**.
2. Allow **“Kurisu 输入监听”** in macOS Input Monitoring.
3. Return to the companion; it reconnects automatically.

The authorized app is `KurisuInputAgent.app`, installed under
`~/Library/Application Support/KurisuDesktop/InputAgent/`. It is launched
independently through Launch Services and retains its own bundle identifier
`local.kurisu.inputagent`. Permission previously granted to the companion itself
does not migrate; this release needs one first confirmation for the input app.

`scripts/build_input_agent.sh` fingerprints input-app sources, its Info.plist,
the shared protocol and its own build instructions. If those inputs are unchanged
and the bundled signature is valid, it preserves the existing signed input app
byte for byte. Companion source, artwork, utility and version changes do not
trigger an input-app rebuild. Installation also reuses a matching authorized
copy without rewriting it. Source changes to the input component itself, a fresh
build producing a different binary, system resets or reinstalling that component
may still require permission again.

The main app does not open an event tap. A random session name and token protect
local CFMessagePort communication; replies contain classified activity only,
never input text or key codes. Installation checks the code signature and
executable hash. The helper stops its event tap on pause, session loss or display
sleep; if the owner's heartbeat stops it stops listening after three seconds and
exits after thirty seconds (or immediately when the owner exits).

The system confirmation cannot be performed by the app. If macOS does not list
the input app automatically, expand “系统列表里没有出现？” and use its reveal
button to add that fixed app once. There is no automated System Settings clicking,
TCC database editing or permission reset. See [the architecture note](docs/INPUT_AGENT.md).

## Packaging

The companion and input app are locally ad hoc signed, not notarized for
distribution. Keep `outputs/Kurisu.app` in a stable location for login startup.
When startup says “等待系统批准”, allow it in macOS Login Items.

The current typing artwork uses approved anime outfit 02 with the user-approved
A6 cheek/chin pixel polish, 16 typing steps and 12-step entry/wait/exit sequences.
Version 0.8.4 applies a 5% size increase directly from that source. Rest and
happy reactions have separate head-size-normalized strips; the original
character sheet is preserved.
Rebuilding uses the bundled assets. Asset regeneration uses Pillow:
`scripts/prepare_laptop_assets.py` prepares typing/rest, and
`scripts/prepare_click_assets.py` prepares happy reactions.
See `outputs/Kurisu-laptop-preview.gif`, `outputs/Kurisu-click-preview.gif`
and `outputs/Kurisu-typing-size-comparison.png` after regenerating assets.

## Utility panel (0.8.0)

Click the pet to play its happy reaction and toggle the utility panel, or select
“随手工具…” from its menu. The reaction's head size matches ordinary idle.
Hover for about 0.45 seconds
to show a nonactivating information card beside the pet. It shows the latest
note (up to two lines), shelf and clipboard counts, and rest/awake status.
Buttons open the corresponding tools. Clipboard contents are not shown on hover.
The pointer can move into the card; leaving both pet and card dismisses it after
a short grace period. Dragging, clicking the pet, hiding, screen lock and speech
bubbles dismiss or suppress the hover card. The panel contains four tabs:

- 便签: create, edit, copy and delete local notes; Command-Return saves a new note.
- 暂存: drop files/folders, links or text onto the pet/panel, or add them using
  the visible controls. Files are copied into managed storage, so originals
  remain independent. Copy, drag out, open, reveal or remove the stored copy.
- 剪贴板: up to 40 recent text, file-reference or image entries for the current
  run; image payloads are bounded to 32 MB in total. Search, copy back, save to
  the shelf or delete entries. Recording can be paused, and the list cleared.
  Secure-input mode and standard confidential/transient markers are skipped;
  unmarked sensitive text is not automatically classified.
- 专注: keep the system awake for 15/30/60/120 minutes, optionally keep the
  display awake too, or stop early. The assertion expires or is released on exit.
  Explicit sleep and closing the laptop are not overridden.

Rest reminders estimate interactive screen usage while the application is running.
The default interval is 50 minutes with a 2-minute break, both configurable.
Locking, sleep, display sleep and idle time are excluded. Static reading/video
without input can be undercounted after two minutes. This is not an import from
macOS Screen Time. Sufficient idle time resets the continuous session; a reminder
offers a timed break or a five-minute snooze. Today’s estimate persists locally.

Contextual Chinese speech bubbles use locally authored randomized lines;
passive clipboard capture is throttled to one bubble per 45 seconds.
Rest bubbles remain actionable until dismissed or handled. Regular feedback
auto-dismisses without taking keyboard focus. Speech is text only, with no network.

Notes, shelf metadata, and usage totals are stored in
`~/Library/Application Support/KurisuDesktop/utilities.json`. Managed file copies
are under its `Shelf/` folder. Clipboard history is in memory only and is not
persisted. The utility panel works independently of input-monitoring permission.
No new automated tests were added or run for this release.

## Source

- `KurisuDesktop/Sources/`: window, animation, event monitor, settings and menu.
- `KurisuDesktop/InputAgent/`: independent input app and typing filter.
- `KurisuDesktop/Shared/`: versioned classified-activity IPC schema.
- `KurisuDesktop/Resources/`: bundled artwork.
- `assets/source/`: approved model image, final pixel sprite, and provenance.
- `scripts/build.sh`: reproducible native build, no package dependencies.
- `scripts/build_input_agent.sh`: preserves an unchanged signed input app.
- `scripts/prepare_laptop_assets.py`: regenerates typing/rest atlases and previews.
- `scripts/prepare_click_assets.py`: regenerates the click-reaction atlas and previews.
- `scripts/prepare_assets.py`: optional original-sheet/icon preparation.
- `docs/ASSETS.md`: source and transformation notes.
- `docs/`: design notes, product decisions, progress and release documentation.
- `outputs/`: locally built app and previews; ignored by Git.
- `work/`: local scratch files and archived experiments; ignored by Git.

### Optional asset regeneration

Building the app uses the committed resources and only requires Command Line
Tools. Python and Pillow are only needed when changing or regenerating artwork:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-assets.txt
.venv/bin/python scripts/prepare_laptop_assets.py
.venv/bin/python scripts/prepare_click_assets.py
zsh scripts/build.sh
```

The pipeline reads the approved input images from `assets/source/`, so it works
without the author's Petdex installation, discarded previews, or API access.
To explicitly reimport an original Petdex sheet:

```sh
.venv/bin/python scripts/prepare_assets.py --source /path/to/spritesheet.webp
```

Build output, Python/Swift caches, generation trials, logs, credentials, local
configuration and runtime user data are excluded by `.gitignore`.
