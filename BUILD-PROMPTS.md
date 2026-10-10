# Jailbrick — Build Document

How to use this file:

1. **Section A** is the master context. It's already in `CLAUDE.md`, so every
   Claude Code session reads it automatically.
2. **Section B** is the full game design. It's the reference every phase builds against.
3. **Section C** has one prompt per phase. Start a new Claude Code session on this
   repo and paste in the next phase's prompt. Finish and commit a phase before starting the next.
4. **Section D** tracks time and progress. Tick off phases as you go.

> Rewritten on 2026-10-09 from notes on the original "brick-escape" draft and
> renamed to **Jailbrick**, with a prison-break theme.

---

## Section A — Master context

See [`CLAUDE.md`](./CLAUDE.md). It holds the pitch, design pillars, tech stack,
PSX look recipe, lessons from the reference games, and the working rules. It is
kept separate so Claude Code loads it every session.

---

## Section B — Game design

> **2026-10-09 design change: depth levels replace locks.** A run is an endless
> dig in 10-row levels (B2), and coins buy a start at any level you've reached
> (B8). Locks are dropped for now. Anything below marked *(parked)* was written
> for the lock design and needs a rethink before it's built.
>
> **2026-10-10:** level types became band twists (B3), worlds became 10-level
> depth bands with brick introduction levels (B9), and puzzle cells and key
> shards are parked.

### B1. Fantasy and framing

You're an inmate of somewhere that doesn't appear on maps, and you're tunnelling
out. Below your cell is a wall of numbered bricks that never ends. Every 10 rows
you dig through takes you somewhere new: the drains, the woods, the scrapyard,
somewhere stranger. If the walls close in, you're dragged back, but you remember
the way and can bribe your way back down.

### B2. Board and turn loop

- **Board:** portrait grid, **15 columns** wide and 22 rows tall. Your **launcher**
  (the hatch you crawl from) sits on the **top line**. Brick rows **rise from the
  bottom**, like sludge filling the room.
- **Layout:** bricks come in clumps with channels and pockets between them, so
  balls can work into tight spaces. Levels start with plenty of empty rows above
  the pile.
- **Bricks are flat tiles** seen straight on through an orthographic camera, so HP
  numbers are always readable. The 3D PSX look is for the room around the board.
- **Turn:**
  1. **Aim.** Drag to aim. A dotted guide line shows the first bounce, or two
     bounces with an upgrade.
  2. **Fire.** Release to fire your volley: *N* balls in quick succession. Balls
     bounce off walls and bricks. Each hit takes 1 HP (times your damage
     multiplier) from the brick's number.
  3. **Return.** Balls return when they leave through the top line. The first
     ball back sets the next launch position.
  4. **Clear or rise.** If every brick above the current level's bottom line is
     gone, the level is cleared: bonus points, and the board scrolls so the next
     level's top row sits back at the start row. Otherwise every brick moves up one
     row, revealing more of the dig from below.
  5. **Check.** If any brick reaches the **danger line** (the row just below the
     launcher), the run ends, though you can continue once (see B8).
- **Levels:** the dig is generated in blocks of 10 rows, one level each, with HP
  climbing with depth. Difficulty follows `levels/depth_curve.tres`: a sawtooth in
  5-level bands (a breather level, then a ramp), with each band harder than the
  last and pressure building from level 3. `tools/solver.gd` checks it. A gauge down the left side numbers each level's bottom line,
  and the HUD shows rows cleared out of 10.
- **Points and coins:** 1 point per HP of damage, plus a bonus per level cleared.
  Coins = points / 20 + 10 per level cleared, banked when the run ends.
- **Turn counter:** the HUD always shows "trapped in N" so the pressure is readable.
- **Fast-forward:** hold to speed up the volley (×2, ×4). Add a recall button after 3 seconds.

### B3. Band twists

> **2026-10-10:** level types became band twists. Each 5-level band of the depth
> curve (B2) gets one twist level, plus a Warden boss at the end of every world.
> Vault, Lockdown and Puzzle were written for the lock and are *(parked)*.

| Twist | What changes | Where |
|---|---|---|
| **Dig** (standard) | Nothing. Rows rise 1 per turn | Most levels |
| **Flood** | Rows rise 2 per turn, but bricks have 40% less HP | Sewer pipes bursting |
| **Nest** | Rat nests everywhere. Clear them before they fill the gaps | Needs rat nests |
| **Cache** | A stash: lots of crates, so lots of pickups, but bricks have 20% more HP | Needs crates |
| **Warden** (boss) | A wide **Warden guard** brick with ×8 HP walks 1 column per turn and drops a minion brick next to itself every 3 turns. The level clears like any other, so the guard has to go | Every 10th level: the end of each world (B9) |

