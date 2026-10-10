class_name Brick
extends RefCounted
## One brick on the board. Occupies `width` cells to the right of (col, row).
## Pure data: no nodes, so the core can run headless.
##
## Types (B4):
## - STONE: basic.
## - IRON: takes half damage, rounded up over every hit so far.
## - CRATE: drops the pickup in `drop` when broken (Board handles it).
## - GAS: explodes for its max HP on the 8 neighbours when broken (Board).
## - NEST: every NEST_EVERY turns spawns a 1 HP stone next to itself (TurnController).
## - SLUDGE: not solid. Balls pass through it slowed (BallSim). No HP to clear.
## - GUARD: the Warden. Walks a column per turn and spawns minions (TurnController).

enum Type { STONE, IRON, CRATE, GAS, NEST, SLUDGE, GUARD }

const NEST_EVERY := 2
const GUARD_MINION_EVERY := 3

var id := 0
var type := Type.STONE
var hp := 1
var max_hp := 1
var col := 0
var row := 0
var width := 1
## CRATE: the Pickup.Type it drops, or -1 for nothing.
var drop := -1
## Pickup data for the drop (the laser bar's direction).
var drop_data := 0
## NEST and GUARD: turns since it last acted.
var timer := 0
## GUARD: +1 walking right, -1 walking left.
var heading := 1
## GUARD: HP of the minions it spawns.
var minion_hp := 1
## IRON: total damage received, so half damage rounds up across hits.
var received := 0


func _init(p_type := Type.STONE, p_hp := 1, p_col := 0, p_row := 0, p_width := 1) -> void:
	type = p_type
	hp = p_hp
	max_hp = p_hp
	col = p_col
	row = p_row
	width = p_width


## Solid bricks block balls, count towards clearing a level, and trap you.
## Sludge is the only one that isn't.
func is_solid() -> bool:
	return type != Type.SLUDGE


func is_destroyed() -> bool:
	return hp <= 0


## Removes up to `amount` HP and returns how much was actually taken.
func take_hit(amount: int) -> int:
	if not is_solid():
		return 0
	var effective := amount
	if type == Type.IRON:
		# Half damage, rounded up over the total: at x1 damage every other hit counts.
		effective = (received + amount + 1) / 2 - (received + 1) / 2
		received += amount
	var dealt := mini(effective, hp)
	hp -= dealt
	return dealt


func clone() -> Brick:
	var copy := Brick.new(type, hp, col, row, width)
	copy.id = id
	copy.max_hp = max_hp
	copy.drop = drop
	copy.drop_data = drop_data
	copy.timer = timer
	copy.heading = heading
	copy.minion_hp = minion_hp
	copy.received = received
	return copy
