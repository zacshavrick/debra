# Debra: guide for Claude

A 3D crustacean ARPG (pick a crab, pick a level on the map, kill things, wear them) in **Godot 4.7.2 (GDScript)**. It ships as a **Windows exe** and a **mobile web app**. Owner: Zac (`zacshavrick`). Claude is the project architect.

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
- **Parts, creatures and levels are data** (`game/data/parts|creatures|levels/*.tres`). Don't hard-code lists of them.
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
- Milestone 1 is done: the shared rig, drops with rarity, equip, combat iteration #1, exe + web exports, and CI.
- Milestone 2 is done: 5 starters (Debra the Lobster, Saul the Crab, Louise the Shrimp, plus Claude's picks Marjorie the Hermit Crab and Gary the Spider Crab), crab select, world map, 5 levels with bosses and unlocks, 21 creature types (10 non-crustaceans with their own bodies), 75 parts, 7 claw styles, poison, a saved game, and a minimap.
- Milestone 3 is done: the endless dive. Depths 6+ come from `LevelGenerator` (deterministic per depth): biomes, layouts, featured creatures, objectives (cull/waves/hunt), modifiers, and chimera bosses with traits. Every boss adapts to range vs close play (`BossBrain`). A portal opens when the boss dies. Part levels scale stats with depth. A 6th Tail socket acts on its own (`TailBrain`). 36 creature types, 113 parts, glowing attack effects with ground telegraphs.
- **Content is data.** A new creature is a `.tres` in `data/creatures/`. Give it a `min_depth` and the generator picks it up. A non-crustacean also needs a `body_kind` in `CritterVisual` (bodies animate generically via named nodes).
- Milestone 4 is done: Legendary + Gold tiers with mods (`Mods`), set bonuses (`Sets`; Gold Debra = Headliner), shell spacebar abilities (`ShellAbility`), passive tails, bag + stash + `InventoryUI`, loot bubbles that vanish after 20 s, a branching map, and dev skip (`GameState.dev_mode`, F5, SKIP).
- 2026-10-20: each crab is its own saved game (`GameState` slots: CONTINUE / NEW GAME on crab select), and depth 1-3 bosses are paced slower (`Level.early_boss_pace`, `Creature.boss_pace`).
- 2026-10-23: each starter has its own movement move (`MoveAbility`, Space / A / MOVE; cooldowns 0.9 s, Louise 0.6 s; Gary jumps ~24 m over everything; shell abilities moved to C / B, the basic dash became Harden): Gary jump, Saul zigzag scuttle RRLL, Debra lunge, Marjorie arc, Louise shimmy FFBF. Fixed per crab for now (tail-linked movement is Open). Title screen backdrop + creature parade; swaying `Props` in levels.
- Not verified yet: touch input on a real phone, and balance deep into the dive (past ~depth 30). The smoke test takes about 9 minutes.
- Next candidates are in DESIGN.md → "Milestones".
