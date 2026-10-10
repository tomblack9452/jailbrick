class_name PickupView
extends Node3D
## Greybox pickups (B5), each a different shape and colour so they read
## without art: +1 Ball green ring, coin gold disc, splitter three cyan dots,
## laser bar a red bar lying along its beam, freeze a pale blue diamond.

const COLORS := {
	Pickup.Type.EXTRA_BALL: Color(0.35, 0.95, 0.45),
	Pickup.Type.COIN: Color(1.0, 0.82, 0.2),
	Pickup.Type.SPLITTER: Color(0.3, 0.9, 1.0),
	Pickup.Type.LASER: Color(1.0, 0.25, 0.25),
	Pickup.Type.FREEZE: Color(0.7, 0.88, 1.0),
}

var target := Vector3.ZERO

var _dying := false


func setup(pickup: Pickup, start_position: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[pickup.type]
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match pickup.type:
		Pickup.Type.EXTRA_BALL:
			var torus := TorusMesh.new()
			torus.inner_radius = 0.2
			torus.outer_radius = 0.3
			_add(torus, material).rotation_degrees.x = 90.0
		Pickup.Type.COIN:
			var disc := CylinderMesh.new()
			disc.top_radius = 0.24
			disc.bottom_radius = 0.24
			disc.height = 0.06
			_add(disc, material).rotation_degrees.x = 90.0
		Pickup.Type.SPLITTER:
			var dot := SphereMesh.new()
			dot.radius = 0.1
			dot.height = 0.2
			for i in 3:
				var angle := TAU * i / 3.0 + PI / 2.0
				_add(dot, material).position = Vector3(cos(angle), sin(angle), 0.0) * 0.17
		Pickup.Type.LASER:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.72, 0.14, 0.1)
			var mesh := _add(bar, material)
			if pickup.data == Pickup.VERTICAL:
				mesh.rotation_degrees.z = 90.0
		Pickup.Type.FREEZE:
			var box := BoxMesh.new()
			box.size = Vector3(0.32, 0.32, 0.1)
			_add(box, material).rotation_degrees.z = 45.0
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


func _add(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance
