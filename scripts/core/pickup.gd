class_name Pickup
extends RefCounted
## Something a ball collects by passing through it. Doesn't block balls.
## Only +1 Ball for now; the rest of B5 arrives in Phase 3.

enum Type { EXTRA_BALL }

var id := 0
var type := Type.EXTRA_BALL
var col := 0
var row := 0


func _init(p_type := Type.EXTRA_BALL, p_col := 0, p_row := 0) -> void:
	type = p_type
	col = p_col
	row = p_row


func clone() -> Pickup:
	var copy := Pickup.new(type, col, row)
	copy.id = id
	return copy
