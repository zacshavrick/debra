# Debra: architecture

## Targets
| Target | How | Notes |
|---|---|---|
| Windows | `builds/windows/Debra.exe` | A single file with the pck embedded. Just run it. |
| Mobile web | `builds/web/` (PWA) | Single-threaded wasm, so it needs no special server headers. Works on GitHub Pages. Players can "Add to Home Screen" for fullscreen landscape. |

Both targets come from **one Godot 4.7.2 project** in `game/`. The rules that keep it that way:
- **Renderer: Compatibility (GL ES 3 / WebGL 2).** No Forward+-only features (SSAO, SSR, SDFGI, volumetric fog, compute shaders).
- **Input goes through `PlayerInput` only.** Every action needs keyboard+mouse, gamepad and touch.
- **Scale with `Platform.is_low()`** (true on phones). It turns off shadows and reduces kelp and bubbles.
- Web export settings live in `game/export_presets.cfg`: no threads, PWA, landscape.

## Repo layout
```
CLAUDE.md               how Claude works in this repo
docs/                   DESIGN.md (spec) · ARCHITECTURE.md (this file) · screenshots/
projectContext/         handoffs from design chats (read-only history)
tools/                  setup-godot / test / screenshot / build (.ps1), serve-web.mjs
.github/workflows/      CI: test → exe + web artifacts → GitHub Pages → releases on v* tags
game/                   the Godot project (res://)
  project.godot, export_presets.cfg, icon.svg
  data/parts/*.tres       PartData: one file per part
  data/creatures/*.tres   CreatureData: loadout + behaviour + loot (Debra is one too)
  scenes/main.tscn        test arena (built in code by arena.gd)
  shaders/                seafloor, kelp
  scripts/
    core/       platform.gd (autoload Platform)
    input/      player_input.gd (autoload PlayerInput), touch_controls.gd
    parts/      PartData, PartInstance, Rarity, CreatureData, PartCatalog, Equipment, PartVisual
    crab/       CrabBody (shared rig), Crab (base), PlayerCrab, EnemyCrab
    combat/     CrabCombat (iteration #1), Health, BubbleShot, FX
    world/      Arena, PartPickup, FollowCamera
    ui/         HUD
  tests/        smoke_test (headless, CI), screenshot (renders docs/screenshots)
```

## The part system (the core)
```
PartData (.tres)  ──roll rarity──▶  PartInstance  ──equip──▶  Equipment (per socket)
                                                          │
                       stats ◀── Crab.apply_stats() ◀─────┤ changed(socket)
                       look  ◀── CrabBody.show_part() ◀───┘  (uses get_displayed → transmog-ready)
```
- **PartData** is pure data: slot, stats, `ability`, colours, procedural `shape` params, and an optional `visual_scene`.
- **PartInstance** is a PartData plus its rarity. Rarity multiplies positive stats.
- **Equipment** stores the *equipped* part (stats) and the *displayed* part (look) separately for each socket. That keeps transmog possible later.
- **CreatureData** holds a creature's loadout (what it wears), its AI numbers and its loot. Enemies drop from their own loadout plus `special_drops`.
- **PartCatalog** lists `data/` in a way that also works in exported builds (`*.tres.remap`).

### Rig contract (CrabBody)
One rig for every crustacean. Parts scale to fit the socket; the socket never changes for a part.
```
CrabBody (origin on the ground, forward = -Z, right = +X)
  Torso (y = 0.45)
    Core
    Socket_Head   (0, 0.08, -0.42)
    Socket_Shell  (0, 0, 0)
    Socket_ClawL  (-0.42, -0.02, -0.28)
    Socket_ClawR  ( 0.42, -0.02, -0.28)
    Socket_Legs   (0, 0.02, 0.05)
```
- A part's **origin is its attach point**, so it snaps to the socket with no offset math.
- Claws are authored for the **right** side and mirrored for the left.
- The moving pincer finger is a node named **`Jaw`**, opened by rotating around Y.
- Each leg is a node with meta `leg_index`. Feet reach the ground at `PartVisual.FOOT_Y` below the legs socket.
- Bigger or smaller creatures scale the whole `CrabBody` (`CreatureData.size`).

**Swapping in real art:** set `visual_scene` on a PartData to a `.glb`/`.tscn` that follows the contract above. Nothing else changes. The smoke test checks every part against every socket that accepts it.

## Combat lives apart from parts
Combat will be rebuilt 3–4 times. Everything combat-specific lives in `scripts/combat/`. The rest of the game reaches it only through:
- `CrabCombat.try_attack(side, dir)`, `is_ready()`, `attack_range()`
- `Crab.receive_hit(raw, from, knock, source)`
- `CrabBody.play_attack(socket, style, windup)`

To start iteration #2, write a new combat node with the same surface and swap it in `Crab._ready()`.

## Conventions
- GDScript with static typing. Use tabs. Use `class_name` for reusable classes. Values read from an untyped `Dictionary` or `Array` need an explicit type (`var x: float = d.k`).
- Keep scenes minimal and build complex things in code. Hand-written `.tscn`/`.tres` files are fine.
- Gameplay forward is −Z. The camera never rotates, so stick-up means −Z.
- Physics layers: 1 = world, 2 = crabs.
- Binary art (`.glb`, `.blend`, audio) goes through Git LFS (`.gitattributes`).

## Decision log
| Date | Decision | Why |
|---|---|---|
| 2026-10-19 | Godot 4.7.2, the same version as Slug Life | Toolchain and export templates already proven for exe + mobile web |
| 2026-10-19 | One project, Compatibility renderer | The only renderer that runs in mobile browsers |
| 2026-10-19 | Procedural placeholder parts driven by `.tres` data | 17 parts with no art cost. Real models drop in via `visual_scene` |
| 2026-10-19 | Creature = CreatureData; enemies wear their drops | "Every enemy is a parts catalogue" is built in, not bolted on |
| 2026-10-19 | Fixed top-down camera | The same controls work on touch, mouse and gamepad. Default only, see DESIGN open questions |
| 2026-10-19 | Mouse motion never switches the input scheme (clicks/keys do) | Stray pointer events in mobile browsers were hiding the touch controls |
