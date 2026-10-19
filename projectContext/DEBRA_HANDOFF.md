# Debra – Agent Handoff

Oct 19, 2026 · Zac

## How to use this handoff

This is the full context for picking up **Debra**, a 3D crustacean ARPG, after one concept conversation with Zac on Oct 19, 2026. Nothing has been built yet; the next step is the first Godot prototype.

- **Decided** = Zac said it or explicitly agreed. Treat as the current design.
- **Suggested** = an assistant recommendation Zac has not confirmed. Treat as a starting point, open to change.
- The companion **Debra – Design Doc** holds the clean spec. Save it in the project as `DESIGN.md` and point to it from `CLAUDE.md`. This handoff adds the history and reasoning behind it.

## Project snapshot

| Item | Value |
| --- | --- |
| Title | Debra (spelled D-E-B-R-A; an earlier "Deborah" spelling was corrected) |
| Genre | 3D action RPG, loot-driven |
| Pitch | You play a little crustacean on the seafloor. Every kill drops a body part; equipping it changes your stats, abilities and look. You are what you kill. |
| Engine | Godot (Unreal was mentioned as an alternative) |
| Status | Concept stage. Design doc written. No code yet. |
| Next milestone | First Godot prototype: Debra, a test arena, the socket system, part drops |

## Decision log

In conversation order. "Source" says who originated the idea.

| # | Topic | Outcome | Source | Reasoning / notes |
| --- | --- | --- | --- | --- |
| 1 | Core concept | Crustacean ARPG; kills drop body parts with rarities; parts change stats, abilities and looks | Zac | The mutation is the hook. Assistant flagged rigging and attachment as the biggest cost. |
| 2 | Name | Debra | Zac | First spelled Deborah, corrected to D-E-B-R-A. |
| 3 | Debra's role | Headliner and first character; other crabs also playable | Zac | Name is a deliberate non sequitur. |
| 4 | Identity | No dialogue; nothing makes Debra special; losing your original look is intended | Zac | Assistant had asked about a signature trait; Zac declined. |
| 5 | Transmog | Keep a part's stats, show another's look | Zac |  |
| 6 | Transmog timing | Unlocks late game | Assistant suggested, Zac agreed | Stops transmog from hiding the mutation hook early. |
| 7 | Roster | Starter crabs and enemies are similar creatures | Zac | Every enemy doubles as a parts catalogue. |
| 8 | Sockets | Fixed attachment points are critical | Zac + assistant | Assistant proposed one shared skeleton; parts scale to the socket. |
| 9 | Non-crustaceans | Only crustaceans are playable with a fixed shape; starfish, eel, shark, jellyfish drop 1–2 parts for limited slots | Zac | Crustacean drops = bread and butter; exotic drops = wildcards. |
| 10 | Exotic parts | Designed later | Zac | Declined to brainstorm them now. |
| 11 | Rarity | RNG; special items drop only from specific creatures | Zac |  |
| 12 | Home | Buildable home (seashell, Coke can) you head out from; long progression | Zac | Assistant suggested home over town for scope; Zac did not reject it. Town stays a possible later idea. |
| 13 | Home functions | Storage yes; crafting shelved | Zac | Zac first said both, then dropped crafting. |
| 14 | Combat | Prototype 3–4 iterations, keep what works | Zac | Assistant: each must make part swaps change how you fight. |
| 15 | Prototype platform | Start directly in Godot | Zac | Assistant first suggested a web prototype; Zac pushed back since they've built Godot games together with direct file access. |
| 16 | Cross-chat workflow | Handoff via design doc in project (`DESIGN.md` + `CLAUDE.md`) | Zac asked, assistant proposed | Chats and Claude Code don't share conversations. |

## Current spec

The core loop: leave home, fight seafloor creatures, take their parts, equip and mutate, return to store spares.

**Characters**

- Several playable starter crustaceans; Debra is the headliner.
- Creatures don't talk. No story identity is protected.

**Body parts**

- Slots named so far: head, carapace / shell / exoskeleton, body, arms (claws), legs.
- Each part has its own stats, its own abilities and its own look.
- All playable crustaceans share one fixed body shape with fixed sockets.
- Crustacean enemies can drop any of their parts. Non-crustaceans drop only 1–2 parts that fit limited slots.
- Rarity is random. Special items come only from specific creatures.
- Transmog unlocks late, so early players are forced to look mutated.

