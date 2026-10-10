class_name LevelGenerator
extends RefCounted
## Seeded generator for the dig: each level is a block of LEVEL_ROWS rows.
##
## With a DepthCurve (levels/depth_curve.tres) the knobs below are set per
## level from the curve. Without one they stay fixed, which tests use.
##
## Rows are built as clumps with channels between them: a brick is likely to
## continue under one from the previous row, long runs get a gap punched in,
## and every row keeps a few empty columns. That leaves pockets and tight
## spaces for balls to get into. HP climbs with depth.
##
## With a curve, some bricks are special (B4) and some gaps hold special
## pickups (B5), from whatever the curve has introduced by that level, and the
## level's twist (B3) shapes it: Flood and Cache scale HP, Nest adds rat nests,
## Cache adds crates, and Warden levels get the guard.

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
var curve: DepthCurve = null

## Per-level content, set by _prepare() from the curve. Empty without one.
var _level := 1
var _twist := ""
var _special_chance := 0.0
var _special_pickup_chance := 0.0
var _brick_pool := []
var _drop_pool := []
var _row_pickup_pool := []

var _last_row: Array[bool] = []


func _init(p_seed := 0, p_curve: DepthCurve = null) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	curve = p_curve


func hp_at(level: int, row_in_level: int) -> int:
	if curve:
		return curve.hp_at(level, row_in_level)
	return hp_base + int(hp_per_level * (level - 1) + hp_per_row * row_in_level)


## Returns LEVEL_ROWS rows, top first. Each is {"bricks": [Brick, ...],
## "pickups": [Pickup, ...]} with each thing's row set to 0: the caller
## places the row on the board.
func generate_level(level: int, columns: int) -> Array[Dictionary]:
	_prepare(level)
	var out: Array[Dictionary] = []
	var hp_scale := curve.twist_hp_at(level) if curve else 1.0
	for row_in_level in LEVEL_ROWS:
		out.append(generate_row(maxi(1, int(hp_at(level, row_in_level) * hp_scale)), columns))
	if _twist == "warden":
		_add_warden(out, columns)
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

	var bricks: Array[Brick] = []
	var gaps: Array[int] = []
	for col in columns:
		if filled[col]:
			var brick_hp := hp * 2 if rng.randf() < double_chance else hp
			bricks.append(_make_brick(col, brick_hp, hp))
		else:
			gaps.append(col)

	var pickups: Array[Pickup] = []
	if rng.randf() < pickup_chance:
		pickups.append(Pickup.new(Pickup.Type.EXTRA_BALL, _take_gap(gaps)))
	if not _row_pickup_pool.is_empty() and gaps.size() > 0 and rng.randf() < _special_pickup_chance:
		pickups.append(_make_pickup(_pick(_row_pickup_pool), _take_gap(gaps)))
	return {"bricks": bricks, "pickups": pickups}


## Reads the curve's content for `level`. Without a curve, everything is stone.
func _prepare(level: int) -> void:
	_level = level
	if curve == null:
		return
	curve.apply(self, level)
	_twist = curve.twist_at(level)
	_special_chance = curve.special_chance_at(level)
	_special_pickup_chance = curve.special_pickup_chance_at(level)
	_brick_pool = curve.brick_pool(level)
	_drop_pool = curve.pickup_pool(level, true)
	_row_pickup_pool = curve.pickup_pool(level, false)


## A brick for a filled cell: stone, or a special one by the level's odds.
## `row_hp` is the row's base HP (before any double).
func _make_brick(col: int, hp: int, row_hp: int) -> Brick:
	if curve == null:
		return Brick.new(Brick.Type.STONE, hp, col)
	var type := Brick.Type.STONE
	if _twist == "nest" and rng.randf() < curve.nest_chance:
		type = Brick.Type.NEST
	elif _twist == "cache" and rng.randf() < curve.cache_crate_chance:
		type = Brick.Type.CRATE
	elif not _brick_pool.is_empty() and rng.randf() < _special_chance:
		type = _pick(_brick_pool)
	if type == Brick.Type.SLUDGE:
		return Brick.new(type, 1, col)
	var brick := Brick.new(type, hp, col)
	if type == Brick.Type.CRATE:
		brick = Brick.new(type, maxi(1, int(row_hp * curve.crate_hp)), col)
		if not _drop_pool.is_empty():
			var drop := _make_pickup(_pick(_drop_pool), col)
			brick.drop = drop.type
			brick.drop_data = drop.data
	return brick


func _make_pickup(type: Pickup.Type, col: int) -> Pickup:
	var data := 0
	if type == Pickup.Type.LASER:
		data = Pickup.VERTICAL if rng.randf() < 0.5 else Pickup.HORIZONTAL
	return Pickup.new(type, col, 0, data)


## Puts the Warden guard (2 wide) on the curve's row, clearing room for it.
func _add_warden(rows: Array[Dictionary], columns: int) -> void:
	var row: Dictionary = rows[clampi(curve.warden_row, 0, rows.size() - 1)]
	var col := rng.randi_range(0, columns - 2)
	var level_hp := curve.hp_at(_level, 0)
	for brick: Brick in row["bricks"].duplicate():
		if brick.col >= col - brick.width + 1 and brick.col <= col + 1:
			row["bricks"].erase(brick)
	for pickup: Pickup in row["pickups"].duplicate():
		if pickup.col == col or pickup.col == col + 1:
			row["pickups"].erase(pickup)
	var guard := Brick.new(Brick.Type.GUARD, maxi(1, int(level_hp * curve.warden_hp)), col, 0, 2)
	guard.minion_hp = maxi(1, int(level_hp * curve.warden_minion_hp))
	row["bricks"].append(guard)


## A random gap, removed from the list so nothing else lands there.
func _take_gap(gaps: Array[int]) -> int:
	return gaps.pop_at(rng.randi_range(0, gaps.size() - 1))


## Picks from [[value, weight], ...] by weight.
func _pick(pool: Array) -> Variant:
	var total := 0.0
	for entry in pool:
		total += entry[1]
	var roll := rng.randf() * total
	for entry in pool:
		roll -= entry[1]
		if roll < 0.0:
			return entry[0]
	return pool.back()[0]


func clone() -> LevelGenerator:
	var copy := LevelGenerator.new(seed_value, curve)
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
