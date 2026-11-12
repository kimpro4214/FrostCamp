extends RefCounted
## 여러 씬이 같이 쓰는 짧은 연출.


## 눌렸다가 살짝 넘치며 원래 크기로 돌아오는 "팝".
static func pop(node: Node3D, squash := Vector3(1.3, 0.7, 1.3), duration := 0.25) -> void:
	node.scale = squash
	node.create_tween().tween_property(node, "scale", Vector3.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