**Enemies**

- Mostly small crustaceans, plus sea creatures such as starfish, eels, sharks and jellyfish.

**Home and progression**

- A long progression arc.
- A home in found objects (a seashell or a Coke can) with storage.
- No crafting for now; a sea town is a maybe for later.

**Combat**

- Undecided by design. Prototype 3–4 versions and compare.

## Open questions

None of these are decided. Ask Zac before committing to an answer that is hard to undo.

- [ ] How many arm and leg sockets does the shared body have, and are left and right separate slots?
- [ ] Is "body" a separate slot from carapace/shell, or the same thing?
- [ ] Which slots each non-crustacean can fill (e.g. shark jaw → head only?).
- [ ] Rarity tiers: how many, their names, and how rarity scales stats.
- [ ] What a part's "ability" is mechanically: active skill, passive, or attack change.
- [ ] How many starter crustaceans, and how they differ at the start.
- [ ] Camera and control scheme (isometric ARPG vs third-person).
- [ ] World structure: open seafloor, zones, or runs from home.
- [ ] Home upgrades: what makes the home grow over the long progression.
- [ ] Art style and target platform.

**Explicitly deferred:** exotic part designs, crafting, sea town.

## Technical approach (suggested)

The socket system is the riskiest part, so build it first and keep it data-driven. Everything here is an assistant suggestion, not a Zac decision.

**Shared body with sockets**

- One crustacean rig (`CrabBody` scene) with named `Marker3D` or `BoneAttachment3D` nodes per slot: `Socket_Head`, `Socket_Shell`, `Socket_ArmL`, `Socket_ArmR`, `Socket_Leg_*`.
- Each part is its own scene with an origin at its attach point, so it snaps to the socket with no offset math.
- Parts scale to fit the socket, not the other way round.

**Data**

- A `PartData` Resource: id, display name, slot, rarity, stats, ability reference, mesh scene, allowed source creatures.
- A `LootTable` Resource per creature: which parts it can drop and their weights.
- Rarity rolled at drop time.

**Suggested structure**

```
res://
  characters/crab_body.tscn   # shared rig + sockets
  parts/<slot>/<part>.tscn     # one scene per part
  data/parts/*.tres            # PartData
  data/loot/*.tres             # LootTable
  scenes/test_arena.tscn
  scripts/equipment.gd         # equips PartData onto sockets, sums stats
```

**Things to keep in mind**

- Keep transmog possible later: store "equipped part" and "displayed part" separately from day one.
- Combat will be rebuilt 3–4 times, so keep it in its own scripts, away from the part system.

## Working with Zac

Zac wants blunt, honest feedback on ideas, not cheerleading. Push back when something risks scope or the core hook.

- Zac designs by talking, often in voice, and decides quickly. Confirm what's decided before building on it.
- Zac has built several games with Claude before, including in Godot with direct project-file access. Don't default to web prototypes for this one.
- Workflow: design in chat, build in Claude Code. Keep `DESIGN.md` in the project as the single source of truth and update it when design changes.
- Zac prefers small scope first: he shelved crafting and exotic parts rather than overloading the first version.

## Next steps

The first prototype is done when a part dropped by a killed crab visibly snaps onto Debra and changes her stats.

1. Set up the Godot project; add `DESIGN.md` and a `CLAUDE.md` that points to it.
2. Build Debra from placeholder shapes on the shared rig, with every socket in place.
3. Make a small seafloor test arena with a basic camera and movement.
4. Write `PartData` and `LootTable`, plus 2–3 placeholder parts per slot across a few rarities.
5. Add 2–3 enemy crabs that fight back and drop parts on death.
6. Pick up and equip parts: the mesh snaps to its socket and stats update on screen.
7. Add simple placeholder combat as combat iteration #1.

**Done when**

- [ ] Every slot accepts any crustacean part with no visible misalignment.
- [ ] Killing an enemy drops a part with a rolled rarity.
- [ ] Equipping a part changes both appearance and a visible stat.
- [ ] Swapping arms changes how an attack feels or works.
