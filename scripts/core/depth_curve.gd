class_name DepthCurve
extends Resource
## How hard each level of the dig is. LevelGenerator reads its knobs from here.
##
## The curve is a sawtooth in bands of `band_size` levels. `band_ramp` gives the
## pressure (0 to 1) at each level of a band: a breather at the start, then a
## ramp to the band's peak. Each knob is a Vector2 of (breather, peak) values
## for the first band, plus a drift per band so later bands start and end harder.
##
## The solver bot (tools/solver.gd) checks its median depth against
## `target_depth` and fails if it falls outside.
##
## It also holds the content of the dig: which special bricks and pickups are
## in play from which level (B9's introduction table), the band twists (B3),
## and the world bands (B9) with their names, tints and signature bricks.

const DEFAULT_PATH := "res://levels/depth_curve.tres"
const BRICK_NAMES := {
	"iron": Brick.Type.IRON, "crate": Brick.Type.CRATE, "gas": Brick.Type.GAS,
	"nest": Brick.Type.NEST, "sludge": Brick.Type.SLUDGE,
}
const PICKUP_NAMES := {
	"ball": Pickup.Type.EXTRA_BALL, "coin": Pickup.Type.COIN, "splitter": Pickup.Type.SPLITTER,
	"laser": Pickup.Type.LASER, "freeze": Pickup.Type.FREEZE,
}

@export var band_size := 5
## Pressure at each level of a band, breather first. Needs `band_size` entries.
@export var band_ramp := PackedFloat32Array([0.0, 0.35, 0.6, 0.85, 1.0])

@export_group("Clumps")
## Chance an empty column starts a new clump.
@export var fill_chance := Vector2(0.24, 0.33)
@export var fill_chance_per_band := 0.01
## Chance a clump carries on from the row above.
@export var keep_chance := Vector2(0.56, 0.66)
@export var keep_chance_per_band := 0.01
## Fewest empty columns in a row. Rounded.
@export var min_gaps := Vector2(5.0, 3.0)
## Longest unbroken run of bricks in a row. Rounded.
@export var max_run := Vector2(3.0, 5.0)

@export_group("HP")
## HP of the first row of level 1.
@export var hp_base := 1
## HP added to the first row on entering a level.
@export var hp_step := Vector2(4.0, 10.5)
@export var hp_step_per_band := 1.0
## Extra HP per row deeper within a level.
@export var hp_per_row := Vector2(0.8, 1.2)
## Chance a brick spawns with double HP.
@export var double_chance := Vector2(0.06, 0.16)
@export var double_chance_per_band := 0.01

@export_group("Pickups")
## Chance a row has a +1 Ball.
@export var pickup_chance := Vector2(0.42, 0.3)
@export var pickup_chance_per_band := -0.01

@export_group("Specials")
## Chance a generated brick is a special brick rather than stone.
@export var special_chance := Vector2(0.08, 0.16)
@export var special_chance_per_band := 0.005
## Relative odds of each special brick once it's introduced. Keys are names
## from BRICK_NAMES.
@export var brick_weights := {"crate": 3.0, "sludge": 1.5, "nest": 0.8, "iron": 2.0, "gas": 1.2}
## Relative odds of each pickup a crate drops, or (without "ball") a row's
## special pickup. Keys are names from PICKUP_NAMES.
@export var pickup_weights := {"ball": 2.0, "coin": 3.0, "freeze": 1.0, "splitter": 1.5, "laser": 1.5}
## Chance a row gets a special pickup (not +1 Ball) in one of its gaps.
@export var special_pickup_chance := Vector2(0.1, 0.06)
## Level each special brick, pickup and twist first appears. Anything missing
## is in from level 1.
@export var introductions := {"coin": 1, "crate": 2, "freeze": 3, "sludge": 4, "splitter": 5,
	"nest": 7, "flood": 8, "laser": 9, "warden": 10, "iron": 13, "gas": 17, "cache": 18}
## Crate HP as a share of the row's.
@export var crate_hp := 0.6

@export_group("Twists")
## Bands before this one (counting from 0) have no twist.
@export var first_twist_band := 1
## Twist for each band from then on, cycling: "flood", "nest" or "cache".
@export var twist_cycle := PackedStringArray(["flood", "nest", "cache"])
## Which level of a band (counting from 0) gets the twist.
@export var twist_slot := 2
## A Warden boss level every this many levels (the end of each world).
@export var warden_every := 10
## Flood: rows per rise, and HP multiplier.
@export var flood_rise := 2
@export var flood_hp := 0.6
## Nest: chance each brick is a rat nest.
@export var nest_chance := 0.14
## Cache: chance each brick is a crate, and HP multiplier.
@export var cache_crate_chance := 0.35
@export var cache_hp := 1.2
## Warden: guard HP and minion HP as multiples of the level's first-row HP,
## and the row of the level (counting from 0) it starts on.
@export var warden_hp := 8.0
@export var warden_minion_hp := 0.5
@export var warden_row := 3

@export_group("Worlds")
## Levels per world. The last world carries on forever.
@export var world_size := 10
## One per world: {"name", "tint" (greybox backdrop colour), "signature"
## (brick names that spawn more often), "specials" (special-chance multiplier),
## and optionally "cycle_tints": true to borrow earlier worlds' tints per level}.
@export var worlds := []
## How much more often a world's signature bricks spawn.
@export var signature_weight := 3.0

@export_group("Solver targets")
## Start level -> Vector2i(min, max) median depth the solver bot should reach.
@export var target_depth := {}


## Which band a level is in, counting from 0.
func band_of(level: int) -> int:
	return (maxi(level, 1) - 1) / band_size


