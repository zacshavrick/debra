# Debra: architecture

## Targets
| Target | How | Notes |
|---|---|---|
| Windows | `builds/windows/Debra.exe` | A single file with the pck embedded. Just run it. |
| Mobile web | `builds/web/` (PWA) | Single-threaded wasm, so it needs no special server headers. Works on GitHub Pages. Players can "Add to Home Screen" for fullscreen landscape. |

Both targets come from **one Godot 4.7.2 project** in `game/`. The rules that keep it that way:
- **Renderer: Compatibility (GL ES 3 / WebGL 2).** No Forward+-only features (SSAO, SSR, SDFGI, volumetric fog, compute shaders).
- **Input goes through `PlayerInput` only.** Every action needs keyboard+mouse, gamepad and touch.
- **Scale with `Platform.is_low()`** (true on phones). It turns off shadows and reduces decor and bubbles.
- Web export settings live in `game/export_presets.cfg`: no threads, PWA, landscape. The PWA service worker caches builds, so unregister it when testing a new build locally.

## Scene flow
```
map.tscn (main) ──DIVE──▶ level.tscn ──MAP / Esc / Start──▶ map.tscn
   │  └─ no crab picked yet ──▶ select.tscn ──PLAY──▶ map.tscn
   └─ HOME / Change crab ─────▶ select.tscn
```
The `GameState` autoload owns the save file (`user://debra_save.json`: chosen crab, per-crab loadouts, cleared levels) and the scene changes (`go_to_map`, `go_to_select`, `play_level`).

## Repo layout
```
CLAUDE.md               how Claude works in this repo
docs/                   DESIGN.md (spec) · ARCHITECTURE.md (this file) · screenshots/
projectContext/         handoffs from design chats (read-only history)
tools/                  setup-godot / test / screenshot / build (.ps1), serve-web.mjs
.github/workflows/      CI: test → exe + web artifacts → GitHub Pages → releases on v* tags
game/                   the Godot project (res://)
  data/parts/*.tres       PartData: one file per part (75)
  data/creatures/*.tres   CreatureData: starters, enemies, bosses (30)
  data/levels/*.tres      LevelData: one per level (5)
  scenes/                 map.tscn (main), select.tscn, level.tscn (all built in code)
  shaders/                seafloor, kelp
  scripts/
    core/       platform.gd (Platform), game_state.gd (GameState: save + scene flow)
    input/      player_input.gd (PlayerInput), touch_controls.gd
    parts/      PartData, PartInstance, Rarity, CreatureData, PartCatalog, Equipment, PartVisual
    creatures/  Creature (base), Critter (non-crustaceans), CritterVisual, Loot
    crab/       CrabBody (shared rig), Crab, PlayerCrab, EnemyCrab
    combat/     CrabCombat, CritterAttack, Melee, Health, BubbleShot, FX   ← combat iteration #1
    world/      Level, LevelData, LevelBuilder (themes/decor), PartPickup, FollowCamera
    ui/         HUD, Minimap, WorldMap, CrabSelect
  tests/        smoke_test (headless, CI), screenshot (renders docs/screenshots)
```

## Creatures
```
Creature (CharacterBody3D, group "creatures")  health, movement + knockback, poison, death, receive_hit()
├── Crab          shared CrabBody rig + Equipment + CrabCombat (claws)
│   ├── PlayerCrab    PlayerInput, pickups/equip, respawn, saves its loadout
│   └── EnemyCrab     wander/chase/attack brain, wears its loadout
└── Critter       CritterVisual body + one CritterAttack + a behaviour
                  (melee, ranged, charger, drifter, turret, ambusher)
```
- **CreatureData.kind** picks the class: CRUSTACEAN → EnemyCrab, CRITTER → Critter (`Level.spawn_enemy`).
- **Loot** is the same for both: crustaceans drop from their loadout plus `drops`/`special_drops`; critters drop only from `drops`. Bosses drop 2.
- **Level difficulty** multiplies enemy HP and damage. Level `rarity_luck` is added to every drop.