- The twist sits on the **third level of each band** (pressure 0.6). Bands cycle
  through none → Flood → Nest → Cache → Flood → … so levels 8, 13, 18, 23 … have
  a twist. A twist whose brick isn't introduced yet falls back to Flood.
- Every knob (which twists, the slot, HP multipliers, the Warden's HP, pace and
  minions) lives in `levels/depth_curve.tres`, so the solver can tune it.
- The HUD's level banner names the twist ("Level 8: Flood").

### B4. Bricks

| Brick | Behaviour | Greybox look |
|---|---|---|
| **Stone** | Basic. Shows its HP | Yellow → red → purple by HP |
| **Iron** | Takes half damage, rounded up over the hits so far (at ×1 damage, every other hit counts) | Steel grey, thick dark rim |
| **Crate** | Drops a pickup (B5) in its cell when broken. Its HP is 60% of the row's | Brown with a dark cross |
| **Gas can** | When broken, explodes for its full starting HP on the 8 neighbours. Blasts chain | Red with a yellow band |
| **Rat nest** | Every 2 turns, spawns a 1 HP stone brick in an empty neighbouring cell (never the danger row) | Dark brown with a ring of dots |
| **Sludge** | Not solid: balls pass through at half speed. Has no HP, never counts for clearing or trapping, and drains away at the danger row | Flat murky green, no number |
| **Warden guard** (boss) | 2 cells wide. Moves 1 column per turn, turning at walls and bricks, and spawns minions (B3 Warden) | Dark blue with a white "W" |
| **Chain** *(parked)* | Linked to the lock. The lock is invulnerable while any chain stands | |
| **Shield** *(parked)* | Sits next to the lock and absorbs the first hit of each volley | |

### B5. Pickups (collected by touching them with a ball)

Pickups that rise into the danger row are collected automatically, so none are
ever lost. +1 Balls come from the generator's rows as before. The others come
from crates, plus a small per-row chance set in the depth curve.

| Pickup | Effect | If it rises into the danger row | Greybox look |
|---|---|---|---|
| **+1 Ball** | Permanent for this run | +1 ball | Green ring |
| **Coin** | +10 coins, banked with the run's other coins | +10 coins | Gold disc |
| **Splitter** | The ball that touches it splits into 3 (the extras last this volley only) | The first ball of the next volley splits | Three cyan dots |
| **Laser bar** | A one-shot horizontal or vertical beam: 1 damage (times the damage multiplier) to every brick in its line | Fires where it is | Red bar, flat or upright |
| **Freeze** | The next rise step is skipped (stacks) | Same | Pale blue diamond |
| **Key shard** *(parked)* | Collect 3 across a world to unlock its bonus Puzzle cell | | |

### B6. Upgrades (permanent, bought with coins)

| Upgrade | Effect per level | Max |
|---|---|---|
| Starting balls | +1 ball at level start | 10 |
| Ball damage | +10% damage | 10 |
| Launch speed | Faster volleys | 5 |
| Crit chance | +2% chance of ×3 damage | 10 |
| Aim guide | Shows one more bounce | 2 |
| Stall | +1 free Freeze per level | 2 |

Prices rise gently and are tuned so that playing normally, with no ads and no
purchases, keeps pace with the difficulty curve. The solver bot in Phase 2/6 checks this.

### B7. Charms (equip up to 3, found and earned)

Charms are build modifiers that change how you play, not just numbers.

- **Lockpick** *(parked)*: +50% damage to locks and chains
- **Rat Tail:** balls bounce off the top line once before returning
- **Rusty Spring:** the first ball of each volley is ×2 size
- **Ghost Ball:** 1 ball per volley passes through Iron bricks
- **Tally Marks:** +1 ball each time you break 10 bricks in one volley
- **Contraband:** Crates drop 2 pickups
- **Bent Spoon:** after each rise, deal 1 damage to the bottom row
- **Static Charm (World 4+):** random brick numbers glitch down by 1 each turn

Charms drop from bosses, from Puzzle cells, and as one-time rewards for world milestones.

### B8. Fail state, continues and restarting deeper

- On a loss: **continue once** per run by watching a rewarded ad (this clears the
  top 3 rows of the pile). There is never a forced ad.
