extends CharacterBody3D
## 플레이어 몸. 입력으로 움직이고, 위치를 sim에 넘기고, 등 뒤 스택을 그린다.

const ITEM_COLORS := {"log": Color(0.55, 0.33, 0.18)}
const ITEM_SIZE := Vector3(0.5, 0.2, 0.3)

var sim: FrostSim
var joystick: Node
var _shown: Array[String] = []
var _materials := {}

@onready var _pivot: Node3D = $Pivot
@onready var _stack_anchor: Node3D = $Pivot/StackAnchor


func setup(frost_sim: FrostSim, virtual_joystick: Node) -> void:
	sim = frost_sim
	joystick = virtual_joystick
	position = Vector3(sim.player.pos.x, 0.0, sim.player.pos.y)


func _physics_process(_delta: float) -> void:
	var input := _read_input()
	velocity = Vector3(input.x, 0.0, input.y) * sim.agent_speed(sim.player)
	move_and_slide()
	if input.length() > 0.1:
		_pivot.rotation.y = atan2(-input.x, -input.y)
	sim.player.pos = Vector2(position.x, position.z)
	_sync_stack()


func _read_input() -> Vector2:
	if joystick.vector != Vector2.ZERO:
		return joystick.vector
	var input := Vector2(
		float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT)),
		float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP)))
	return input.limit_length(1.0)


func _pressed(key: Key, alt: Key) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_physical_key_pressed(alt)


func _sync_stack() -> void:
	if sim.player.stack.items == _shown:
		return
	_shown = sim.player.stack.items.duplicate()
	for child in _stack_anchor.get_children():
		child.queue_free()
	for i in _shown.size():
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = ITEM_SIZE
		box.mesh = mesh
		box.material_override = _material_for(_shown[i])
		box.position.y = i * (ITEM_SIZE.y + 0.02)
		_stack_anchor.add_child(box)


func _material_for(item: String) -> StandardMaterial3D:
	if not _materials.has(item):
		var material := StandardMaterial3D.new()
		material.albedo_color = ITEM_COLORS.get(item, Color.MAGENTA)
		_materials[item] = material
	return _materials[item]