## The part system (the core)
```
PartData (.tres)  ──roll rarity──▶  PartInstance  ──equip──▶  Equipment (per socket)
                                                          │
                       stats ◀── Crab.apply_stats() ◀─────┤ changed(socket)
                       look  ◀── CrabBody.show_part() ◀───┘  (uses get_displayed → transmog-ready)
```
- **PartData** is pure data: slot, stats, `ability`, colours, procedural `shape` params, and an optional `visual_scene`.
- **PartInstance** is a PartData plus its rarity. It serialises as `{id, rarity}` in the save.
- **Equipment** stores the *equipped* part (stats) and the *displayed* part (look) separately for each socket.
- **PartCatalog** lists `data/` in a way that also works in exported builds (`*.tres.remap`).

### Rig contract (CrabBody)
One rig for every crustacean. Parts scale to fit the socket; the socket never changes for a part.
```
CrabBody (origin on the ground, forward = -Z, right = +X)
  Torso (y = 0.45)
    Core
    Socket_Head   (0, 0.08, -0.42)
    Socket_Shell  (0, 0, 0)          lobster/shrimp tails are part of the shell
    Socket_ClawL  (-0.42, -0.02, -0.28)
    Socket_ClawR  ( 0.42, -0.02, -0.28)
    Socket_Legs   (0, 0.02, 0.05)
```
- A part's **origin is its attach point**. Claws are authored for the **right** side and mirrored for the left.
- The moving finger is a node named **`Jaw`**. It opens around Y by default, or around X when it has meta `open_axis = "x"` (bite jaws).
- Each leg is a node with meta `leg_index`. Feet reach the ground at `PartVisual.FOOT_Y` below the legs socket.
- Bigger or smaller creatures scale the whole `CrabBody` (`CreatureData.size`).

**Swapping in real art:** set `visual_scene` on a PartData (or later, a scene per critter `body_kind`). The smoke test checks every part against every socket that accepts it.

## Levels
`LevelData` holds the theme (colours, fog, decor set), the creature list, `kill_goal`, `boss`, `difficulty` and `rarity_luck`. `LevelBuilder` turns it into an arena: environment, a seafloor shader tinted per level, a wall ring and rock rim, themed decor (shells, kelp, coral, wreck, glowing abyss), and the home can. Decor is seeded from the level id, so a level looks the same every visit.

## Combat lives apart from parts
Combat will be rebuilt 3–4 times. Everything combat-specific lives in `scripts/combat/`. The rest of the game reaches it only through:
- `CrabCombat.try_attack(side, dir)`, `is_ready()`, `attack_range()`
- `Critter` → `CritterAttack.telegraph()` / `perform()`
- `Creature.receive_hit(raw, from, knock, source)`, `Creature.poison(dps, sec)`
- `CrabBody.play_attack(socket, style, windup)`

## Conventions
- GDScript with static typing. Use tabs. Use `class_name` for reusable classes. Values read from an untyped `Dictionary` or `Array` need an explicit type (`var x: float = d.k`).
- Keep scenes minimal and build complex things in code. Hand-written `.tscn`/`.tres` files are fine.
- Gameplay forward is −Z. The camera never rotates, so stick-up means −Z. Home sits at the north (−Z) edge.
- Physics layers: 1 = world, 2 = creatures. Hit checks are 2D (xz), so hovering critters (fish, jellies) still get hit.
- Binary art (`.glb`, `.blend`, audio) goes through Git LFS (`.gitattributes`).

## Decision log
| Date | Decision | Why |
|---|---|---|
| 2026-10-19 | Godot 4.7.2, the same version as Slug Life | Toolchain and export templates already proven for exe + mobile web |
| 2026-10-19 | One project, Compatibility renderer | The only renderer that runs in mobile browsers |
| 2026-10-19 | Procedural placeholder parts driven by `.tres` data | Lots of parts with no art cost. Real models drop in via `visual_scene` |
| 2026-10-19 | Creature = CreatureData; enemies wear their drops | "Every enemy is a parts catalogue" is built in |
| 2026-10-19 | Fixed top-down camera | The same controls work on touch, mouse and gamepad |
| 2026-10-19 | Mouse motion never switches the input scheme (clicks/keys do) | Stray pointer events in mobile browsers were hiding the touch controls |
| 2026-10-19 | `Creature` base split from `Crab`; non-crustaceans are `Critter` | Non-crustaceans need their own bodies but the same hit/health/loot rules |
| 2026-10-19 | Levels are data (`LevelData`); the map is a depth chart | Adding a level = one `.tres`. Deeper = harder + better loot reads at a glance |
| 2026-10-19 | Saves are JSON in `user://` | Works on desktop and in browsers (IndexedDB) |