## 0 at a band's breather, 1 at its peak.
func pressure(level: int) -> float:
	var index := (maxi(level, 1) - 1) % band_size
	return band_ramp[mini(index, band_ramp.size() - 1)]


func fill_chance_at(level: int) -> float:
	return clampf(_knob(fill_chance, fill_chance_per_band, level), 0.05, 0.6)


func keep_chance_at(level: int) -> float:
	return clampf(_knob(keep_chance, keep_chance_per_band, level), 0.1, 0.9)


func min_gaps_at(level: int) -> int:
	return maxi(1, roundi(_knob(min_gaps, 0.0, level)))


func max_run_at(level: int) -> int:
	return maxi(1, roundi(_knob(max_run, 0.0, level)))


func hp_per_row_at(level: int) -> float:
	return maxf(0.0, _knob(hp_per_row, 0.0, level))


func double_chance_at(level: int) -> float:
	return clampf(_knob(double_chance, double_chance_per_band, level), 0.0, 0.5)


func pickup_chance_at(level: int) -> float:
	return clampf(_knob(pickup_chance, pickup_chance_per_band, level), 0.1, 0.8)


## HP of the first row of `level`: the sum of every level's step so far.
func level_hp(level: int) -> float:
	var hp := float(hp_base)
	for l in range(2, level + 1):
		hp += maxf(0.0, _knob(hp_step, hp_step_per_band, l))
	return hp


func hp_at(level: int, row_in_level: int) -> int:
	return int(level_hp(level) + hp_per_row_at(level) * row_in_level)


func special_chance_at(level: int) -> float:
	var world: Dictionary = world_at(level)
	var chance := _knob(special_chance, special_chance_per_band, level) * float(world.get("specials", 1.0))
	return clampf(chance, 0.0, 0.6)


func special_pickup_chance_at(level: int) -> float:
	return clampf(_knob(special_pickup_chance, 0.0, level), 0.0, 0.5)


func is_introduced(thing: String, level: int) -> bool:
	return level >= int(introductions.get(thing, 1))


## The twist on `level`: "warden", "flood", "nest", "cache" or "" for none.
## A twist that isn't introduced yet falls back to flood (or none).
func twist_at(level: int) -> String:
	if warden_every > 0 and level % warden_every == 0 and is_introduced("warden", level):
		return "warden"
	if twist_cycle.is_empty() or (maxi(level, 1) - 1) % band_size != twist_slot \
			or band_of(level) < first_twist_band:
		return ""
	var twist := twist_cycle[(band_of(level) - first_twist_band) % twist_cycle.size()]
	if twist == "" or is_introduced(twist, level):
		return twist
	return "flood" if is_introduced("flood", level) else ""


## Rows the pile rises each turn on `level`.
func rise_at(level: int) -> int:
	return flood_rise if twist_at(level) == "flood" else 1


## HP multiplier from the level's twist.
func twist_hp_at(level: int) -> float:
	match twist_at(level):
		"flood": return flood_hp
		"cache": return cache_hp
	return 1.0


func world_index(level: int) -> int:
	if worlds.is_empty():
		return 0
	return mini((maxi(level, 1) - 1) / world_size, worlds.size() - 1)


func world_at(level: int) -> Dictionary:
	return {} if worlds.is_empty() else worlds[world_index(level)]


func world_name(level: int) -> String:
	return str(world_at(level).get("name", ""))


## The greybox tint for `level`'s world. A world with "cycle_tints" borrows
## the earlier worlds' tints in turn, one per level.
func world_tint(level: int) -> Color:
	var world := world_at(level)
	if world.get("cycle_tints", false) and world_index(level) > 0:
		return worlds[(maxi(level, 1) - 1) % world_index(level)].get("tint", Color.BLACK)
	return world.get("tint", Color(0.12, 0.13, 0.13))


## [[Brick.Type, weight], ...] for the special bricks in play on `level`,
## with the world's signature bricks boosted.
func brick_pool(level: int) -> Array:
	var signature: Array = world_at(level).get("signature", [])
	var pool := []
	for name in brick_weights:
		if BRICK_NAMES.has(name) and is_introduced(name, level):
			var weight := float(brick_weights[name]) * (signature_weight if signature.has(name) else 1.0)
			pool.append([BRICK_NAMES[name], weight])
	return pool


## [[Pickup.Type, weight], ...] for the pickups in play on `level`. Rows only
## use the specials (`with_ball` false); crates can also drop a +1 Ball.
func pickup_pool(level: int, with_ball: bool) -> Array:
	var pool := []
	for name in pickup_weights:
		if PICKUP_NAMES.has(name) and is_introduced(name, level) and (with_ball or name != "ball"):
			pool.append([PICKUP_NAMES[name], float(pickup_weights[name])])
	return pool


## Sets the generator's knobs for `level`.
func apply(generator: LevelGenerator, level: int) -> void:
	generator.fill_chance = fill_chance_at(level)
	generator.keep_chance = keep_chance_at(level)
	generator.min_gaps = min_gaps_at(level)
	generator.max_run = max_run_at(level)
	generator.hp_per_row = hp_per_row_at(level)
	generator.double_chance = double_chance_at(level)
	generator.pickup_chance = pickup_chance_at(level)


## The (min, max) median depth the solver should reach from `start_level`,
## or Vector2i.ZERO if there's no target for it.
func target_for(start_level: int) -> Vector2i:
	return target_depth.get(start_level, Vector2i.ZERO)


static func load_default() -> DepthCurve:
	return load(DEFAULT_PATH)


func _knob(values: Vector2, per_band: float, level: int) -> float:
	return lerpf(values.x, values.y, pressure(level)) + per_band * band_of(level)
