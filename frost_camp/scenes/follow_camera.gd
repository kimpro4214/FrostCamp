extends Camera3D
## 고정 쿼터뷰(45°) 카메라. 대상을 부드럽게 따라간다.

@export var offset := Vector3(0.0, 13.0, 13.0)
@export var smoothing := 6.0

var target: Node3D


func snap() -> void:
	position = target.position + offset


func _physics_process(delta: float) -> void:
	if target:
		position = position.lerp(target.position + offset, 1.0 - exp(-smoothing * delta))
