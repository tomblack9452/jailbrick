class_name Board
extends RefCounted
## The playfield grid. Column 0 is on the left. Row 0 is the danger row just
## under the launcher, and rows count downwards. Bricks rise towards row 0.
##
## In board space a cell (col, row) covers x in [col, col + 1] and
## y in [row, row + 1], with y pointing down.
##
## Bricks and pickups may sit below the floor (row >= rows). They're the next
## part of the dig: out of sight and out of reach until the board scrolls up.
##
## Sludge isn't solid, so it lives in its own list and grid: balls pass through
## it, and it never counts for clearing a level or getting trapped.

const COLUMNS := 15
const DEFAULT_ROWS := 22
const DANGER_ROW := 0

var columns := COLUMNS
var rows := DEFAULT_ROWS
var bricks: Array[Brick] = []
var sludge: Array[Brick] = []
var pickups: Array[Pickup] = []
## Things that happened this volley that the view can show (blasts, beams).
## Each is a Dictionary with a "kind". TurnController clears it every volley.
var effects: Array[Dictionary] = []

var _next_id := 1
var _cells: Array[Brick] = []
var _pickup_cells: Array[Pickup] = []
var _sludge_cells: Array[Brick] = []


func _init(p_rows := DEFAULT_ROWS, p_columns := COLUMNS) -> void:
	rows = p_rows
	columns = p_columns
	_cells.resize(rows * columns)
	_pickup_cells.resize(rows * columns)
	_sludge_cells.resize(rows * columns)


func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < columns and row >= 0 and row < rows


## The brick in a visible cell, or null. Bricks below the floor aren't returned.
func brick_at(col: int, row: int) -> Brick:
	if not in_bounds(col, row):
		return null
	return _cells[row * columns + col]


func pickup_at(col: int, row: int) -> Pickup:
	if in_bounds(col, row):
		return _pickup_cells[row * columns + col]
	for pickup in pickups:
		if pickup.col == col and pickup.row == row:
			return pickup
	return null


func sludge_at(col: int, row: int) -> Brick:
	if not in_bounds(col, row):
		return null
	return _sludge_cells[row * columns + col]


func is_free(col: int, row: int) -> bool:
	return in_bounds(col, row) and brick_at(col, row) == null and pickup_at(col, row) == null \
		and sludge_at(col, row) == null


func add_brick(brick: Brick) -> Brick:
	for i in brick.width:
		var col := brick.col + i
		assert(not in_bounds(col, brick.row) or is_free(col, brick.row), "cell (%d, %d) is taken" % [col, brick.row])
	brick.id = _next_id
	_next_id += 1
	if brick.is_solid():
		bricks.append(brick)
		_fill(brick, brick)
	else:
		sludge.append(brick)
		_fill_sludge(brick, brick)
	return brick


func add_pickup(pickup: Pickup) -> Pickup:
	assert(not in_bounds(pickup.col, pickup.row) or is_free(pickup.col, pickup.row), "cell (%d, %d) is taken" % [pickup.col, pickup.row])
	pickup.id = _next_id
	_next_id += 1
	pickups.append(pickup)
	_fill_pickup(pickup, pickup)
	return pickup


## Hits a brick and removes it from the board if it breaks. Returns HP taken,
## including anything a gas can blast took from its neighbours.
func damage_brick(brick: Brick, amount: int) -> int:
	if brick.is_destroyed():
		return 0 # already broken by a blast earlier this substep
	var dealt := brick.take_hit(amount)
	if not brick.is_destroyed():
		return dealt
	# Breaking can set off gas cans, which can break more gas cans: work
	# through them in order rather than recursing.
	var broken: Array[Brick] = [brick]
	var i := 0
	while i < broken.size():
		var gone := broken[i]
		i += 1
		_break(gone)
		if gone.type != Brick.Type.GAS:
			continue
		effects.append({"kind": "blast", "col": gone.col, "row": gone.row})
		for neighbour in neighbours_of(gone):
			if neighbour.is_destroyed():
				continue
			dealt += neighbour.take_hit(gone.max_hp)
			if neighbour.is_destroyed():
				broken.append(neighbour)
	return dealt


## Fires a laser bar's beam along its row or column: `amount` damage to every
## visible brick in the line, each hit once. Returns HP taken.
func fire_laser(col: int, row: int, vertical: bool, amount: int) -> int:
	effects.append({"kind": "laser", "col": col, "row": row, "vertical": vertical})
	var targets: Array[Brick] = []
	for i in (rows if vertical else columns):
		var brick := brick_at(col, i) if vertical else brick_at(i, row)
		if brick != null and not targets.has(brick):
			targets.append(brick)
	var dealt := 0
	for brick in targets:
		dealt += damage_brick(brick, amount)
	return dealt


