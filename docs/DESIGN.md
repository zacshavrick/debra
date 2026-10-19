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

- All starters share one fixed body (6 sockets), so any crustacean part fits any starter (Decided: fixed sockets).
- Mutations are saved per crab. The select screen shows each crab as they look now, and "Undo mutations" resets one crab (Default).

## The endless dive (Decided: endless, part levels)
| Rule | Status |
|---|---|
| Depths 1–5 are hand-made. **Every depth after that is generated, forever** | Decided |
| **The same depth is always the same level** (seeded from the depth), so "depth 23 is brutal" means the same thing for everyone | Decided |
| **Part levels:** every part drops at the level's depth. Level multiplies its bonuses (+12% per level; level 11 = ×2.2), on top of rarity. Penalties don't scale; SPD scales gently | Decided (numbers: Default) |
| Difficulty = 1 + 0.25 × (depth − 1) on enemy HP and damage. Rarity luck = 0.3 × (depth − 1), capped at 3 | Default |
| The map is an endless scrolling depth chart. The water darkens with depth, and you can see 2 locked depths ahead | Default |
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
A 6th socket. Tails act on their own; you never trigger them.

| Tail behaviour | What it does | From |
|---|---|---|
| Flick | When you're hit, sometimes yanks you backwards (maybe into trouble) | Lobster, shrimp, squat lobster |
| Stab | Stabs a nearby enemy every ~2 s | Horseshoe crab, stingray whip |
| Zap | Chain-zaps up to 3 enemies every ~4 s | Torpedo ray |
| Lure | Every ~9 s, calls every creature within 18 m to you | Anglerfish |
| Spines | Sprays spines in all directions when you're hit | Lionfish, mantis shrimp |
| Surge | Randomly rams you forward, hurting what you hit | Shark tails |
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
| Reef Shark | charger | dash | Shark Jaw, Shark Fin Shell |
| Hammerhead | charger | pierce | Hammerhead (head), Shark Tail |
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
| Rarity is random. Special items drop only from specific creatures (Pearl Conch, King's Crown) | Decided |
| Transmog unlocks late (data model ready, not built) | Decided |
| Sockets: Head, Shell, Left claw, Right claw, Legs, **Tail** ("body" = shell; legs are one slot for all six) | Default (tail: Decided) |
| Rarity: Common / Uncommon / Rare / Epic (×1.0/1.3/1.7/2.2 on bonuses), and part level on top | Default |
| A swapped-out part drops at your feet (stand-in for storage) | Default |
| 113 parts so far | — |

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
| Left / right claw | LMB, J / RMB, K | X, LB, LT / B, RB, RT | L CLAW / R CLAW |
| Equip (left claw) / to right claw | E or F / R | A / Y | EQUIP, EQUIP L / EQUIP R |
| Back to map | Esc (or the portal) | Start | MAP button |
| Dev: random part / spawn creature / heal / summon boss | F1 / F2 / F3 / F4 | | |

## Home and progression
| Rule | Status |
|---|---|
| A long progression arc | Decided |
| A buildable home from a found object; storage yes, crafting shelved | Decided |
| A sea town is a maybe for later | Decided (deferred) |
| The Coke can stands at the north edge of every level: you start and respawn there, and it heals you. On the map, HOME = change crab | Default |
| **Storage is not built yet** | — |

## Open questions
- [ ] Storage at home: a stash on the map's HOME?
- [ ] Abilities for heads, shells and legs, including exotic parts
- [ ] A Legendary tier above Epic?
- [ ] Is the camera isometric or third-person? (Default: fixed top-down)
- [ ] Art style
- [ ] Are Marjorie and Gary keepers?
- [ ] Balance past depth ~30 is untested in play

**Explicitly deferred:** exotic part abilities, crafting, sea town, transmog UI.

## Milestones
- **Milestone 1 (done):** parts snap onto the shared rig; kills drop parts; equipping changes look and stats; swapping arms changes the attack.
- **Milestone 2 (done):** 5 starters, crab select, world map, 5 hand-made levels with bosses, sea creatures, saved progress.
- **Milestone 3 (done):** endless generated depths (biomes, layouts, featured creatures, modifiers, objectives), chimera bosses with traits and adaptive tactics, the portal, part levels, the tail socket, 16 new creatures, new attacks (zap, pull, volley, pierce, rake) and glowing attack effects with telegraphs.
- **Next candidates:** storage, a Legendary tier, abilities for non-claw parts, combat iteration #2, real models, sound.
