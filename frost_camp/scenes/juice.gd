extends RefCounted
## 여러 씬이 같이 쓰는 짧은 연출.


## 눌렸다가 살짝 넘치며 원래 크기로 돌아오는 "팝".
static func pop(node: Node3D, squash := Vector3(1.3, 0.7, 1.3), duration := 0.25) -> void:
	node.scale = squash
	node.create_tween().tween_property(node, "scale", Vector3.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 머리 위로 떠올랐다 사라지는 글자(데미지 숫자, 얻은 개수 등).
static func float_text(parent: Node, at: Vector3, text: String, color := Color.WHITE, size := 64) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.1, 0.15)
	label.font_size = size
	label.outline_size = 12
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.25, 0.25), 0.0, 0.0)
	label.scale = Vector3.ONE * 0.6
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", at.y + 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


## 한 번 터지는 파편 입자를 만든다. restart()로 다시 터뜨린다.
static func make_burst(parent: Node3D, color: Color, amount := 10, size := 0.12) -> CPUParticles3D:
	var burst := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	burst.mesh = mesh
	burst.emitting = false
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = amount
	burst.lifetime = 0.6
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.initial_velocity_min = 2.5
	burst.initial_velocity_max = 4.5
	burst.angular_velocity_min = -360.0
	burst.angular_velocity_max = 360.0
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.2
	parent.add_child(burst)
	return burst