- **Start from any level you've reached.** Level 1 is always free and instant.
  Deeper starts cost coins: 25 × (L − 1) × (L + 2), so level 2 is 100 and level 5
  is 700. You start with 5 balls plus 5 per level skipped (the solver bot picks
  up 4-5 +1 Balls a level on the way down; 3 left restarts starved).
- Coins and your best level are saved between runs. There are no lives or energy.

### B9. Worlds (depth bands)

> **2026-10-10:** worlds are 10-level depth bands. Each world ends on a Warden
> boss level (B3). Puzzle cells and key shards are *(parked)*.

Each world maps to one PSX asset pack. Add the asset links in `assets/README.md`
when they're imported. Until Phase 5 the HUD shows the world name and the board
gets a greybox tint per world.

| # | World | Levels | Escape story beat | Asset pack | Fog/palette | Signature |
|---|---|---|---|---|---|---|
| 1 | **The Drains** | 1–10 | Out through the cell's floor grate into the sewers | PSX Sewers *(licence to verify, Phase 8)* | Green-grey, drippy | Sludge, Rat nest |
| 2 | **Black Pines** | 11–20 | Out of the outflow pipe into night woods | PSX Trees | Blue-black, torch-lit | Crate-heavy |
| 3 | **Scrap Row** | 21–30 | A scrapyard full of wrecked cars between you and the road | PSX Cars / junk | Rust orange, sodium lights | Iron, Gas can |
| 4 | **The Hum** | 31–40 | Something isn't right. A place that shouldn't exist | PSX "weird" pack | Purple static, heavy dither | Everything, denser *(glitch variants parked)* |
| 5 | **Lockdown** (finale) | 41+ | Back at the start, but you know the way out now | Remix of all packs | Shifts per level | Everything, Warden every 10 |

**Introduction levels.** One new thing at a time. Each brick or pickup first
appears on its level and stays in the mix after that. A world's signature bricks
spawn 3× as often in that world.

| Level | New | Level | New |
|---|---|---|---|
| 1 | Stone, +1 Ball, Coin | 8 | Flood twist |
| 2 | Crate | 9 | Laser bar |
| 3 | Freeze | 10 | Warden boss |
| 4 | Sludge | 13 | Iron, Nest twist |
| 5 | Splitter | 17 | Gas can |
| 7 | Rat nest | 18 | Cache twist |

- The difficulty curve is still the B2 sawtooth in 5-level bands, so each world
  is two bands: a breather, a ramp, a breather, a ramp, then the Warden.

### B10. Monetisation (ethical, final)

- **Rewarded ads only.** Watch an ad, if you choose to, for: continue once per
  run, double coins at run end, or the daily free crate.
- **Supporter Pack (one-time, ~£3.99):** grants every rewarded-ad reward
  automatically without the ad (including double coins), an exclusive cosmetic ball
  and launcher skin, and a thank-you in the credits. It adds **no** extra power
  beyond what ads already give, and coins are never sold on their own.
- **Never:** interstitials, banners, energy, loot boxes, paid boosters, or currency packs.

---

## Section C — Phase prompts

Paste one prompt per new session. Each assumes `CLAUDE.md` has been loaded.

> Prompts for Phases 4–9 were written before the depth-level change (see the note
> at the top of Section B). Revise each one before running it: drop the lock, and
> swap "levels" for generated depth levels plus the restart-at-level economy.

### Phase 0 — Project setup

```
Phase 0 of Jailbrick (see CLAUDE.md and BUILD-PROMPTS.md).

Set up the Godot 4 project in this repo:
- project.godot (portrait 1080x1920 window, stretch mode canvas_items/aspect expand,
  Mobile renderer), text-based scenes/resources only.
- Folder layout: scenes/, scripts/core/ (pure game logic, no nodes required),
  scripts/view/, levels/, shaders/, assets/, ui/, tests/, tools/.
- .gitignore and .gitattributes suited to Godot 4 (ignore .godot/, export builds).
- Install GUT into addons/ and add one passing smoke test.
- A README section on how to open, run, and run tests headless.
- If the Godot binary isn't available in this environment, download the matching
  Linux headless build into tools/ (gitignored) so tests can run here.
Commit with a clear message. Don't build gameplay yet.
```

### Phase 1 — Proof of concept (greybox)

