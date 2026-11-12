extends Camera3D
## 고정 쿼터뷰(45°) 카메라. 대상을 부드럽게 따라가고, 충격이 오면 화면을 흔든다.
## 흔들림은 위치가 아니라 h_offset/v_offset(보이는 것)만 움직인다.

@export var offset := Vector3(0.0, 13.0, 13.0)
@export var smoothing := 6.0
@export var shake_decay := 1.5
@export var max_shake := 0.35

var target: Node3D
var _trauma := 0.0
var _shake_time := 0.0


func snap() -> void:
	position = target.position + offset


## 충격을 더한다(0~1). 여러 번 맞으면 쌓인다.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if target:
		position = position.lerp(target.position + offset, 1.0 - exp(-smoothing * delta))


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var shake := _trauma * _trauma
	_shake_time += delta * 30.0
	h_offset = max_shake * shake * sin(_shake_time * 1.7)
	v_offset = max_shake * shake * sin(_shake_time * 2.3)
