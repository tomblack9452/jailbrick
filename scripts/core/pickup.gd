class_name Pickup
extends RefCounted
## Something a ball collects by passing through it. Doesn't block balls (B5).
##
## - EXTRA_BALL: +1 ball for the rest of the run.
## - COIN: COIN_VALUE coins, banked with the run.
## - SPLITTER: the ball that touches it splits into 3 for this volley.
## - LASER: a one-shot beam along its row (data = HORIZONTAL) or column
##   (data = VERTICAL) that hits every brick in the line once.
## - FREEZE: the next rise step is skipped.
##
## Pickups that rise into the danger row are collected automatically
## (TurnController handles what each one does then).

enum Type { EXTRA_BALL, COIN, SPLITTER, LASER, FREEZE }

const COIN_VALUE := 10
const HORIZONTAL := 0
const VERTICAL := 1

var id := 0
var type := Type.EXTRA_BALL
var col := 0
var row := 0
## Extra per-type data (the laser bar's direction).
var data := 0


func _init(p_type := Type.EXTRA_BALL, p_col := 0, p_row := 0, p_data := 0) -> void:
	type = p_type
	col = p_col
	row = p_row
	data = p_data


func clone() -> Pickup:
	var copy := Pickup.new(type, col, row, data)
	copy.id = id
	return copy
