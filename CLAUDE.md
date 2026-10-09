# Jailbrick — Project Context

> This file is read automatically by Claude Code at the start of every session.
> It is Section A of `BUILD-PROMPTS.md`. If you change the design, update both.

## Pitch

**Jailbrick** is a turn-based brick-breaker escape game with a low-poly PSX look.
You're a prisoner breaking out. Each level has a **lock** (a cell door, grate or
gate) buried in a wall of numbered bricks. Aim, fire a volley of balls, and break
the lock before the rising brick rows box you in. Escape through the sewers, woods,
scrapyard and somewhere stranger, collect charms and upgrades as you go, and never
get forced to watch an ad.

## Design pillars

1. **Escape, not endurance.** Every level has a clear exit: break the lock. Levels
   end with a win or a loss, never an endless grind.
2. **Readable tension.** You can always see how many turns are left before the walls
   reach you. Losses should feel fair, so you think "one more go".
3. **Earned power.** Everything that makes you stronger can be earned by playing.
   Nothing is pay-to-win, and every level must be beatable without spending.
4. **Respect the player.** Ads only play when the player chooses them (rewarded),
   there are no interstitials, no energy timers, and no loot boxes. There is one
   optional Supporter Pack.
5. **Grimy PSX charm.** Wobbly vertices, chunky pixels, fog and a little unsettling.
   It should look like a lost 1998 demo disc.

## Tech stack

- **Engine:** Godot 4 (latest stable 4.x), **GDScript**. All scenes (`.tscn`) and
  resources (`.tres`) stay text so Claude Code can edit them directly.
- **Targets:** Android first, then iOS. Portrait, one-thumb play.
- **Renderer:** Mobile or Compatibility. Render the 3D world into a low-res
  SubViewport (~320×568) and upscale it with nearest filtering. Draw the UI at full
  resolution on top.
- **Ball movement:** custom deterministic code (fixed timestep, no RigidBody
  physics) so the headless solver bot can replay levels exactly.
- **Level data:** Godot `Resource` files (`res://levels/*.tres`), plus a seeded
  procedural generator.
- **Tests:** GUT (Godot Unit Test), run headless with `godot --headless`.
- **Monetisation:** AdMob rewarded ads and Google Play Billing / StoreKit through
  maintained Godot plugins. These are added in Phase 8 only.

## PSX look recipe

- Low-res render target, nearest-neighbour upscale, no anti-aliasing
- Vertex snapping to a coarse grid in the vertex shader (wobble)
- Affine texture mapping (warped textures), small 64–128px textures, nearest filtering
- Colour reduced to 15-bit (5 bits per channel) with ordered (Bayer) dithering
- Distance fog in a colour that suits each world, short draw distance
- Low-poly models (under ~500 tris for props), vertex colours for lighting where possible
- UI: chunky bitmap-style font, hard drop shadows, CRT/VHS overlay that can be turned off

## Lessons from the reference games

Reference games: *Brick Out Shoot*, *Break Bricks*, *Bricks Breaker RPG*,
*Brick Breaker Shoot Blast*.

- **Biggest complaint across all four:** forced interstitial ads and pay-to-win
  boosters. Jailbrick avoids both.
- **Bricks Breaker RPG has the best rating (~4.8★)** because ads are rewarded-only
  and progression can be earned. Copy that approach.
- The aim-and-volley ("Ballz") loop is satisfying. Keep the aim line clear and the
  volley fast, and add a fast-forward button.
- Endless modes get stale, so levels with a goal (the lock) keep things fresh.

## Working rules for Claude Code

- Work one phase at a time, following the prompts in `BUILD-PROMPTS.md` Section C.
- Keep scenes and resources text-based. Don't commit binary `.scn`/`.res` files.
- Game logic (board, turns, bricks) lives in plain scripts that can run with no
  rendering, so the solver bot and tests can drive it headless.
- Run the GUT tests before each commit.
- When a design decision changes, update `BUILD-PROMPTS.md` and this file.
