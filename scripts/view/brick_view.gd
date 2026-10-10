class_name BrickView
extends Node3D
## Greybox brick: a flat tile with a darker rim and its HP in the middle.
## Slides towards `target` so rises animate, and flashes white when hit.
## Special bricks (B4) get a fixed colour and a simple mark so they read
## without art: iron rivets, a crate cross, a gas band, nest dots, a Warden "W".
## Sludge is a flat murky puddle with no number.

const SIZE := 0.92
const RIM := 0.07
const SLIDE_RATE := 14.0
const LOW_HP_COLOR := Color(0.95, 0.78, 0.3)
const MID_HP_COLOR := Color(0.86, 0.33, 0.24)
const HIGH_HP_COLOR := Color(0.52, 0.24, 0.66)
## HP at which a brick reaches HIGH_HP_COLOR (log scale between).
const HIGH_HP := 40.0
## Label size in world units per font pixel, for 1-2 digit and 3+ digit HP.
const LABEL_SCALE := 0.0085
const LABEL_SCALE_SMALL := 0.0065
## Fill colour per special type. Stone uses the HP gradient instead.
const TYPE_COLORS := {
	Brick.Type.IRON: Color(0.55, 0.58, 0.62),
	Brick.Type.CRATE: Color(0.6, 0.42, 0.22),
	Brick.Type.GAS: Color(0.78, 0.14, 0.1),
	Brick.Type.NEST: Color(0.34, 0.22, 0.13),
	Brick.Type.SLUDGE: Color(0.3, 0.42, 0.16, 0.7),
	Brick.Type.GUARD: Color(0.16, 0.22, 0.5),
}
const MARK_COLOR := Color(0.12, 0.1, 0.08)

var target := Vector3.ZERO

var _fill := _unshaded()
var _rim := _unshaded()
var _label := _make_label(64)
var _base_color := Color.WHITE
var _rim_color := Color.WHITE
var _hp := -1
var _flash := 0.0
var _dying := false
var _type := Brick.Type.STONE


func setup(brick: Brick, start_position: Vector3) -> void:
	_type = brick.type
	position = start_position
	var width := brick.width - (1.0 - SIZE)
	if _type == Brick.Type.SLUDGE:
		_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_base_color = TYPE_COLORS[_type]
		_add_quad(Vector2(width, SIZE * 0.8), -0.3, _fill)
		_fill.albedo_color = _base_color
		return
	var rim := RIM * (2.2 if _type == Brick.Type.IRON else 1.0)
	_add_quad(Vector2(width, SIZE), 0.0, _rim)
	_add_quad(Vector2(width - rim * 2.0, SIZE - rim * 2.0), 0.01, _fill)
	_add_marks(width)
	add_child(_label)
	set_hp(brick.hp)


func set_hp(hp: int) -> void:
	if hp == _hp:
		return
	if _hp != -1 and hp < _hp:
		_flash = 1.0
	_hp = hp
	_label.text = str(hp)
	_label.pixel_size = LABEL_SCALE if hp < 100 else LABEL_SCALE_SMALL
	_base_color = TYPE_COLORS.get(_type, _color_for(hp))
	_rim_color = _base_color.darkened(0.35 if _type != Brick.Type.IRON else 0.6)


## Plays a quick shrink and frees the node.
func break_apart() -> void:
	_dying = true
	_flash = 1.0


func _process(delta: float) -> void:
	position = position.lerp(target, 1.0 - exp(-SLIDE_RATE * delta))
	if _type == Brick.Type.SLUDGE:
		scale.x = 1.0 + 0.04 * sin(Time.get_ticks_msec() / 300.0 + position.x)
		if _dying:
			queue_free()
		return
	_flash = maxf(0.0, _flash - delta * 7.0)
	_fill.albedo_color = _base_color.lerp(Color.WHITE, _flash * 0.75)
	_rim.albedo_color = _rim_color.lerp(Color.WHITE, _flash * 0.75)
	if _dying:
		scale *= exp(-18.0 * delta)
		if scale.x < 0.05:
			queue_free()


func _color_for(hp: int) -> Color:
	var t := clampf(log(float(maxi(hp, 1))) / log(HIGH_HP), 0.0, 1.0)
	if t < 0.5:
		return LOW_HP_COLOR.lerp(MID_HP_COLOR, t * 2.0)
	return MID_HP_COLOR.lerp(HIGH_HP_COLOR, (t - 0.5) * 2.0)


## The flat marks that tell special bricks apart, drawn just above the fill.
func _add_marks(width: float) -> void:
	var mark := _unshaded()
	mark.albedo_color = MARK_COLOR
	var half := Vector2(width, SIZE) / 2.0
	match _type:
		Brick.Type.IRON:
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var rivet := _add_quad(Vector2(0.09, 0.09), 0.015, mark)
				rivet.position += Vector3(corner.x * (half.x - 0.2), corner.y * (half.y - 0.2), 0.0)
		Brick.Type.CRATE:
			for angle in [45.0, -45.0]:
				var plank := _add_quad(Vector2(SIZE * 1.1, 0.09), 0.015, mark)
				plank.rotation_degrees.z = angle
		Brick.Type.GAS:
			var band := _unshaded()
			band.albedo_color = Color(0.95, 0.78, 0.15)
			_add_quad(Vector2(width - RIM * 2.0, 0.2), 0.015, band)
		Brick.Type.NEST:
			var dot := _unshaded()
			dot.albedo_color = Color(0.75, 0.62, 0.45)
			for i in 6:
				var angle := TAU * i / 6.0
				var speck := _add_quad(Vector2(0.08, 0.08), 0.015, dot)
				speck.position += Vector3(cos(angle) * 0.32, sin(angle) * 0.32, 0.0)
		Brick.Type.GUARD:
			var badge := _make_label(64)
			badge.text = "W"
			badge.pixel_size = 0.006
			badge.modulate = Color(0.95, 0.95, 0.85)
			badge.position = Vector3(-half.x + 0.25, half.y - 0.22, 0.03)
			add_child(badge)


func _add_quad(size: Vector2, z: float, material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.position.z = z
	add_child(mesh)
	return mesh


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