```
Phase 1 of Jailbrick. Build the core turn loop in greybox (cubes, flat colours, no
PSX shader yet), following Section B2.

- scripts/core/: Board (15 columns), Brick (HP, type), Lock, Ball simulation with
  fixed timestep and deterministic maths, TurnController (aim -> fire -> return ->
  rise -> check). Core must run with no scene tree so it can be tested headless.
- scripts/view/: renders the board in 3D with an orthographic-ish camera, aim
  guide line, volley firing, brick HP labels, "rows until trapped" HUD.
- Win when the lock hits 0 HP, lose when a brick reaches the danger line.
- One hard-coded test level with a lock buried mid-pile.
- GUT tests: ball reflection, brick damage, rise step, win and lose detection,
  determinism (same seed + same aim = same result).
Stop when it's fun to play for 5 minutes on desktop with the mouse. Commit.
```

### Phase 2 — Depth curve and solver bot

```
Phase 2 of Jailbrick. The game is an endless dig in 10-row levels (CLAUDE.md,
Section B2 and B8). Phase 1 left the difficulty knobs hard-coded in
LevelGenerator. Make the curve data-driven and measurable.

1. Depth curve: a DepthCurve Resource (levels/depth_curve.tres) that gives the
   generator's knobs per level (fill/keep chance, gaps, HP per row and per
   level, double-HP chance, +1 Ball chance). Shape it as a sawtooth in 5-level
   bands: a short breather at the start of each band, then a ramp.
   Play-test note: a human reached level 8 before it felt hard, so pressure
   should start building around levels 3-4.
2. Solver bot (tools/solver.gd, run via godot --headless): greedy aim choice
   with a short lookahead on the core sim only (clone + play_turn). Pick an aim
   count that keeps a full report under ~10 minutes. Plays K seeded runs from
   level 1 and from a few restart levels, and reports depth reached (median,
   p10, p90), turns per level, coins per run, and how many no-spend runs it
   takes to afford each restart level.
3. Target bands live in the curve resource. The bot exits non-zero if its median
   depth falls outside them.
4. Write the report to tools/reports/solver-latest.md.
Commit the curve, the bot and the first report.
```

### Phase 3 — Bricks, pickups, twists and worlds

```
Phase 3 of Jailbrick. Read CLAUDE.md and Sections B2-B5, B8 and B9 first.
Skip anything marked (parked).

1. Bricks (B4): iron, crate, gas can, rat nest, sludge and the Warden guard,
   in scripts/core with GUT tests, and a greybox look for each in
   scripts/view that reads without art.
2. Pickups (B5): coin, splitter, laser bar and freeze, same rules: core +
   tests + greybox look. Pickups that rise into the danger row still count.
3. Twists and worlds: band twists from B3 (Flood, Nest, Cache, and the Warden
   boss on every 10th level) and the world bands from B9, with its brick
   introduction levels, all driven by levels/depth_curve.tres. The HUD shows
   the world name, with a greybox tint per world.
4. Keep the sim deterministic: the determinism and clone tests must still
   pass, and ./tools/run_tests.sh must be green.
5. Re-run tools/solver.gd and retune the curve so the Phase 2 target bands
   still hold. Refresh tools/reports/solver-latest.md.
Commit in chunks (bricks, pickups, twists and worlds, retune). Keep greybox
visuals: art comes in Phase 5. Ask before any design change beyond the doc.
```

### Phase 4 — Progression and saves

```
Phase 4 of Jailbrick. Implement B6–B8:
- Coins, the upgrade shop (B6), charms with 3 slots (B7), key shards, Puzzle-cell unlocks.
- World map: 5 worlds, level nodes, stars (win / win with rows to spare / win
  without continue).
- Save system (user://, versioned JSON, migration-safe) with tests.
- Continue/retry flow (B8). Hook the "watch ad" buttons to a stub AdService
  that grants instantly for now.
- Re-run the solver with the expected upgrade levels at each point and tune prices.
Commit.
```

### Phase 5 — PSX art and audio pass

```
Phase 5 of Jailbrick. Apply the PSX look recipe from CLAUDE.md:
- Low-res SubViewport + nearest upscale, vertex snap + affine texture shader,
  15-bit colour + Bayer dither post-process, per-world fog.
- Import each world's asset pack into assets/<world>/. Build the backdrop rooms,
  flat brick and lock tiles per world (keep bricks readable: the HP number always
  sits on top, high contrast).
- Game feel: hit flashes, screen shake (toggle), brick break particles, lock-break
  escape cutscene (camera pushes through the doorway).
- Audio: crunchy low-sample-rate SFX, an ambient loop per world, music bus +
  settings sliders.
- Performance budget: 60 fps on a mid-range 2020 Android phone. Note draw calls.
Commit per world.
```

