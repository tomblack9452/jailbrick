class_name BrickView
extends Node3D
## Greybox brick: a flat tile with a darker rim and its HP in the middle.
## Slides towards `target` so rises animate, and flashes white when hit.

const SIZE := 0.92
const RIM := 0.07
const SLIDE_RATE := 14.0
const LOW_HP_COLOR := Color(0.95, 0.78, 0.3)
const MID_HP_COLOR := Color(0.86, 0.33, 0.24)
const HIGH_HP_COLOR := Color(0.52, 0.24, 0.66)
const LOCK_COLOR := Color(0.42, 0.52, 0.6)
const LOCK_RIM_COLOR := Color(0.95, 0.78, 0.3)
## HP at which a brick reaches HIGH_HP_COLOR (log scale between).
const HIGH_HP := 40.0
## Label size in world units per font pixel, for 1-2 digit and 3+ digit HP.
const LABEL_SCALE := 0.0085
const LABEL_SCALE_SMALL := 0.0065

var target := Vector3.ZERO

var _fill := _unshaded()
var _rim := _unshaded()
var _label := _make_label(64)
var _caption: Label3D = null
var _base_color := Color.WHITE
var _rim_color := Color.WHITE
var _hp := -1
var _is_lock := false
var _flash := 0.0
var _dying := false


func setup(brick: Brick, start_position: Vector3) -> void:
	_is_lock = brick.is_lock()
	var width := brick.width - (1.0 - SIZE)
	_add_quad(Vector2(width, SIZE), 0.0, _rim)
	_add_quad(Vector2(width - RIM * 2.0, SIZE - RIM * 2.0), 0.01, _fill)
	add_child(_label)
	if _is_lock:
		_caption = _make_label(48)
		_caption.text = "LOCK"
		_caption.pixel_size = LABEL_SCALE_SMALL
		_caption.position.y = 0.24
		_label.position.y = -0.1
		add_child(_caption)
	position = start_position
	set_hp(brick.hp)


func set_hp(hp: int) -> void:
	if hp == _hp:
		return
	if _hp != -1 and hp < _hp:
		_flash = 1.0
	_hp = hp
	_label.text = str(hp)
	_label.pixel_size = LABEL_SCALE if hp < 100 or _is_lock else LABEL_SCALE_SMALL
	_base_color = _color_for(hp)
	_rim_color = LOCK_RIM_COLOR if _is_lock else _base_color.darkened(0.35)


## Plays a quick shrink and frees the node.
func break_apart() -> void:
	_dying = true
	_flash = 1.0


func _process(delta: float) -> void:
	position = position.lerp(target, 1.0 - exp(-SLIDE_RATE * delta))
	_flash = maxf(0.0, _flash - delta * 7.0)
	_fill.albedo_color = _base_color.lerp(Color.WHITE, _flash * 0.75)
	_rim.albedo_color = _rim_color.lerp(Color.WHITE, _flash * 0.75)
	if _dying:
		scale *= exp(-18.0 * delta)
		if scale.x < 0.05:
			queue_free()


func _color_for(hp: int) -> Color:
	if _is_lock:
		return LOCK_COLOR
	var t := clampf(log(float(maxi(hp, 1))) / log(HIGH_HP), 0.0, 1.0)
	if t < 0.5:
		return LOW_HP_COLOR.lerp(MID_HP_COLOR, t * 2.0)
	return MID_HP_COLOR.lerp(HIGH_HP_COLOR, (t - 0.5) * 2.0)


func _add_quad(size: Vector2, z: float, material: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.position.z = z
	add_child(mesh)


static func _unshaded() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _make_label(font_size: int) -> Label3D:
	var label := Label3D.new()
	label.position.z = 0.02
	label.font_size = font_size
	label.pixel_size = LABEL_SCALE
	label.outline_size = 14
	label.outline_modulate = Color.BLACK
	label.shaded = false
	return label
