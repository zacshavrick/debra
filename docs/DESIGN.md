# Debra: design doc

**Single source of truth for the design.** Update it when the design changes. History and reasoning: [`projectContext/DEBRA_HANDOFF.md`](../projectContext/DEBRA_HANDOFF.md).

Labels used below:
- **Decided**: Zac said it or explicitly agreed to it.
- **Default**: Claude picked it to get the game running. It is not decided. Change it freely.
- **Open**: nobody has picked yet. Ask Zac before committing to anything that's hard to undo.

## Pitch (Decided)
You play a little crustacean on the seafloor. Every kill drops a body part. Equipping a part changes your stats, your abilities and your look. **You are what you kill.**

- 3D action RPG, loot-driven. Title: **Debra** (D-E-B-R-A).
- Engine: **Godot**. Targets: **Windows exe** and **mobile web app**.
- **No plot. Drop in and play.**

## Core loop
Pick a crab → pick a depth on the map → do the objective → beat the boss → walk through the portal whenever you're done looting → go deeper. Parts from deeper levels are stronger, so diving deeper always pays off.

## Starter crustaceans
| Crab | Status | Plays like | Tail |
|---|---|---|---|
| **Debra the Lobster** (headliner) | Decided | Crusher + cutter claws | Fan tail: flick |
| **Saul the Crab** | Decided | Two pincers, balanced | Tucked (does nothing) |
| **Louise the Shrimp** | Decided | Two fast snippers, very fast, fragile | Fan tail: flick |
| **Marjorie the Hermit Crab** | Default | Conch shell, one crusher, slow tank | Tucked |
| **Gary the Spider Crab** | Default | Long lash arms, very long legs | Tucked |

### Movement moves (Space / gamepad A / MOVE)
Each starter has its own movement move (Decided: the moves, Space to use them, cooldowns cut by 70% on 2026-10-23). Charges refill one at a time, each taking its cooldown.

| Crab | Move | Charges | Cooldown | What it does |
|---|---|---|---|---|
| Gary | Long Jump | 1 | 0.9 s | A big jump (~24 m, stops at the arena edge) over creatures, rocks and coral; untouchable in the air |
| Saul | Scuttle | 3 | 0.9 s | Zigzag dash: diagonally forward, pattern **Right, Right, Left, Left**, repeating |
| Debra | Lunge | 2 | 0.9 s | A long forward dash |
| Marjorie | Arc Dash | 2 | 0.9 s | A fast (speed 30) medium dash that curves 90°, alternating right then left (Default) |
| Louise | Shimmy | 4 | 0.6 s | Short dashes (~3 m), pattern **Forward, Forward, Back, Forward** |

