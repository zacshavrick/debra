# Debra: design doc

**Single source of truth for the design.** Update it when the design changes. History and reasoning: [`projectContext/DEBRA_HANDOFF.md`](../projectContext/DEBRA_HANDOFF.md).

Labels used below:
- **Decided**: Zac said it or explicitly agreed to it.
- **Default**: Claude picked it to get the prototype running. It is not decided. Change it freely.
- **Open**: nobody has picked yet. Ask Zac before committing to anything that's hard to undo.

## Pitch (Decided)
You play a little crustacean on the seafloor. Every kill drops a body part. Equipping a part changes your stats, your abilities and your look. **You are what you kill.**

- 3D action RPG, loot-driven. Title: **Debra** (D-E-B-R-A).
- Engine: **Godot**. Targets: **Windows exe** and **mobile web app** (Zac, Oct 19 2026).

## Core loop (Decided)
Leave home → fight seafloor creatures → take their parts → equip and mutate → go back home to store spares.

## Characters (Decided)
- There are several playable starter crustaceans. Debra is the headliner and the first one.
- Creatures don't talk. Nothing makes Debra special, and losing her original look is intended.
- Starter crabs and enemies are the same kind of creature, so every enemy is also a parts catalogue.

## Body parts
| Rule | Status |
|---|---|
| Each part has its own stats, ability and look | Decided |
| Every playable crustacean shares one fixed body shape with fixed sockets | Decided |
| Crustacean enemies can drop any of their parts | Decided |
| Non-crustaceans (starfish, eel, shark, jellyfish) drop only 1–2 parts, for limited slots | Decided (not built) |
| Rarity is random. Special items drop only from specific creatures | Decided |
| Transmog (keep a part's stats, show another part's look) unlocks late, so early players are forced to look mutated | Decided (data model ready, not built) |
| **Sockets: Head, Shell, Left claw, Right claw, Legs.** "Body" is the same slot as shell. Legs are one slot holding the whole set of 6 | Default |
| **Rarity: Common / Uncommon / Rare / Epic.** These multiply a part's *bonuses* by ×1.0 / 1.3 / 1.7 / 2.2; penalties stay flat. Base odds are 60 / 28 / 10 / 2, and some creatures have "luck" that shifts them up | Default |
| **Claw ability = attack style.** Each claw is an attack (see Combat). Abilities for the other slots are not designed yet | Default |
| Stats: HP, ATK, DEF, SPD | Default |

## Enemies (prototype set: Default)
| Creature | Look | Fights | Drops |
|---|---|---|---|
| Shore Crab | small, green-brown, spiky | fast pinches | shore eyes/shell/pincer/legs |
| Hermit Crab | conch shell, one big crusher claw | slow, heavy hits | hermit parts, plus the **Pearl Conch** (special, 8%) |
| Mantis Shrimp | slim, rainbow, big eyes | keeps its distance and snaps bubbles | mantis parts, higher rarity luck |

Enemies wear exactly the parts they drop.

## Combat
**Open by design.** We will prototype 3–4 versions and keep what works. Each one has to make part swaps change how you fight.

**Iteration #1, "each claw is an attack" (Default, built):**
- The left claw is attack 1 and the right claw is attack 2. Hold to keep attacking.
- The claw's style sets the attack:
  - **Pinch**: quick, short range.
  - **Crush**: slow windup, big damage, wide arc, knockback.
  - **Snap**: ranged bubble shot.
- Damage = style damage × claw rarity + ½ of total ATK. DEF scales incoming damage by 25/(25+DEF).
- Aim follows the mouse or the right stick. On touch, attacks auto-aim at the nearest enemy.

## Camera and controls (Default)
A fixed-angle top-down ARPG camera that doesn't rotate, so it works the same on a phone and with a mouse.

| | Keyboard & mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Left thumb (floating stick) |
| Aim | Mouse | Right stick | Auto-aim |
| Left claw | LMB / J | X / LB / LT | L CLAW (hold) |
| Right claw | RMB / K | B / RB / RT | R CLAW (hold) |
| Equip (left claw) | E / F | A | EQUIP / EQUIP L |
| Equip right claw | R | Y | EQUIP R |
| Dev: drop random part / spawn enemy / heal | F1 / F2 / F3 | | |

## Home and progression
| Rule | Status |
|---|---|
| A long progression arc | Decided |
| A buildable home made from a found object (a seashell or a Coke can) that you head out from | Decided |
| Storage at home: yes. Crafting: shelved | Decided |
| A sea town is a maybe for later | Decided (deferred) |
| **Home is a Coke can at the arena edge.** You respawn there, and standing near it heals you | Default |
| **No storage yet.** A swapped-out part drops at your feet, so nothing is lost | Default |

## Open questions
- [ ] Final socket count. Are left and right legs separate slots?
- [ ] Which slots each non-crustacean can fill (e.g. shark jaw → head only?)
- [ ] Final rarity tiers and how they scale stats (Default is in place)
- [ ] What abilities mean for heads, shells and legs (passives? actives?)
- [ ] How many starter crustaceans there are, and how they differ
- [ ] Is the camera isometric or third-person? (Default: fixed top-down)
- [ ] World structure: open seafloor, zones, or runs from home
- [ ] Home upgrades: what makes the home grow
- [ ] Art style

**Explicitly deferred:** exotic part designs, crafting, sea town.

## Prototype milestone 1: status
The goal: a part dropped by a killed crab visibly snaps onto Debra and changes her stats.

- [x] Every slot accepts any crustacean part with no visible misalignment *(checked by the smoke test for every part × socket)*
- [x] Killing an enemy drops a part with a rolled rarity
- [x] Equipping a part changes both appearance and a visible stat
- [x] Swapping arms changes how an attack feels or works (pinch / crush / snap)

**Next candidates:** home storage + save file, combat iteration #2, a second starter crab, first non-crustacean (starfish?), a real Debra model on the rig.
