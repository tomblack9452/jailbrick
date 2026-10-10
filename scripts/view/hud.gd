class_name Hud
extends CanvasLayer
## Greybox HUD: level progress, coins, rows until trapped, volley controls and
## the trapped screen with its restart-at-level picker. Real UI arrives in Phase 7.

signal recall_pressed
signal continue_pressed
signal start_pressed(level: int)

const DANGER_COLOR := Color(1.0, 0.35, 0.3)
const GOOD_COLOR := Color(0.36, 0.79, 0.65)
const BANNER_TIME := 1.4

var fast_forward_held := false

var _banner_left := 0.0

@onready var _world: Label = $TopBar/Run/World
@onready var _level: Label = $TopBar/Run/Level
@onready var _progress: ProgressBar = $TopBar/Run/Progress
@onready var _rows: Label = $TopBar/Run/Rows
@onready var _coins: Label = $TopBar/Bank/Coins
@onready var _best: Label = $TopBar/Bank/Best
@onready var _trapped: Label = $TopBar/Bank/Trapped
@onready var _hint: Label = $Controls/Hint
@onready var _recall: Button = $Controls/Recall
@onready var _fast_forward: Button = $Controls/FastForward
@onready var _banner: Label = $Banner
@onready var _result: Control = $Result
@onready var _result_title: Label = $Result/Box/Title
@onready var _result_detail: Label = $Result/Box/Detail
@onready var _result_coins: Label = $Result/Box/Coins
@onready var _levels: GridContainer = $Result/Box/Scroll/Levels
@onready var _continue: Button = $Result/Box/Continue
@onready var _restart: Button = $Result/Box/Restart


func _ready() -> void:
	_fast_forward.button_down.connect(func() -> void: fast_forward_held = true)
	_fast_forward.button_up.connect(func() -> void: fast_forward_held = false)
	_recall.pressed.connect(recall_pressed.emit)
	_continue.pressed.connect(continue_pressed.emit)
	_restart.pressed.connect(func() -> void: start_pressed.emit(1))
	_result.hide()
	_banner.hide()


func refresh(game: TurnController, coins: int, best_level: int, can_recall: bool, speed: int) -> void:
	var cleared := game.rows_cleared()
	var curve := game.generator.curve if game.generator else null
	_world.visible = curve != null and curve.world_name(game.level) != ""
	if _world.visible:
		_world.text = curve.world_name(game.level).to_upper()
		_world.modulate = world_label_color(curve.world_tint(game.level))
	_level.text = "Level %d" % game.level
	_progress.max_value = TurnController.LEVEL_ROWS
	_progress.value = cleared
	_rows.text = "%d of %d rows cleared" % [cleared, TurnController.LEVEL_ROWS]
	_coins.text = "%s coins" % _thousands(coins)
	_best.text = "Best: level %d" % best_level
	var rows := game.rows_until_trapped()
	_trapped.text = "Trapped in %d" % rows
	if game.freezes > 0:
		_trapped.text += " (%d frozen)" % game.freezes
	_trapped.modulate = DANGER_COLOR if rows <= 2 else Color(0.8, 0.82, 0.8)

	var in_volley := game.phase == TurnController.Phase.VOLLEY
	_hint.visible = game.phase == TurnController.Phase.AIM
	_recall.visible = in_volley and can_recall
	_fast_forward.visible = in_volley
	_fast_forward.text = ">> x%d" % speed if speed > 1 else ">>"
	if not in_volley:
		fast_forward_held = false


## The world tint is a dark backdrop colour; lift it so the name stays readable.
static func world_label_color(tint: Color) -> Color:
	return tint.lightened(0.6)


## "Level 8: Flood", "Level 10: Warden", or just "Level 9".
static func level_title(game: TurnController) -> String:
	var title := "Level %d" % game.level
	if game.generator and game.generator.curve:
		var twist := game.generator.curve.twist_at(game.level)
		if twist != "":
			title += ": " + twist.capitalize()
	return title


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.show()
	_banner_left = BANNER_TIME


func show_trapped(game: TurnController, coins: int, best_level: int) -> void:
	_result_title.text = "Trapped at level %d" % game.level
	_result_detail.text = "%s points this run, +%d coins" % [_thousands(game.points), game.coins_earned()]
	_result_coins.text = "%s coins" % _thousands(coins)
	_continue.visible = not game.continued
	_continue.text = "Watch ad: continue at level %d" % game.level

	for child in _levels.get_children():
		child.queue_free()
	for level in range(1, best_level + 1):
		var cost := Economy.start_cost(level)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 34)
		button.text = "Level %d\n%s" % [level, "Free" if cost == 0 else "%s coins" % _thousands(cost)]
		button.disabled = coins < cost
		button.pressed.connect(func() -> void: start_pressed.emit(level))
		_levels.add_child(button)
	_result.show()


func hide_trapped() -> void:
	_result.hide()


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left / 0.4, 0.0, 1.0)
		if _banner_left <= 0.0:
			_banner.hide()


static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