- **The move belongs to the crab, not to a part** (Default, Claude's recommendation): gear swapping rebuilds everything else, so the move is what keeps each crab feeling like itself. **Open:** whether tails should add universal movement augments (an extra charge, faster recharge), or whether moves should move onto tails and become swappable. Today it's a CreatureData field (`move_ability`), so either change is cheap.
- "Forward" means where you're steering, or where you face if you're not moving. Saul's scuttles and Louise's back-steps keep you facing forward.

- All starters share one fixed body (6 sockets), so any crustacean part fits any starter (Decided: fixed sockets).
- **Every crab is its own saved game** (Decided): its gear, bag, stash and map progress all belong to that crab. On the select screen, **CONTINUE** picks a crab's save back up and **NEW GAME** starts that crab over from the beginning (press twice to confirm if it has a save). The select screen shows each crab as it looks in its save, plus its deepest depth.

## The endless dive (Decided: endless, part levels)
| Rule | Status |
|---|---|
| Depths 1–5 are hand-made. **Every depth after that is generated, forever** | Decided |
| **The same depth is always the same level** (seeded from the depth), so "depth 23 is brutal" means the same thing for everyone | Decided |
| **Part levels:** every part drops at the level's depth. Level multiplies its bonuses (+12% per level; level 11 = ×2.2), on top of rarity. Penalties don't scale; SPD scales gently | Decided (numbers: Default) |
| Difficulty = 1 + 0.25 × (depth − 1) on enemy HP and damage. Rarity luck = 0.3 × (depth − 1), capped at 3 | Default |
| **The map branches** (Decided): 2–3 routes per depth that fork and rejoin; a level unlocks when any level leading to it is cleared. Cliffs, kelp, coral, glowing specks and whale bones line the chart, the water darkens with depth, and modifier dots ring each level | Default (look) |
| **Bosses dash much farther** (×2.2 reach, Decided for the shark boss; applies to every boss charge) | Decided |
| **Dev skip** (Decided): F5 or SKIP in a level clears it and opens the portal; "DEV: mark cleared" on the map. `GameState.dev_mode` | Decided |
| **When the boss dies, a portal opens.** No prompt: walk through it whenever, and keep fighting/looting until then | Decided |

### What makes each generated depth different (Decided ingredients, Default details)
1. **Biome.** Shallows, Kelp, Reef, Wreck, Abyss, plus Smoking Vents (6+), Sargassum Drift (6+), Cold Seep (7+), Black Trench (8+) and Whale Fall (9+), each with its own palette and scenery. Newer biomes get likelier the deeper you go.
2. **Arena layout.** Open, pillars, ring (inner wall with gaps), canyon (three lanes) or islands.
3. **Creature mix.** 5–6 creatures that live at that depth (each creature has a `min_depth`), always at least 2 crustaceans. One **featured** creature appears 3× as often.
4. **Objective.**
   - **Cull:** kill N.
   - **Waves:** survive N escalating waves.
   - **Hunt:** kill N marked champions.

   The hand-made Coral Reef is Waves and the Sunken Wreck is Hunt.
5. **Modifiers.** One per level, two from depth 12, three from depth 25. They're shown on the map before you dive and on the HUD.

| Modifier | Effect |
|---|---|
| Swarm | Twice as many creatures, half the HP each |
| Armoured | Creatures take 35% less damage |
| Venom tide | Creature hits poison you |
| Dark water | Thick fog, glowing creatures |
| Treasure current | +1.5 rarity luck |
| Champions | ~20% of creatures are elites: bigger, 3× HP, glowing, always drop, often wearing stolen parts |
| Riptide | A slowly turning current pushes everyone |
| Frenzy | Creatures move 25% faster and attack 30% faster |

## Bosses
- **Chimera bosses (Decided).** A generated boss is a giant creature wearing 2–4 parts stolen from other creatures at that depth. It gets a generated name ("The Barnacled Hermit Crab Wearer of Others") and always drops two parts, one of them stolen.
- **Early bosses are paced slower** (Decided: they were too hard): depth 1 bosses wait 2× as long between attacks, depth 2 waits 1.7×, depth 3 waits 1.4×, and their windups are a little longer too (by the square root). Damage is unchanged. From depth 4 on, bosses fight at full speed.
- **Adaptive tactics (Decided: bosses change tactics based on range vs close).** Every boss watches where you hit it from.
  - If you **snipe from range**, it switches to **Rush**: it charges across the arena at you (a red lane warns you), then answers with a volley of shots.
  - If you **brawl up close**, it switches to **Bristle**: thorns (hitting it hurts you), a point-blank slam (a red circle warns you), then it backs off.
  - A toast tells you when it adapts.
- **Traits (Default).** Generated bosses get 1 trait, 2 from depth 8, and 3 from depth 16.

| Trait | Effect |
|---|---|
| Summoner | Calls in 2 creatures every ~11 s |
| Enrage | Below half health: faster, attacks faster, glows red |
| Slam | A telegraphed shockwave |
| Shell | At 2/3 and 1/3 health it hides in a bubble shield (90% less damage) for 5 s |
| Splitter | Splits into two half-size champions when it dies |

## Tails (Decided: a tail attachment that does something out of your control)
A 6th socket. Tails are passive: they attack or defend on their own, and you never trigger them. (The shark tail was removed from loot: Decided.)

| Tail behaviour | What it does | From |
|---|---|---|
| Flick | When you're hit, sometimes yanks you backwards (maybe into trouble) | Lobster, shrimp, squat lobster |
| Stab | Stabs a nearby enemy every ~2 s | Horseshoe crab, stingray whip |
| Zap | Chain-zaps up to 3 enemies every ~4 s | Torpedo ray |
| Lure | Every ~9 s, calls every creature within 18 m to you | Anglerfish |
| Spines | Sprays spines in all directions when you're hit | Lionfish, mantis shrimp |
| Dodge | 20% chance to slip out of a hit completely | Louise, shrimp |
| Guard | Every 6 s, hardens to block the next hit | Giant isopod |
| Mend | Always slowly regrowing HP | Squat lobster |
| Tucked | Nothing. It's a crab | Crab starters |

## Creatures: 36 types + 5 hand-made bosses
**Crustaceans** (on the shared rig; they wear exactly what they drop, Decided): Shore Crab, Ghost Crab, Fiddler Crab, Blue Crab, Hermit Crab, Decorator Crab, Rock Lobster, Mantis Shrimp, Pistol Shrimp, Boxer Crab (fights with stinging anemones), Spider Crab, Coconut Crab, Squat Lobster, Giant Isopod, Yeti Crab (hairy, rakes), plus the King Crab boss.

**Other sea creatures** (their own bodies; each drops 1–2 parts for limited slots, Decided rule):

| Creature | Behaviour | Attack | Drops |
|---|---|---|---|
| Starfish | drifter | pulse | Starfish Back |
| Sea Urchin | turret | spines | Urchin Shell |
| Jellyfish | drifter | pulse + poison | Jelly Cap |
| Man o' War | drifter (venomous) | pulse | Man o' War Float |
| Sea Cucumber | drifter | pulse | Cucumber Hide |
| Moray Eel | ambusher | dash | Moray Jaw |
| Sea Snake | melee (venomous) | bite | Sea Snake Fang |
| Pufferfish | drifter | spines | Puffer Shell |
| Reef Shark | charger | dash | Shark Jaw, Shark Fin (rare) |
| Hammerhead | charger | pierce | Hammerhead (head), Shark Fin (rare) |
| Barracuda | charger | pierce | Barracuda Fang |
| Swordfish | charger | pierce | Swordfish Bill |
| Stingray | charger | dash | Ray Stinger, Ray Whip (tail) |
| Torpedo Ray | ranged | zap (chain lightning) | Torpedo Tail |
| Anglerfish | ranged | glowing spit | Angler Lure, Angler Stalk (tail) |
| Lionfish | ranged | venom spit | Lionfish Crest, Lionfish Fan (tail) |
| Octopus | ranged | 3-shot ink | Octopus Arms (legs) |
| Cuttlefish | ranged | tentacle pull (yanks you in) | Cuttlebone |
| Nautilus | ranged | 5-shot volley | Nautilus Shell |
| Horseshoe Crab | melee | bite | Horseshoe Helmet, Horseshoe Spike (tail) |
| Giant Clam | turret | pearl volley | Giant Clam Shell |

Every creature attack has a windup: area attacks show a filling red circle and charges show a red lane.

> Exotic parts are **stat-and-look only** for now. Special powers for exotic parts are still **deferred** (Decided). Claws and tails are the parts with behaviour.

## Body parts
| Rule | Status |
|---|---|
| Each part has its own stats, ability and look | Decided |
| Rarity is random. Special items drop only from specific creatures (Pearl Conch, King's Crown, Shark Fin) | Decided |
| Transmog unlocks late (data model ready). The Gold Debra set makes it mostly unnecessary | Decided |
| Sockets: Head, Shell, Left claw, Right claw, Legs, Tail ("body" = shell; legs are one slot for all six) | Default (tail: Decided) |
| 114 parts so far | — |

### Loot tiers (Decided: more tiers, a much rarer Gold tier that always has a unique mod)
| Tier | Bonus multiplier | Base odds | Mod |
|---|---|---|---|
| Common | ×1.0 | 60 | — |
| Uncommon | ×1.3 | 28 | — |
| Rare | ×1.7 | 10 | — |
| Epic | ×2.2 | 2 | — |
| **Legendary** | ×2.8 | 0.4 | always one regular mod |
| **Gold** | ×3.5 | 0.06 (~1 in 1700 at depth 1) | always one unique gold-only mod |

Luck (depth, bosses, champions, Treasure, Lucky) boosts tiers up to Epic fully, Legendary partly and Gold only a little, so Gold stays rare everywhere. **15% of Gold drops become a Golden Debra piece.** (Numbers: Default.)

**Regular mods (Legendary):** Vampiric, Thorns, Swift, Sturdy, Keen, Lucky, Regen, Magnet.
**Gold-only mods:** Echo (every claw strike hits again), Detonate (kills explode), Stormcaller (hits chain lightning), Second wind (survive one killing blow per dive), Colossus (+40% HP, bigger, no knockback), Midas (every kill drops an extra part), Timeless (shell cooldowns −40%), Frost (hits slow).

### Sets (Decided: set bonuses for full Epic sets; the Debra set is the best)
- Each crustacean family's parts form a set (Shore, Hermit, Mantis, Rock Lobster, …, plus each starter's own set).
- Wear **every piece, all Epic or better**, and the bonus switches on: +20–30% HP/ATK/DEF plus perks that reuse the mods (for example, Shore = Swift, Mantis = Echo, King Crab = Detonate).
- **Headliner (Debra):** all 6 Debra pieces at **Gold** gives +60% HP/ATK/DEF, Echo, Vampiric ×2, Second wind and Detonate. It's the best gear in the game, so the strongest look in the sea is Debra's own and transmog is mostly unnecessary.

### Shell abilities: C / gamepad B / ABILITY (Decided: every shell has an ability; the basic dash was removed 2026-10-23)
| Ability | Shells | Cooldown |
|---|---|---|
| Harden (60% less damage for 2.5 s; replaced the basic dash, Default) | most crab and lobster shells | 6 s |
| Deflector (blocks 80% of damage, bounces shots back) | hermit conches, Marjorie, clam, nautilus | 7 s |
| Cloak (invisible 3 s; next hit ×2) | mantis, ghost crab, decorator, cuttlebone | 10 s |
| Spike Burst | urchin, puffer | 5 s |
| Roll (untouchable rolling charge) | isopod, horseshoe | 6 s |
| Mend (heal 30%) | starfish, sea cucumber | 12 s |
| Quake (ground slam) | coconut, king, yeti | 6 s |
| **Shark Dash** (long, straight ramming charge): the premium one | **Shark Fin** (rare special drop from sharks) | 2.5 s |

Higher rarity shortens cooldowns; Timeless cuts them by 40%.

### Inventory and storage (Decided)
- **Bag:** 30 slots, per crab. Q / Y / TAKE puts loot in the bag. A part you swap out goes into the bag (or to the floor if the bag is full).
- **Stash:** 90 slots at home, per crab. Reach it at the Coke can in any level (open the inventory there), or with STASH / BAG on the map.
- **Inventory screen** (I / Tab / Back / INV): what you're wearing, set progress, active mods, bag and stash. It compares stats against what you wear, and lets you equip (L/R for claws), store, or drop/scrap. The game pauses while it's open.
- **Loot on the floor vanishes after 20 seconds,** blinking for the last 5 (Decided). It floats in a glowing bubble in its rarity colour, so it never looks like a creature (Decided fix: the jelly cap looked like a jellyfish).

## Combat
**Open by design.** We will prototype 3–4 versions. **Iteration #1 (built): each claw is an attack.**

| Style | Feel | Effect |
|---|---|---|
| Pinch | quick jabs | small arc + sparks |
| Crush | slow, heavy, knockback | arc, ground cracks, dust, camera shake |
| Cut | fast double slice | two crossing slashes |
| Rake | three wide swipes | triple fan |
| Snap | ranged bubble | bubble with a trail |
| Bite | heals you for 30% of damage | jaws snapping shut |
| Lash | long, narrow reach | whip line |
| Sting | poisons for 3 s | green thrust + puff |

Damage = style damage × claw power (rarity × level) + ½ total ATK. DEF scales incoming damage by 25/(25+DEF). Poison ignores DEF. Effects glow (additive) so they read on dark water.

## Controls (Default)
| | Keyboard & mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Left thumb |
| Aim | Mouse | Right stick | Auto-aim |
| Left / right claw | LMB, J / RMB, K | LB, LT / RB, RT | L CLAW / R CLAW |
| Shell ability | C | B | ABILITY |
| Take to bag | Q | Y | TAKE |
| Inventory | I or Tab | Back | INV |
| Equip (left claw) / to right claw | E or F / R | X / D-pad right | EQUIP, EQUIP L / EQUIP R |
| Own movement move | Space | A | MOVE |
| Back to map | Esc (or the portal) | Start | MAP button |
| Dev: random part / spawn / heal / boss / skip level | F1 / F2 / F3 / F4 / F5 | | SKIP |

## Title screen and decor (Decided)
- The crab select screen doubles as the title screen. Sea creatures scuttle and swim past behind the starters (crabs side-on, fish at their swimming height), in front of a backdrop of kelp, rocks, corals, sponges and anemones, with seagrass in the corners.
- **Props are game-ready and used in levels:** branching and staghorn corals, sea fans, brain and table corals (solid), tube sponges (solid), anemones with glowing tips, and seagrass. They sway with the water. Shallows get seagrass, anemones and staghorn; Kelp gets seagrass and anemones; the Reef gets the full coral set; the Wreck gets sponges, anemones and fans; Sargassum gets seagrass.

## Home and progression
| Rule | Status |
|---|---|
| A long progression arc | Decided |
| A buildable home from a found object; storage yes, crafting shelved | Decided |
| A sea town is a maybe for later | Decided (deferred) |
| The Coke can stands at the north edge of every level: you start and respawn there, and it heals you. On the map, HOME = change crab | Default |
| Storage: the stash, reached at the Coke can or from the map | Decided (built) |

## Open questions

- [ ] Abilities for heads, shells and legs, including exotic parts
- [ ] Should Gold drop rates rise past depth ~40?
- [ ] Is the camera isometric or third-person? (Default: fixed top-down)
- [ ] Art style
- [ ] Are Marjorie and Gary keepers?
- [ ] Balance past depth ~30 is untested in play

**Explicitly deferred:** exotic part abilities, crafting, sea town, transmog UI.

## Milestones
- **Milestone 1 (done):** parts snap onto the shared rig; kills drop parts; equipping changes look and stats; swapping arms changes the attack.
- **Milestone 2 (done):** 5 starters, crab select, world map, 5 hand-made levels with bosses, sea creatures, saved progress.
- **Milestone 3 (done):** endless generated depths (biomes, layouts, featured creatures, modifiers, objectives), chimera bosses with traits and adaptive tactics, the portal, part levels, the tail socket, 16 new creatures, new attacks (zap, pull, volley, pierce, rake) and glowing attack effects with telegraphs.
- **Milestone 4 (done):** Legendary and Gold tiers with mods, set bonuses (Gold Debra = Headliner), shell spacebar abilities (Shark Dash on the rare Shark Fin), passive tails (dodge, guard, mend), bag + stash + inventory screen, loot bubbles that vanish after 20 s, a branching and richer map, dev skip, longer boss dashes.
- **2026-10-20:** each crab is its own saved game; depth 1–3 bosses paced slower.
- **2026-10-23:** a movement move per starter crab (jump, scuttle, lunge, arc, shimmy); a title screen with a creature parade and a coral backdrop; game-ready swaying props (corals, sponges, anemones, seagrass) used in the shallows, kelp, reef, wreck and sargassum.
- **Next candidates:** abilities for heads and legs, tail augments for movement (Open), combat iteration #2, real models, sound, transmog UI.
