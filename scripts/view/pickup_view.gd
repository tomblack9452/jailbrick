class_name PickupView
extends Node3D
## Greybox +1 Ball pickup: a pulsing green ring.

const COLOR := Color(0.35, 0.95, 0.45)

var target := Vector3.ZERO

var _ring := MeshInstance3D.new()
var _dying := false


func setup(start_position: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.3
	_ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = material
	_ring.rotation_degrees.x = 90.0
	add_child(_ring)
	position = start_position


func collect() -> void:
	_dying = true


func _process(delta: float) -> void:
	position = position.lerp(target, 1.0 - exp(-BrickView.SLIDE_RATE * delta))
	if _dying:
		scale *= exp(-14.0 * delta)
		if scale.x < 0.05:
			queue_free()
	else:
		scale = Vector3.ONE * (1.0 + 0.1 * sin(Time.get_ticks_msec() / 160.0))
