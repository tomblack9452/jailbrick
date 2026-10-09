class_name RowGenerator
extends RefCounted
## Seeded generator for the brick row that spawns at the bottom each turn.
##
## Rows are built as clumps with channels between them: a brick is likely to
## continue under one from the previous row, long runs get a gap punched in,
## and every row keeps a few empty columns. That leaves pockets and tight
## spaces for balls to get into. Phase 2 adds proper difficulty parameters.

var rng := RandomNumberGenerator.new()
var seed_value := 0
var fill_chance := 0.25 ## chance an empty column starts a new clump
var keep_chance := 0.6 ## chance a clump carries on from the row above
var max_run := 4 ## longest unbroken run of bricks in a row
var min_gaps := 4 ## fewest empty columns in a row
var hp_start := 1 ## brick HP on turn 1
var hp_per_turn := 1.0
var double_chance := 0.15 ## chance a brick spawns with double HP
var pickup_chance := 0.8 ## chance the row has a +1 Ball

var _last_row: Array[bool] = []


func _init(p_seed := 0) -> void:
	seed_value = p_seed
	rng.seed = p_seed


func hp_for_turn(turn: int) -> int:
	return hp_start + int(hp_per_turn * (turn - 1))


## Returns {"bricks": [[col, hp], ...], "pickup": col or -1}.
func generate(turn: int, columns: int) -> Dictionary:
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

	var hp := hp_for_turn(turn)
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


func clone() -> RowGenerator:
	var copy := RowGenerator.new(seed_value)
	copy.rng.state = rng.state
	copy.fill_chance = fill_chance
	copy.keep_chance = keep_chance
	copy.max_run = max_run
	copy.min_gaps = min_gaps
	copy.hp_start = hp_start
	copy.hp_per_turn = hp_per_turn
	copy.double_chance = double_chance
	copy.pickup_chance = pickup_chance
	copy._last_row = _last_row.duplicate()
	return copy
