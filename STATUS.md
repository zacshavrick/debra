# Debra: status

## What the game is
A 3D action RPG where you play a crustacean on the seafloor. Every kill drops a body part, and wearing it changes your stats, attacks and look: you are what you kill. Godot 4.7.2; ships as a Windows exe and a mobile web app.

## Current state
Milestones 1–4 are done: 5 starter crabs (each its own saved game, each with its own movement move on Space), a branching map, an endless generated dive with chimera bosses that adapt to your play, 36 creatures, 114 parts, loot tiers up to Gold with mods, set bonuses, shell abilities (C), tails, bag + stash + inventory. Latest build: `builds/Debra-v0.10-windows.zip`. CI builds and publishes through GitHub (GitHub Pages still needs Settings → Pages → Source: GitHub Actions). Design: `docs/DESIGN.md`; code: `docs/ARCHITECTURE.md`. Smoke test: `tools/test.ps1` (~9 min, passing).

## Recent changes
- CC, Nov 6, corrected this file (milestone 4, known problems, next up).
- CC, Nov 6, created this file. Earlier history is in git and CLAUDE.md.
- CC, Oct 28, Gary's jump ~10 m; boss portal ~10 m from the boss and click/tap only; floor swaps drop the old part in place with a fresh 20 s timer; swap prompts warn about lost mods, shell abilities, tails and set bonuses (push eadf7c6, v0.10).

## Next up
- Zac to playtest v0.10: Gary's jump length, portal clicking, swap warnings.
- Open: should movement moves stay fixed per crab, or move onto tails? (docs/DESIGN.md)
- Open: towns. CC suggested a map-node barter trader (parts for parts, mod rerolls) instead of a shop town, to keep "you are what you kill". Waiting on Zac.
- Crafting, exotic parts and the sea town stay shelved.

## Known problems
- Touch input not verified on a real phone.
- Balance not checked past ~depth 30.
- Movement cooldowns (0.9 s, Louise 0.6 s) may make dodging too cheap; bosses could feel easy.
- Gary could land inside a rock (collision returns on landing; physics should push him out, not seen yet).
- Clicking the portal also swings the left claw (harmless).
