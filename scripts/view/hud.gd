class_name Hud
extends CanvasLayer
## Greybox HUD: rows until trapped, lock HP, turn, volley controls and the
## win/lose screen. Real UI arrives in Phase 7.

signal retry_pressed
signal recall_pressed

const DANGER_COLOR := Color(1.0, 0.35, 0.3)

var fast_forward_held := false

@onready var _trapped: Label = $TopBar/Trapped
@onready var _lock: Label = $TopBar/Lock
@onready var _turn: Label = $TopBar/Turn
@onready var _hint: Label = $Controls/Hint
@onready var _recall: Button = $Controls/Recall
@onready var _fast_forward: Button = $Controls/FastForward
@onready var _result: Control = $Result
@onready var _result_title: Label = $Result/Box/Title
@onready var _result_detail: Label = $Result/Box/Detail
@onready var _retry: Button = $Result/Box/Retry


func _ready() -> void:
	_fast_forward.button_down.connect(func() -> void: fast_forward_held = true)
	_fast_forward.button_up.connect(func() -> void: fast_forward_held = false)
	_recall.pressed.connect(recall_pressed.emit)
	_retry.pressed.connect(retry_pressed.emit)
	_result.hide()


func refresh(game: TurnController, can_recall: bool, speed: int) -> void:
	var rows := game.rows_until_trapped()
	_trapped.text = "TRAPPED IN %d" % rows
	_trapped.modulate = DANGER_COLOR if rows <= 2 else Color.WHITE
	_lock.text = "LOCK %d" % game.lock_hp()
	_turn.text = "TURN %d" % game.turn

	var in_volley := game.phase == TurnController.Phase.VOLLEY
	_hint.visible = game.phase == TurnController.Phase.AIM
	_recall.visible = in_volley and can_recall
	_fast_forward.visible = in_volley
	_fast_forward.text = ">> x%d" % speed if speed > 1 else ">>"
	if not in_volley:
		fast_forward_held = false


func show_result(game: TurnController) -> void:
	if game.phase == TurnController.Phase.WON:
		_result_title.text = "ESCAPED!"
		_result_title.modulate = Color(0.55, 1.0, 0.6)
		_result_detail.text = "Lock broken on turn %d\nwith %d rows to spare." % [game.turn, game.rows_until_trapped()]
	else:
		_result_title.text = "TRAPPED"
		_result_title.modulate = DANGER_COLOR
		_result_detail.text = "The walls closed in on turn %d.\nThe lock had %d HP left." % [game.turn, game.lock_hp()]
	_result.show()
	_retry.grab_focus()


func hide_result() -> void:
	_result.hide()
