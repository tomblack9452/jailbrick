class_name RowGenerator
extends RefCounted
## Seeded generator for the brick row that spawns at the bottom each turn.
## Phase 2 replaces the knobs here with proper difficulty parameters.

var rng := RandomNumberGenerator.new()
var seed_value := 0
var fill_chance := 0.5
var hp_start := 1 ## brick HP on turn 1
var hp_per_turn := 1.0
var double_chance := 0.2 ## chance a brick spawns with double HP
var pickup_chance := 0.8 ## chance the row has a +1 Ball


func _init(p_seed := 0) -> void:
	seed_value = p_seed
	rng.seed = p_seed


func hp_for_turn(turn: int) -> int:
	return hp_start + int(hp_per_turn * (turn - 1))


## Returns {"bricks": [[col, hp], ...], "pickup": col or -1}.
## Always leaves at least one column empty.
func generate(turn: int, columns: int) -> Dictionary:
	var cols: Array[int] = []
	for col in columns:
		if rng.randf() < fill_chance:
			cols.append(col)
	if cols.size() == columns:
		cols.remove_at(rng.randi_range(0, columns - 1))
	elif cols.is_empty():
		cols.append(rng.randi_range(0, columns - 1))

	var hp := hp_for_turn(turn)
	var bricks: Array = []
	for col in cols:
		bricks.append([col, hp * 2 if rng.randf() < double_chance else hp])

	var pickup := -1
	if rng.randf() < pickup_chance:
		var empty: Array[int] = []
		for col in columns:
			if not cols.has(col):
				empty.append(col)
		pickup = empty[rng.randi_range(0, empty.size() - 1)]
	return {"bricks": bricks, "pickup": pickup}


func clone() -> RowGenerator:
	var copy := RowGenerator.new(seed_value)
	copy.rng.state = rng.state
	copy.fill_chance = fill_chance
	copy.hp_start = hp_start
	copy.hp_per_turn = hp_per_turn
	copy.double_chance = double_chance
	copy.pickup_chance = pickup_chance
	return copy
