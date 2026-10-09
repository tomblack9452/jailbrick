class_name LevelGenerator
extends RefCounted
## Seeded generator for the dig: each level is a block of LEVEL_ROWS rows.
##
## Tuned with a throwaway greedy bot (7 aims a turn, sees each outcome): it
## reaches level 5-7 by turn 60, while random aiming dies on level 1-2.
##
## Rows are built as clumps with channels between them: a brick is likely to
## continue under one from the previous row, long runs get a gap punched in,
## and every row keeps a few empty columns. That leaves pockets and tight
## spaces for balls to get into. HP climbs with depth.

const LEVEL_ROWS := 10

var rng := RandomNumberGenerator.new()
var seed_value := 0
var fill_chance := 0.28 ## chance an empty column starts a new clump
var keep_chance := 0.62 ## chance a clump carries on from the row above
var max_run := 4 ## longest unbroken run of bricks in a row
var min_gaps := 4 ## fewest empty columns in a row
var hp_base := 1 ## HP of the first row of level 1
var hp_per_row := 1.0 ## extra HP per row deeper within a level
var hp_per_level := 8.0 ## extra HP per level
var double_chance := 0.12 ## chance a brick spawns with double HP
var pickup_chance := 0.35 ## chance a row has a +1 Ball

var _last_row: Array[bool] = []


func _init(p_seed := 0) -> void:
	seed_value = p_seed
	rng.seed = p_seed


func hp_at(level: int, row_in_level: int) -> int:
	return hp_base + int(hp_per_level * (level - 1) + hp_per_row * row_in_level)


## Returns LEVEL_ROWS rows, top first. Each is {"bricks": [[col, hp], ...], "pickup": col or -1}.
func generate_level(level: int, columns: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row_in_level in LEVEL_ROWS:
		out.append(generate_row(hp_at(level, row_in_level), columns))
	return out


## One row of clumps. Exposed so tests can check the shape rules.
func generate_row(hp: int, columns: int) -> Dictionary:
	if _last_row.size() != columns:
		_last_row.resize(columns)
		_last_row.fill(false)

	var filled: Array[bool] = []
	for col in columns:
		filled.append(rng.randf() < (keep_chance if _last_row[col] else fill_chance))

	var run := 0
	for col in columns:
		run = run + 1 if filled[col] else 0
		if run > max_run:
			filled[col] = false
			run = 0

	var empty := filled.count(false)
	while empty < min_gaps:
		var col := rng.randi_range(0, columns - 1)
		if filled[col]:
			filled[col] = false
			empty += 1
	if empty == columns:
		filled[rng.randi_range(0, columns - 1)] = true
	_last_row = filled

	var bricks: Array = []
	var gaps: Array[int] = []
	for col in columns:
		if filled[col]:
			bricks.append([col, hp * 2 if rng.randf() < double_chance else hp])
		else:
			gaps.append(col)

	var pickup := -1
	if rng.randf() < pickup_chance:
		pickup = gaps[rng.randi_range(0, gaps.size() - 1)]
	return {"bricks": bricks, "pickup": pickup}


func clone() -> LevelGenerator:
	var copy := LevelGenerator.new(seed_value)
	copy.rng.state = rng.state
	copy.fill_chance = fill_chance
	copy.keep_chance = keep_chance
	copy.max_run = max_run
	copy.min_gaps = min_gaps
	copy.hp_base = hp_base
	copy.hp_per_row = hp_per_row
	copy.hp_per_level = hp_per_level
	copy.double_chance = double_chance
	copy.pickup_chance = pickup_chance
	copy._last_row = _last_row.duplicate()
	return copy
