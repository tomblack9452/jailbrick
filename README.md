# Jailbrick

A turn-based brick-breaker escape game with a low-poly PSX look, built in Godot 4.
Dig as deep as you can before the walls close in.

- [`CLAUDE.md`](./CLAUDE.md): project context (pitch, pillars, tech, art recipe)
- [`BUILD-PROMPTS.md`](./BUILD-PROMPTS.md): full game design and the phase-by-phase build prompts

**Status:** Phase 3 done: every non-parked brick and pickup, band twists (Flood,
Nest, Cache, Warden boss) and 10-level worlds, all in greybox and driven by
`levels/depth_curve.tres`. Next step is Phase 4 (progression and saves).

## Getting started

Requires **Godot 4.7** (standard build, not .NET). Get it from
[godotengine.org](https://godotengine.org/download) or drop the binary into
`tools/godot/` (gitignored) so the scripts below find it.

### Open in the editor

1. Launch Godot and choose **Import**.
2. Select this folder's `project.godot`.
3. The GUT plugin is already enabled. Its panel sits at the bottom of the editor.

### Run the game

Press **F5** in the editor, or from the command line:

```bash
godot --path .
```

On desktop the window opens at 540×960 (half size). The game itself is laid out
at 1080×1920 portrait and stretches to fit.

**Controls (greybox):** hold the left mouse button below the hatch to aim,
release to fire. Right-click cancels the aim. Hold **Space** (or the `>>` button)
to fast-forward, **Q** recalls the volley after 3 seconds, and **R** restarts from
level 1. Coins and your best level save to `user://progress.json`; delete it to reset.

### Run tests headless

```bash
./tools/run_tests.sh
```

This uses `$GODOT` if it's set, otherwise the first Godot binary in `tools/godot/`,
otherwise `godot` on your PATH. It refreshes the `.godot/` import cache first so
new `class_name` scripts are picked up. Any extra arguments go straight to GUT, for example
`./tools/run_tests.sh -gselect=test_smoke`.

Or call GUT directly:

```bash
godot --headless --import --path .
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

Test settings live in `.gutconfig.json`. Tests are in `tests/` and named `test_*.gd`.

## Layout

| Folder | What goes there |
|---|---|
| `scenes/` | `.tscn` scenes (text only) |
| `scripts/core/` | Pure game logic: board, turns, bricks, ball sim. No nodes, runs headless |
| `scripts/view/` | Nodes that render the core state |
| `levels/` | `LevelData` resources (`.tres`) |
| `shaders/` | PSX shaders (`.gdshader`) |
| `assets/` | Imported art and audio, one folder per world |
| `ui/` | Menus, HUD, fonts, themes |
| `tests/` | GUT tests |
| `tools/` | Scripts, solver bot, reports. `tools/godot/` holds local binaries (ignored) |
| `addons/gut/` | GUT 9.7.1 (vendored) |
