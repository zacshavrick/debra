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
- **No plot. Drop in and play.** (Zac, Oct 19 2026)

## Core loop
Pick a crab → pick a level on the map → fight sea creatures → take their parts → equip and mutate → the boss shows up → beat it → the next level unlocks.

## Starter crustaceans
| Crab | Status | Plays like |
|---|---|---|
| **Debra the Lobster** (headliner) | Decided | Crusher claw + cutter claw, lobster tail shell. Balanced-heavy. |
| **Saul the Crab** | Decided | Two pincers. Balanced. |
| **Louise the Shrimp** | Decided | Two fast snippers (cut), very fast, fragile. |
| **Marjorie the Hermit Crab** | Default (Claude's pick) | Conch shell, one crusher. Slow tank. |
| **Gary the Spider Crab** | Default (Claude's pick) | Long lash arms and very long legs. Hits from range. |

- Debra was a crab in the first prototype and is now a lobster (Zac).
- All starters share one fixed body with 5 sockets, so any crustacean part fits any starter (Decided: fixed sockets).
- **Mutations are saved per crab.** Switching crabs doesn't lose anyone's parts. The select screen shows each crab as they currently look, and "Undo mutations" resets one crab (Default).
- Creatures don't talk. Nothing makes Debra special, and losing her original look is intended (Decided).

## Levels and the map
| Rule | Status |
|---|---|
| Levels, a map, and lots of sea creatures to fight | Decided |
| **Five levels**, deeper = harder: Sandy Shallows → Kelp Forest → Coral Reef → Sunken Wreck → The Abyss | Default |
| **The map is a depth chart.** Shallows at the top, abyss at the bottom, a path from home through every level | Default |
| **Level loop:** kill N creatures → the boss arrives → beat it → cleared, the next level unlocks. Creatures keep coming, so you can keep farming | Default |
| Deeper levels: tougher creatures (HP/damage ×1.0 → ×3.2) and better loot odds (rarity luck 0 → 1.5) | Default |
| Bosses are big versions of a level creature and always drop 2 parts, one at least Rare | Default |
| In-level minimap; MAP button / Esc / Start goes back to the map | Default |

| Level | Creatures | Boss |
|---|---|---|
| Sandy Shallows | Shore Crab, Fiddler Crab, Starfish, Sea Urchin | Giant Fiddler Crab |
| Kelp Forest | Hermit Crab, Rock Lobster, Decorator Crab, Moray Eel, Jellyfish, Shore Crab | Old Rock Lobster |
| Coral Reef | Mantis Shrimp, Pistol Shrimp, Pufferfish, Lionfish, Stingray, Jellyfish | Great Reef Shark |
| Sunken Wreck | Spider Crab, Octopus, Moray Eel, Rock Lobster, Anglerfish, Coconut Crab | Coconut Crab Matriarch |
| The Abyss | Giant Isopod, Anglerfish, Reef Shark, Jellyfish, Spider Crab, Sea Urchin | The King Crab |

## Creatures (21 types + 5 bosses)
**Crustaceans** (on the shared rig; they wear exactly what they drop, so every one is a parts catalogue, Decided): Shore Crab, Fiddler Crab (one giant claw), Hermit Crab, Mantis Shrimp, Rock Lobster, Pistol Shrimp, Spider Crab, Coconut Crab, Decorator Crab, Giant Isopod, King Crab (boss).

**Other sea creatures** (their own bodies; each drops only 1–2 parts for limited slots, Decided rule):

| Creature | Behaviour | Attack | Drops (Default) |
|---|---|---|---|
| Starfish | drifts at you | stinging pulse | Starfish Back (shell) |
| Sea Urchin | never moves | spines in all directions | Urchin Shell |
| Jellyfish | floats at you | stinging pulse + poison | Jelly Cap (head) |
| Moray Eel | hides, then lunges | dash | Moray Jaw (claw: bite) |
| Pufferfish | drifts, puffs up | spines | Puffer Shell |
| Reef Shark | circles in and charges | dash | Shark Jaw (claw: bite), Shark Fin Shell |
| Anglerfish | keeps its distance | glowing spit | Angler Lure (head) |
| Octopus | keeps its distance | 3-shot ink spread | Octopus Arms (legs: 8 tentacles) |
| Stingray | charges | dash | Ray Stinger (claw: sting) |
| Lionfish | keeps its distance | venom spit | Lionfish Crest (head) |

Every creature attack has a visible windup (the body puffs up or glows, and a red ring warns of area attacks) so you can dodge it.

> The exotic parts are **stat-and-look only for now**. "Exotic part designs" (special abilities) are still **deferred** (Decided). These are placeholders so the creatures have something to drop.

## Body parts
| Rule | Status |
|---|---|
| Each part has its own stats, ability and look | Decided |
| Crustacean enemies can drop any of their parts. Non-crustaceans drop 1–2 | Decided |
| Rarity is random. Special items drop only from specific creatures (Pearl Conch from hermits, King's Crown from the King Crab) | Decided (specials: Default) |
| Transmog unlocks late (data model ready, not built) | Decided |
| Sockets: Head, Shell, Left claw, Right claw, Legs ("body" = shell; legs are one slot holding the whole set) | Default |
| Rarity: Common / Uncommon / Rare / Epic, which multiply *bonuses* ×1.0/1.3/1.7/2.2. Odds 60/28/10/2, shifted by luck | Default |
| Claw ability = attack style. Other slots' abilities are not designed yet | Default |
| A swapped-out part drops at your feet (stand-in for storage) | Default |
| 75 parts so far | — |

## Combat
**Open by design.** We will prototype 3–4 versions and keep what works.

**Iteration #1, "each claw is an attack" (Default, built).** Left claw = attack 1, right claw = attack 2. Hold to keep attacking.

| Style | Feel | From |
|---|---|---|
| Pinch | quick jabs | most pincers |
| Crush | slow, heavy, knockback | crushers, fiddler claw |
| Cut | fast double slice | lobster cutter, Louise |
| Snap | ranged bubble | mantis/pistol shrimp |
| Bite | heals you for 30% of the damage | shark and moray jaws |
| Lash | long, narrow reach | spider crab arms, Gary |
| Sting | poisons for 3 s | ray stinger |

Damage = style damage × claw rarity + ½ of total ATK. DEF scales incoming damage by 25/(25+DEF). Poison ignores DEF.

## Controls (Default)
A fixed top-down camera that doesn't rotate.

| | Keyboard & mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Left thumb |
| Aim | Mouse | Right stick | Auto-aim |
| Left / right claw | LMB, J / RMB, K | X, LB, LT / B, RB, RT | L CLAW / R CLAW |
| Equip (left claw) / to right claw | E or F / R | A / Y | EQUIP, EQUIP L / EQUIP R |
| Back to map | Esc | Start | MAP button |
| Dev: random part / spawn creature / heal / summon boss | F1 / F2 / F3 / F4 | | |

## Home and progression
| Rule | Status |
|---|---|
| A long progression arc | Decided |
| A buildable home made from a found object (a seashell or a Coke can) | Decided |
| Storage at home: yes. Crafting: shelved | Decided |
| A sea town is a maybe for later | Decided (deferred) |
| **The Coke can stands at the north edge of every level.** You start and respawn there, and it heals you. On the map, HOME = change crab | Default |
| **Storage is not built yet** | — |

## Open questions
- [ ] Storage at home: how it works now that there's a map (a stash on the map's HOME?)
- [ ] Final socket count. Are left and right legs separate slots?
- [ ] What abilities mean for heads, shells and legs (passives? actives?), including the exotic parts
- [ ] Is the camera isometric or third-person? (Default: fixed top-down)
- [ ] Home upgrades: what makes the home grow
- [ ] Art style
- [ ] Are Marjorie and Gary keepers?

**Explicitly deferred:** exotic part abilities, crafting, sea town, transmog UI.

## Milestones
**Milestone 1 (done):** a part from a killed crab snaps onto Debra and changes her stats. Every slot fits every crustacean part; kills drop parts with a rolled rarity; equipping changes look and stats; swapping arms changes the attack.

**Milestone 2 (done):** 5 starters, crab select, world map, 5 themed levels with bosses and unlocks, 21 creature types (10 non-crustacean), 7 claw styles, poison, saved progress and mutations, minimap.

**Next candidates:** home storage, combat iteration #2, abilities for non-claw parts, real models for Debra and friends, sound.
