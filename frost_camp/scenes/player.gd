extends CharacterBody3D
## 플레이어 몸. 입력으로 움직이고, 위치를 sim에 넘긴다. 등 뒤 스택은 StackAnchor가 그린다.

var sim: FrostSim
var joystick: Node

@onready var _pivot: Node3D = $Pivot


func setup(frost_sim: FrostSim, virtual_joystick: Node) -> void:
	sim = frost_sim
	joystick = virtual_joystick
	position = Vector3(sim.player.pos.x, 0.0, sim.player.pos.y)
	$Pivot/StackAnchor.setup(sim.player.stack)


func _physics_process(_delta: float) -> void:
	var input := _read_input()
	velocity = Vector3(input.x, 0.0, input.y) * sim.agent_speed(sim.player)
	move_and_slide()
	if input.length() > 0.1:
		_pivot.rotation.y = atan2(-input.x, -input.y)
	sim.player.pos = Vector2(position.x, position.z)


func _read_input() -> Vector2:
	if joystick.vector != Vector2.ZERO:
		return joystick.vector
	var input := Vector2(
		float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT)),
		float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP)))
	return input.limit_length(1.0)


func _pressed(key: Key, alt: Key) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_physical_key_pressed(alt)
