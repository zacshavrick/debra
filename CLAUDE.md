# Debra: guide for Claude

A 3D crustacean ARPG in **Godot 4.7.2 (GDScript)**. It ships as a **Windows exe** and a **mobile web app**. Owner: Zac (`zacshavrick`). Claude is the project architect.

**Read first:** `docs/DESIGN.md` (the design; single source of truth) and `docs/ARCHITECTURE.md` (targets, part system, rig contract, decision log). Background: `projectContext/DEBRA_HANDOFF.md`.

## Commands (PowerShell, from repo root)
```
powershell -ExecutionPolicy Bypass -File tools/setup-godot.ps1   # once per machine: Godot + export templates into .tools/
powershell -ExecutionPolicy Bypass -File tools/test.ps1          # headless smoke test (exit 0 = pass)
powershell -ExecutionPolicy Bypass -File tools/screenshot.ps1    # docs/screenshots/*.png (opens a window)
powershell -ExecutionPolicy Bypass -File tools/build.ps1         # builds/windows/Debra.exe + builds/web/
node tools/serve-web.mjs                                         # play the web build at http://localhost:8060
```
To run Godot directly: `.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path game ...`. Always pass `--quit-after N` to headless runs.

## Rules
- **The design lives in `docs/DESIGN.md`.** When Zac decides something in chat, update it. Mark items **Decided**, **Default** (Claude's pick) or **Open**. Ask before committing to an Open item that's hard to undo.
- **Renderer is Compatibility.** No Forward+-only features, because they break the web build.
- **Only `PlayerInput` reads input devices.** Every new action needs keyboard+mouse, gamepad **and touch**.
- Heavy content scales with `Platform.is_low()` (phones).
- **Parts are data.** Add a part by adding a `.tres` in `game/data/parts/`. Add a creature with a `.tres` in `game/data/creatures/`. Don't hard-code part lists.
- **Respect the rig contract** (ARCHITECTURE.md). Parts snap to sockets with zero offset.
- **Keep combat in `scripts/combat/`.** It will be rebuilt 3–4 times. Don't let part code depend on combat details.
- Keep transmog possible: look comes from `Equipment.get_displayed()`, stats from `get_part()`.
- GDScript with static typing and tabs. Values from untyped `Dictionary`/`Array` need explicit types.
- After gameplay or visual changes, run `tools/test.ps1`, then `tools/screenshot.ps1`, and **look at the screenshots** before saying it works. Extend `tests/smoke_test.gd` when behaviour changes.
- After web-facing changes, run `tools/build.ps1 -Target web` and check it in a browser. The PWA service worker caches old builds, so unregister it or hard-reload.

## Working with Zac
- Zac wants blunt, honest feedback, not cheerleading. Push back when something risks scope or the core hook ("you are what you kill").
- Zac designs by talking, often by voice, and decides fast. Confirm what was decided before building on it.
- Small scope first. Crafting, exotic parts and the sea town are deliberately shelved.
- Bias to action: pick reasonable defaults, say which ones you picked, and keep going.

## Status (2026-10-19)
- Prototype milestone 1 is done: the shared rig with 5 sockets, 17 placeholder parts, Debra + 3 enemy types, drops with rolled rarity, equip with stat comparison, combat iteration #1 (pinch / crush / snap), the home can (respawn + heal), the HUD, touch controls, exe + web exports, and CI.
- Not verified yet: touch input on a real phone (detection and drawing are checked; real finger input isn't).
- Next candidates are in DESIGN.md → "Prototype milestone 1: status".
