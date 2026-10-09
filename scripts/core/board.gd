class_name Board
extends RefCounted
## The playfield grid. Column 0 is on the left. Row 0 is the danger row just
## under the launcher, and rows count downwards. Bricks rise towards row 0.
##
## In board space a cell (col, row) covers x in [col, col + 1] and
## y in [row, row + 1], with y pointing down.

const COLUMNS := 7
const DEFAULT_ROWS := 11
const DANGER_ROW := 0

var columns := COLUMNS
var rows := DEFAULT_ROWS
var bricks: Array[Brick] = []
var pickups: Array[Pickup] = []
var lock: Lock = null

var _next_id := 1
var _cells: Array[Brick] = []


func _init(p_rows := DEFAULT_ROWS, p_columns := COLUMNS) -> void:
	rows = p_rows
	columns = p_columns
	_cells.resize(rows * columns)


func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < columns and row >= 0 and row < rows


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
		assert(is_free(brick.col + i, brick.row), "cell (%d, %d) is taken" % [brick.col + i, brick.row])
	brick.id = _next_id
	_next_id += 1
	bricks.append(brick)
	if brick is Lock:
		lock = brick
	_fill(brick, brick)
	return brick


func add_pickup(pickup: Pickup) -> Pickup:
	assert(is_free(pickup.col, pickup.row), "cell (%d, %d) is taken" % [pickup.col, pickup.row])
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


## Moves every brick and pickup up one row. Pickups pushed into the danger row
## are collected automatically and returned, so the player never loses them.
func rise() -> Array[Pickup]:
	var collected: Array[Pickup] = []
	for brick in bricks:
		brick.row -= 1
	for pickup: Pickup in pickups.duplicate():
		pickup.row -= 1
		if pickup.row <= DANGER_ROW:
			pickups.erase(pickup)
			collected.append(pickup)
	_rebuild_cells()
	return collected


## Smallest row index holding a brick, or `rows` if the board is empty.
func topmost_brick_row() -> int:
	var top := rows
	for brick in bricks:
		top = mini(top, brick.row)
	return top


func is_trapped() -> bool:
	return topmost_brick_row() <= DANGER_ROW


func clone() -> Board:
	var copy := Board.new(rows, columns)
	copy._next_id = _next_id
	for brick in bricks:
		var b := brick.clone()
		copy.bricks.append(b)
		if b is Lock:
			copy.lock = b
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
