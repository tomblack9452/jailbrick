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

const DEFAULT_PATH := "res://levels/depth_curve.tres"

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
