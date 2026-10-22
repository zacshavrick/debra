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
The `GameState` autoload owns the save file and the scene changes (`go_to_map`, `go_to_select`, `play_level`). The save (`user://debra_save.json`, version 2) holds **one slot per crab**: `{"current": id, "slots": {id: {loadout, cleared, bag, stash}}}`. The playing crab's slot lives in `_loadout`, `_cleared`, `bag` and `stash`, and the others wait in `_slots`. `choose_starter()` = continue (switch slots), `new_game()` = wipe that slot. Version-1 saves (shared progress) migrate into the crab that was being played.

## Repo layout
```
CLAUDE.md               how Claude works in this repo
docs/                   DESIGN.md (spec) · ARCHITECTURE.md (this file) · screenshots/
projectContext/         handoffs from design chats (read-only history)
tools/                  setup-godot / test / screenshot / build (.ps1), serve-web.mjs
.github/workflows/      CI: test → exe + web artifacts → GitHub Pages → releases on v* tags
game/                   the Godot project (res://)
  data/parts/*.tres       PartData: one file per part (113)
  data/creatures/*.tres   CreatureData: starters, enemies, hand-made bosses (46)
  data/levels/*.tres      LevelData: the 5 hand-made depths (deeper ones are generated)
  scenes/                 map.tscn (main), select.tscn, level.tscn (all built in code)
  shaders/                seafloor, kelp
  scripts/
    core/       platform.gd (Platform), game_state.gd (GameState: save + scene flow)
    input/      player_input.gd (PlayerInput), touch_controls.gd
    parts/      PartData, PartInstance, Rarity, Sets, CreatureData, PartCatalog, Equipment, PartVisual
    creatures/  Creature (base), Critter (non-crustaceans), CritterVisual, Loot
    crab/       CrabBody (shared rig), Crab, PlayerCrab, EnemyCrab
    combat/     CrabCombat, CritterAttack, ShellAbility, TailBrain, BossBrain, Mods, Melee, Health, BubbleShot, FX   ← combat iteration #1
    world/      Level, LevelData, LevelGenerator, LevelBuilder (biomes/layouts), Portal, PartPickup, FollowCamera
    ui/         HUD, Minimap, WorldMap, CrabSelect, InventoryUI
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
- **CreatureData.kind** picks the class: CRUSTACEAN → EnemyCrab, CRITTER → Critter (`Level.spawn_enemy`). `min_depth` gates where the generator may use it.
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
    Socket_Shell  (0, 0, 0)
    Socket_ClawL  (-0.42, -0.02, -0.28)
    Socket_ClawR  ( 0.42, -0.02, -0.28)
    Socket_Legs   (0, 0.02, 0.05)
    Socket_Tail   (0, -0.02, 0.36)   tails grow backwards (+Z); the moving part is a node named "Swing"
```
- A part's **origin is its attach point**. Claws are authored for the **right** side and mirrored for the left.
- The moving finger is a node named **`Jaw`**. It opens around Y by default, or around X when it has meta `open_axis = "x"` (bite jaws).
- Each leg is a node with meta `leg_index`. Feet reach the ground at `PartVisual.FOOT_Y` below the legs socket.
- Bigger or smaller creatures scale the whole `CrabBody` (`CreatureData.size`).

**Swapping in real art:** set `visual_scene` on a PartData (or later, a scene per critter `body_kind`). The smoke test checks every part against every socket that accepts it.

## Levels: hand-made + endless
- **`GameState.level_at_depth(d)`** returns the hand-made `.tres` for depths 1–5, and `LevelGenerator.generate(d)` for everything deeper. Generated ids are `depth_N`. Clearing depth N unlocks N + 1 (`frontier_depth()`).
- **`LevelData`** holds everything a level is:
  - theme: palette, fog, `decor` biome, `layout`
  - creatures, plus a `featured` one
  - `objective` + `objective_count`
  - `modifiers`
  - the boss (`boss`, `boss_name`, `boss_traits`, `boss_parts` = stolen parts per socket)
  - `difficulty`, `rarity_luck`, `depth`
- **`LevelGenerator`** is deterministic: the RNG is seeded from `"debra-depth-N"` and results are cached. It picks the biome (weighted toward newer ones), layout, 5–6 creatures with `min_depth ≤ depth` (at least 2 crustaceans), the objective, modifiers, and a chimera boss (a duplicated CreatureData, scaled up, with stolen parts and traits).
- **`LevelBuilder`** turns a LevelData into an arena: environment, a seafloor shader tinted per level, a wall ring and rock rim, biome decor (shells, kelp, coral, wreck, glow, vents, sargassum, ice, trench, whale bones), layout obstacles, and the home can. Decor is seeded from the level id, so a level looks the same every visit.
- **`Level`** runs the objective (cull / waves / hunt), applies modifiers at spawn time (`spawn_enemy(creature, pos, track, opts)`), makes champions, spawns the boss with a `BossBrain`, and opens a `Portal` when the boss dies.

