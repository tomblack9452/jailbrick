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

### B1. Fantasy and framing

You're an inmate of somewhere that doesn't appear on maps. You get out one locked
door at a time. Each level is a single locked barrier (cell door, drain grate,
padlocked fence, the strange humming hatch) packed in with numbered bricks. Break
the lock and you squeeze through to the next one. If the walls close in first,
you're dragged back.

### B2. Board and turn loop

- **Board:** portrait grid, **7 columns** wide. Your **launcher** (the hatch you
  crawl from) sits on the **top line**. Brick rows **rise from the bottom**, like
  sludge filling the room.
- **Turn:**
  1. **Aim.** Drag to aim. A dotted guide line shows the first bounce, or two
     bounces with an upgrade.
  2. **Fire.** Release to fire your volley: *N* balls in quick succession. Balls
     bounce off walls and bricks. Each hit takes 1 HP (times your damage
     multiplier) from the brick's number.
  3. **Return.** Balls return when they leave through the top line. The first
     ball back sets the next launch position.
  4. **Rise.** Every brick moves up one row and a new row spawns at the bottom.
  5. **Check.** If any brick reaches the **danger line** (the row just below the
     launcher), you lose, though you can continue (see B8).
- **Win:** reduce the **lock** to 0 HP. The lock is a 1×1 or 2×1 brick with large
  HP, a distinct model, and often shielded (B4).
- **Turn counter:** the HUD always shows "rows until trapped" so the pressure is readable.
- **Fast-forward:** hold to speed up the volley (×2, ×4). Add a recall button after 3 seconds.

### B3. Level types (6)

| Type | Twist | Example |
|---|---|---|
| **Breakout** (standard) | The lock sits mid-pile and rows rise every turn | Most levels |
| **Flood** | Rows rise 2 per turn, but the lock has lower HP | Sewer pipes bursting |
| **Vault** | The lock is chained. Break every **chain brick** first to make it vulnerable | Mid/late world |
| **Warden** (boss) | The lock is carried by a moving **guard brick** that shuffles columns and spawns minions | End of each world |
| **Lockdown** (survival) | No lock at first. Survive *X* turns, then the lock drops in | Pacing break |
| **Puzzle** | Fixed balls, no rising, limited shots. Break the lock in exactly *N* volleys | Optional side cells |

### B4. Bricks

| Brick | Behaviour |
|---|---|
| **Stone** | Basic. Shows its HP |
| **Iron** | Takes half damage (round up) |
| **Crate** | Drops a pickup when broken |
| **Gas can** | Explodes for damage on the 8 neighbours |
| **Rat nest** | Every 2 turns, spawns a 1 HP stone brick in an empty adjacent cell |
| **Chain** | Linked to the lock. The lock is invulnerable while any chain stands |
| **Sludge** | Slows balls that pass near it. Doesn't block |
| **Shield** | Sits next to the lock and absorbs the first hit of each volley |
| **Guard** (boss) | Moves 1 column per turn. Carries or protects the lock |

### B5. Pickups (collected by touching them with a ball)

- **+1 Ball** (permanent for this level)
- **Coin** (currency)
- **Splitter:** the next ball to pass through splits into 3
- **Laser bar:** a one-shot horizontal or vertical beam that deals 1 damage per brick in its line
- **Freeze:** the next "Rise" step is skipped
- **Key shard:** collect 3 across a world to unlock its bonus **Puzzle** cell

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

- **Lockpick:** +50% damage to locks and chains
- **Rat Tail:** balls bounce off the top line once before returning
- **Rusty Spring:** the first ball of each volley is ×2 size
- **Ghost Ball:** 1 ball per volley passes through Iron bricks
- **Tally Marks:** +1 ball each time you break 10 bricks in one volley
- **Contraband:** Crates drop 2 pickups
- **Bent Spoon:** after each rise, deal 1 damage to the bottom row
- **Static Charm (World 4+):** random brick numbers glitch down by 1 each turn