## Every solid brick in a visible cell touching `brick` (its 8 neighbours, or
## more for a wide brick), each listed once.
func neighbours_of(brick: Brick) -> Array[Brick]:
	var out: Array[Brick] = []
	for row in range(brick.row - 1, brick.row + 2):
		for col in range(brick.col - 1, brick.col + brick.width + 1):
			var other := brick_at(col, row)
			if other != null and other != brick and not out.has(other):
				out.append(other)
	return out


## Free visible cells around `brick`, never in the danger row. Row by row,
## left to right, so callers pick from them deterministically.
func free_cells_around(brick: Brick) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in range(maxi(brick.row - 1, DANGER_ROW + 1), brick.row + 2):
		for col in range(brick.col - 1, brick.col + brick.width + 1):
			if is_free(col, row):
				out.append(Vector2i(col, row))
	return out


## Moves a brick sideways to `col` if every cell it would cover there is free
## (or its own). Returns false and leaves it alone otherwise.
func move_brick(brick: Brick, col: int) -> bool:
	for i in brick.width:
		var c := col + i
		if not in_bounds(c, brick.row):
			return false
		if brick_at(c, brick.row) != brick and not is_free(c, brick.row):
			return false
	_fill(brick, null)
	brick.col = col
	_fill(brick, brick)
	return true


func remove_brick(brick: Brick) -> void:
	if brick.is_solid():
		bricks.erase(brick)
		_fill(brick, null)
	else:
		sludge.erase(brick)
		_fill_sludge(brick, null)


func remove_pickup(pickup: Pickup) -> void:
	pickups.erase(pickup)
	_fill_pickup(pickup, null)


## Moves every brick and pickup by `delta` rows (negative = up). Pickups pushed
## into the danger row are collected automatically and returned, so the player
## never loses them.
func shift(delta: int) -> Array[Pickup]:
	var collected: Array[Pickup] = []
	for brick in bricks:
		brick.row += delta
	# Sludge drains away when it reaches the danger row.
	for puddle: Brick in sludge.duplicate():
		puddle.row += delta
		if puddle.row <= DANGER_ROW:
			sludge.erase(puddle)
	for pickup: Pickup in pickups.duplicate():
		pickup.row += delta
		if pickup.row <= DANGER_ROW:
			pickups.erase(pickup)
			collected.append(pickup)
	_rebuild_cells()
	return collected


## Moves everything up one row. See shift().
func rise() -> Array[Pickup]:
	return shift(-1)


## Smallest row index holding a brick, or `rows` if the board is empty.
func topmost_brick_row() -> int:
	var top := rows
	for brick in bricks:
		top = mini(top, brick.row)
	return top


## How many bricks sit above (not on or below) `row`.
func bricks_above(row: int) -> int:
	var count := 0
	for brick in bricks:
		if brick.row < row:
			count += 1
	return count


func is_trapped() -> bool:
	return topmost_brick_row() <= DANGER_ROW


## Removes every brick in the `count` rows from the top of the pile down.
## Used by the continue: it gives the player room to breathe.
func clear_top_rows(count: int) -> void:
	var limit := topmost_brick_row() + count
	for brick: Brick in bricks.duplicate():
		if brick.row < limit:
			remove_brick(brick)


func clone() -> Board:
	var copy := Board.new(rows, columns)
	copy._next_id = _next_id
	for brick in bricks:
		copy.bricks.append(brick.clone())
	for puddle in sludge:
		copy.sludge.append(puddle.clone())
	for pickup in pickups:
		copy.pickups.append(pickup.clone())
	copy._rebuild_cells()
	return copy


func _fill(brick: Brick, value: Brick) -> void:
	for i in brick.width:
		if in_bounds(brick.col + i, brick.row):
			_cells[brick.row * columns + brick.col + i] = value


func _fill_sludge(puddle: Brick, value: Brick) -> void:
	for i in puddle.width:
		if in_bounds(puddle.col + i, puddle.row):
			_sludge_cells[puddle.row * columns + puddle.col + i] = value


## Takes a broken brick off the board. A crate leaves its pickup behind.
func _break(brick: Brick) -> void:
	remove_brick(brick)
	if brick.type == Brick.Type.CRATE and brick.drop >= 0 and is_free(brick.col, brick.row):
		add_pickup(Pickup.new(brick.drop, brick.col, brick.row, brick.drop_data))


func _fill_pickup(pickup: Pickup, value: Pickup) -> void:
	if in_bounds(pickup.col, pickup.row):
		_pickup_cells[pickup.row * columns + pickup.col] = value


func _rebuild_cells() -> void:
	_cells.fill(null)
	for brick in bricks:
		_fill(brick, brick)
	_pickup_cells.fill(null)
	for pickup in pickups:
		_fill_pickup(pickup, pickup)
	_sludge_cells.fill(null)
	for puddle in sludge:
		_fill_sludge(puddle, puddle)
