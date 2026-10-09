class_name BrickView
extends Node3D
## Greybox brick: a flat-coloured cube with its HP on the front face.
## Slides towards `target` so rises animate, and flashes white when hit.

const SIZE := 0.92
const SLIDE_RATE := 14.0
const LOW_HP_COLOR := Color(0.95, 0.78, 0.3)
const MID_HP_COLOR := Color(0.86, 0.33, 0.24)
const HIGH_HP_COLOR := Color(0.52, 0.24, 0.66)
const LOCK_COLOR := Color(0.42, 0.52, 0.6)
## HP at which a brick reaches HIGH_HP_COLOR (log scale between).
const HIGH_HP := 40.0

var target := Vector3.ZERO

var _material := StandardMaterial3D.new()
var _label := Label3D.new()
var _base_color := Color.WHITE
var _hp := -1
var _is_lock := false
var _flash := 0.0
var _dying := false


func setup(brick: Brick, start_position: Vector3) -> void:
	_is_lock = brick.is_lock()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(brick.width - (1.0 - SIZE), SIZE, SIZE)
	mesh.mesh = box
	mesh.material_override = _material
	add_child(mesh)

	_label.position = Vector3(0.0, 0.0, SIZE / 2.0 + 0.01)
	_label.font_size = 80 if _is_lock else 96
	_label.pixel_size = 0.0045
	_label.outline_size = 22
	_label.outline_modulate = Color.BLACK
	_label.shaded = false
	add_child(_label)

	position = start_position
	set_hp(brick.hp)


func set_hp(hp: int) -> void:
	if hp == _hp:
		return
	if _hp != -1 and hp < _hp:
		_flash = 1.0
	_hp = hp
	_label.text = "LOCK\n%d" % hp if _is_lock else str(hp)
	_base_color = _color_for(hp)


## Plays a quick shrink and frees the node.
func break_apart() -> void:
	_dying = true
	_flash = 1.0


func _process(delta: float) -> void:
	position = position.lerp(target, 1.0 - exp(-SLIDE_RATE * delta))
	_flash = maxf(0.0, _flash - delta * 7.0)
	_material.albedo_color = _base_color.lerp(Color.WHITE, _flash * 0.75)
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
