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

const COLUMNS := 15
const DEFAULT_ROWS := 22
const DANGER_ROW := 0

var columns := COLUMNS
var rows := DEFAULT_ROWS
var bricks: Array[Brick] = []
var pickups: Array[Pickup] = []

var _next_id := 1
var _cells: Array[Brick] = []


func _init(p_rows := DEFAULT_ROWS, p_columns := COLUMNS) -> void:
	rows = p_rows
	columns = p_columns
	_cells.resize(rows * columns)


func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < columns and row >= 0 and row < rows


## The brick in a visible cell, or null. Bricks below the floor aren't returned.
func brick_at(col: int, row: int) -> Brick:
	if not in_bounds(col, row):
		return null
	return _cells[row * columns + col]


func pickup_at(col: int, row: int) -> Pickup:
	for pickup in pickups:
		if pickup.col == col and pickup.row == row:
			return pickup
	return null


func is_free(col: int, row: int) -> bool:
	return in_bounds(col, row) and brick_at(col, row) == null and pickup_at(col, row) == null


func add_brick(brick: Brick) -> Brick:
	for i in brick.width:
		var col := brick.col + i
		assert(not in_bounds(col, brick.row) or is_free(col, brick.row), "cell (%d, %d) is taken" % [col, brick.row])
	brick.id = _next_id
	_next_id += 1
	bricks.append(brick)
	_fill(brick, brick)
	return brick


func add_pickup(pickup: Pickup) -> Pickup:
	assert(not in_bounds(pickup.col, pickup.row) or is_free(pickup.col, pickup.row), "cell (%d, %d) is taken" % [pickup.col, pickup.row])
	pickup.id = _next_id
	_next_id += 1
	pickups.append(pickup)
	return pickup


## Hits a brick and removes it from the board if it breaks. Returns HP taken.
func damage_brick(brick: Brick, amount: int) -> int:
	var dealt := brick.take_hit(amount)
	if brick.is_destroyed():
		remove_brick(brick)
	return dealt


func remove_brick(brick: Brick) -> void:
	bricks.erase(brick)
	_fill(brick, null)


func remove_pickup(pickup: Pickup) -> void:
	pickups.erase(pickup)


## Moves every brick and pickup by `delta` rows (negative = up). Pickups pushed
## into the danger row are collected automatically and returned, so the player
## never loses them.
func shift(delta: int) -> Array[Pickup]:
	var collected: Array[Pickup] = []
	for brick in bricks:
		brick.row += delta
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
	for pickup in pickups:
		copy.pickups.append(pickup.clone())
	copy._rebuild_cells()
	return copy


func _fill(brick: Brick, value: Brick) -> void:
	for i in brick.width:
		if in_bounds(brick.col + i, brick.row):
			_cells[brick.row * columns + brick.col + i] = value


func _rebuild_cells() -> void:
	_cells.fill(null)
	for brick in bricks:
		_fill(brick, brick)
