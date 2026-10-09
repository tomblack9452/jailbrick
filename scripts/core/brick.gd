class_name Brick
extends RefCounted
## One brick on the board. Occupies `width` cells to the right of (col, row).
## Pure data: no nodes, so the core can run headless.

enum Type { STONE }

var id := 0
var type := Type.STONE
var hp := 1
var max_hp := 1
var col := 0
var row := 0
var width := 1


func _init(p_type := Type.STONE, p_hp := 1, p_col := 0, p_row := 0, p_width := 1) -> void:
	type = p_type
	hp = p_hp
	max_hp = p_hp
	col = p_col
	row = p_row
	width = p_width


func is_destroyed() -> bool:
	return hp <= 0


## Removes up to `amount` HP and returns how much was actually taken.
func take_hit(amount: int) -> int:
	var dealt := mini(amount, hp)
	hp -= dealt
	return dealt


func clone() -> Brick:
	var copy := Brick.new(type, hp, col, row, width)
	copy.id = id
	copy.max_hp = max_hp
	return copy