## Bosses and tails (combat folder)
- **`BossBrain`** is a child node of the boss. It tracks where the player's hits come from (an EMA of range, standard vs close) and switches tactic between `rush` and `bristle`. It runs traits (summoner, enrage, slam, shell, splitter). It drives special moves with `Creature.lock_ai()` + `start_dash()`, and emits `announce` for HUD toasts.
- **`TailBrain`** is a child of every `Crab`. It reads the TAIL part's `ability` (flick, stab, zap, lure, spines, surge) and acts on timers or on `health.damaged`. Strength = tail power × base + 0.3 × ATK. It animates the tail's `Swing` node.

## Part levels
`PartInstance.level` (the depth it dropped at) multiplies bonuses by `1 + 0.12 × (level − 1)`, on top of rarity. `PartInstance.power()` = rarity × level is used for claw damage and tail strength. Saves store `{id, rarity, level}`; old saves without `level` load as level 1.

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
| 2026-10-19 | Endless depths are generated, deterministic per depth | Shareable ("depth 23"), no level files to maintain, cacheable |
| 2026-10-19 | Part levels (depth-scaled stats) | Enemy difficulty grows forever; without it player power plateaus at Epic |
| 2026-10-19 | 6th socket: Tail, driven by TailBrain (no player input) | Zac asked for a part that acts on its own; keeps claws as the player's buttons |
| 2026-10-19 | Bosses adapt to range vs close via BossBrain | Zac asked for bosses that change tactics depending on how you play them |
| 2026-10-19 | Boss death opens a Portal instead of a prompt | Zac: no prompt, leave whenever |
| 2026-10-19 | Mods reuse one hook set for parts and set perks | One implementation per effect; sets are just bundles of mods |
| 2026-10-19 | ~~Bag shared by all crabs~~ → 2026-10-20: each crab is its own save (gear, bag, stash, progress) | Zac: each crab is a separate game; NEW GAME restarts one |
| 2026-10-20 | `boss_pace` slows depth 1-3 bosses (x2 / x1.7 / x1.4 cooldowns) | Zac: early bosses killed new players too often |
| 2026-10-19 | Branching chart from a deterministic graph, not stored | Endless and shareable like the depths themselves |

## Milestone 4 systems
- **Tiers and mods.** `Rarity.Tier` runs Common to Gold. `PartInstance.roll()` is the one place drops get their tier, their mod (`Mods.roll_for`: a regular mod for Legendary, a gold-only one for Gold) and the Golden Debra swap. Boss and champion guarantees raise the tier with `set_tier()`, which re-rolls the mod for the new tier.
- **Mods** (`combat/mods.gd`) are data plus hooks. `Crab.apply_stats()` builds `active_mods` (part mods + set perks) and applies the stat multipliers, thorns, regen and knockback resistance. Combat effects run through `Creature._on_dealt_hit()` / `_on_killed()` (called from `receive_hit` and `_on_died` via `_last_hitter`) → `Mods.on_hit` / `on_kill`. Second wind is `Health.cheat_death`. Echo lives in `CrabCombat.try_attack`. Midas and Lucky live in `Loot`.
- **Sets** (`parts/sets.gd`): `PartData.set_id` (written by the data generator: one id per crustacean family). `Sets.progress/active/stat_mult/perks(equipment)`. A set counts when every piece is worn at its required tier (Epic, or Gold for Debra).
- **ShellAbility** (child of every Crab): reads the SHELL part's `ability` and implements dash, shield (`damage_taken_mult` + `Creature.reflecting`, which BubbleShot bounces off), cloak (`Creature.cloaked`; enemy AIs and BossBrain ignore cloaked players), shark_dash, spikes, roll, heal and quake. `PlayerCrab` calls `try_use()` on `PlayerInput.ability_pressed`.
- **Passive tails**: TailBrain handles timed and reactive tails; `Crab.apply_stats` sets `dodge_chance` and `regen` from the tail. Guard grants `guard_charges`. `Creature.receive_hit` checks dodge and guard before damage.
- **Bag and stash** live in `GameState.bag` / `GameState.stash` (`Array[PartInstance]`, saved as `{id, rarity, level, mod}`). `InventoryUI` is a pausing CanvasLayer. With a player it edits `player.equipment` through `PlayerCrab.equip_from_storage`; on the map it builds a temporary Equipment from the saved loadout and writes it back with `store_loadout`.
- **Branching chart**: `GameState.branch_count(d)`, `level_at(d, b)`, `parents(d, b)` (nearest parent + seeded cross-links; every node gets ≥1 parent and every parent ≥1 child), `is_unlocked` (any parent cleared), `frontier_depth()`. Generated ids are `depth_D_B`; old `depth_D` ids still resolve to branch 0. `LevelGenerator.generate(depth, branch)` seeds from both.