Charms drop from bosses, from Puzzle cells, and as one-time rewards for world milestones.

### B8. Fail state and continues

- On a loss: **continue once** by watching a rewarded ad (this clears the bottom 3
  rows), or retry for free. There is never a forced ad.
- Retrying is always free and instant. There are no lives or energy.

### B9. Worlds (5)

Each world maps to one PSX asset pack. Add the asset links in `assets/README.md`
when they're imported.

| # | World | Escape story beat | Asset pack | Fog/palette | Signature brick |
|---|---|---|---|---|---|
| 1 | **The Drains** | Out through the cell's floor grate into the sewers | PSX Sewers *(licence to verify, Phase 8)* | Green-grey, drippy | Sludge, Rat nest |
| 2 | **Black Pines** | Out of the outflow pipe into night woods | PSX Trees | Blue-black, torch-lit | Crate-heavy |
| 3 | **Scrap Row** | A scrapyard full of wrecked cars between you and the road | PSX Cars / junk | Rust orange, sodium lights | Iron, Gas can |
| 4 | **The Hum** | Something isn't right. A place that shouldn't exist | PSX "weird" pack | Purple static, heavy dither | Glitch variants |
| 5 | **Lockdown** (finale) | Back at the start, but you know the way out now | Remix of all packs | Shifts per level | Everything + final Warden |

- **Levels per world:** 20 (16 main + 1 Warden boss + 3 optional Puzzle cells) = **100 total**.
- **Difficulty curve:** a sawtooth. It ramps within a world, eases at the start
  of the next, and new brick types are introduced one at a time.

### B10. Monetisation (ethical, final)

- **Rewarded ads only.** Watch an ad, if you choose to, for: continue once, double
  coins at level end, or the daily free crate.
- **Supporter Pack (one-time, ~£3.99):** grants every rewarded-ad reward
  automatically without the ad, an exclusive cosmetic ball and launcher skin, and
  a thank-you in the credits. It adds **no** extra power beyond what ads already give.
- **Never:** interstitials, banners, energy, loot boxes, paid boosters, or currency packs.

---

## Section C — Phase prompts

Paste one prompt per new session. Each assumes `CLAUDE.md` has been loaded.

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

- scripts/core/: Board (7 columns), Brick (HP, type), Lock, Ball simulation with
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

### Phase 2 — Levels, generator and solver bot

```
Phase 2 of Jailbrick.

1. Level format: a LevelData Resource (rows, brick types/HP, lock position/HP,
   level type from B3, rise rate, seed for spawned rows). Load from levels/*.tres.
2. A seeded procedural row generator with difficulty parameters.
3. Hand-make 10 levels covering Breakout, Flood and Lockdown types.
4. A headless solver bot (tools/solver.gd, run via godot --headless):
   - Samples aim angles (e.g. 64 per turn) with a greedy + short lookahead
     policy, using the core sim only.
   - Plays each level K times with a baseline loadout (no paid anything, upgrades
     at the level the curve expects at that point) and reports win rate,
     average turns, and closest-loss margin.
   - Fails (non-zero exit) if any level is under 60% win rate.
5. Write a report to tools/reports/solver-latest.md.
Commit levels, generator, bot and the first report.
```

### Phase 3 — Full content build

```
Phase 3 of Jailbrick. Implement all of Section B3–B5:
- All 6 level types, including the Warden boss (moving guard brick + minions).
- All bricks in B4 and all pickups in B5, each with GUT tests.
- Author the 100 levels across 5 worlds (B9), using the generator for drafts
  and hand-tuning the result. Introduce one new mechanic at a time.
- Run the solver bot on every level and fix anything under 60%.
Commit in chunks (per world). Keep greybox visuals, art comes in Phase 5.
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
  brick and lock models per world (keep bricks readable: the HP number always
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
| 1 — Proof of concept | 6–10 | ☐ | Is it fun in greybox? If not, stop and fix here |
| 2 — Levels + solver | 6–10 | ☐ | |
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
