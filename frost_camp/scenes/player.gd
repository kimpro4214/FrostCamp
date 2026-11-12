extends CharacterBody3D
## 플레이어 몸. 입력으로 움직이고, 위치를 sim에 넘긴다. 등 뒤 스택은 StackAnchor가 그린다.

const MODEL := "res://frost_camp/assets/models/characters/character-male-a.glb"
## 도끼 레벨별로 손에 드는 모델. 0레벨은 맨주먹이다.
const AXE_MODELS := [
	"",
	"res://frost_camp/assets/models/survival/tool-axe.glb",
	"res://frost_camp/assets/models/survival/tool-axe-upgraded.glb",
]

var sim: FrostSim
var joystick: Node

@onready var _pivot: Node3D = $Pivot
@onready var _model: Node3D = $Pivot/Model


func setup(frost_sim: FrostSim, virtual_joystick: Node) -> void:
	sim = frost_sim
	joystick = virtual_joystick
	position = Vector3(sim.player.pos.x, 0.0, sim.player.pos.y)
	$Pivot/StackAnchor.setup(sim.player.stack)
	_model.setup(MODEL)
	sim.tree_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.trees[i].pos))
	sim.bear_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.bears[i].pos))


func _physics_process(_delta: float) -> void:
	var input := _read_input()
	velocity = Vector3(input.x, 0.0, input.y) * sim.agent_speed(sim.player)
	move_and_slide()
	if input.length() > 0.1:
		_pivot.rotation.y = atan2(-input.x, -input.y)
	sim.player.pos = Vector2(position.x, position.z)
	_model.set_moving(input.length() > 0.1)
	_model.set_frozen(sim.player.warmth <= 0.0)
	_model.set_tool(AXE_MODELS[mini(sim.find_zone("axe").level, AXE_MODELS.size() - 1)])


## 내가 친 것이면 휘두르고, 서 있을 때는 맞은 쪽을 바라본다.
func _on_hit(agent: SimAgent, target: Vector2) -> void:
	if agent != sim.player:
		return
	_model.play_action()
	if velocity.length() < 0.1:
		var dir := target - sim.player.pos
		_pivot.rotation.y = atan2(-dir.x, -dir.y)


func _read_input() -> Vector2:
	if joystick.vector != Vector2.ZERO:
		return joystick.vector
	var input := Vector2(
		float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT)),
		float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP)))
	return input.limit_length(1.0)


func _pressed(key: Key, alt: Key) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_physical_key_pressed(alt)