### Phase 6 — Audit

```
Phase 6 of Jailbrick. Do a full audit and fix pass, no new features:
- Run the solver on all 100 levels and write a report. Fix anything under 60% and
  flag anything above 98% that's meant to be a hard level.
- Code review core/ and view/ for bugs, dead code and missing tests.
- Profile on an Android device or emulator, fix frame drops and memory spikes.
- Check the economy: can a no-spend player afford what the curve expects? Show
  the numbers.
- List remaining known issues in docs/known-issues.md.
Commit fixes separately from the report.
```

### Phase 7 — UI/UX polish

```
Phase 7 of Jailbrick:
- Title screen, world map, shop, charm loadout, settings, pause, win/lose screens,
  all in the chunky PSX UI style with a toggleable CRT overlay.
- First-time tutorial that teaches aim, volley, lock and rise across the first 3
  levels with no text walls.
- Accessibility: colour-blind-safe brick palette option, larger HP numbers option,
  reduced motion/shake, left-handed layout.
- Haptics on hits/lock break (toggle).
- Prepare all strings for localisation (tr()), English only for now.
Commit.
```

### Phase 8 — Ads, purchase and compliance

```
Phase 8 of Jailbrick. Implement B10 exactly. No other monetisation.
- Replace the stub AdService with AdMob rewarded ads through a maintained Godot 4
  plugin. Rewarded only: no interstitials, no banners.
- Consent: Google UMP consent flow (GDPR/UK), and an option to change consent in settings.
- Supporter Pack one-time purchase (Google Play Billing, then StoreKit), plus
  restore purchases.
- Privacy policy and data safety form answers in docs/.
- LICENCE CHECK: verify every asset pack licence allows commercial use in a paid
  or ad-supported mobile game, especially the Sewers pack (flagged earlier).
  Record each licence in assets/LICENCES.md. Replace any pack that fails.
Commit.
```

### Phase 9 — Release and live ops

```
Phase 9 of Jailbrick:
- Android release build: signing, AAB export, versioning scheme.
- Store listing: short and long description, PSX-style screenshots, feature
  graphic, a 30s trailer script.
- Check "Jailbrick" is free on Google Play / App Store and pick a fallback if not.
- Play Console internal test, then closed test, then production checklist.
- Privacy-light analytics: level start/win/lose, continue usage (no personal data).
- Live-ops plan: a weekly seeded "Daily Breakout" level, plus a schedule for a new
  world update.
Commit and tag v1.0.0.
```

---

## Section D — Time tracker

Rough estimate: **4–6 weeks** of evenings (~2 h) and weekends (~6 h/day), about
**60–90 hours** in total. Most of the time goes into reviewing and play-testing
what Claude builds, not typing code.

| Phase | Est. hours | Status | Notes |
|---|---|---|---|
| 0 — Setup | 1–2 | ☑ | Godot 4.7.2, GUT 9.7.1. Windows binary used locally instead of Linux headless |
| 1 — Proof of concept | 6–10 | ☑ | Reworked into depth levels mid-phase. Play-test: plays great, reached level 8 before it got hard |
| 2 — Depth curve + solver | 6–10 | ☑ | Sawtooth curve in `levels/depth_curve.tres`; bot median depth 5 from level 1, all 4 start targets pass in ~10 min. Restart balls 3→5 per level |
| 3 — Full content | 12–18 | ☐ | The biggest phase. Split it by world |
| 4 — Progression | 6–8 | ☐ | |
| 5 — PSX art + audio | 10–14 | ☐ | |
| 6 — Audit | 4–6 | ☐ | |
| 7 — UI/UX | 6–8 | ☐ | |
| 8 — Ads/IAP/licences | 4–6 | ☐ | Licence check for the Sewers pack |
| 9 — Release | 4–8 | ☐ | Store review times vary |
| **Total** | **59–90** | | |

### Open decisions

- **Engine:** Godot 4 has been chosen, so Claude Code can edit scenes as text.
  Revisit only if you strongly prefer Unity.
- **Asset packs:** add the exact pack names and links to `assets/README.md`.
- **Board direction:** launcher at the top with rows rising from below (as above).
  Flip it to the classic "bricks descend" layout in Phase 1 if it plays better.
