extends CharacterBody3D
## 플레이어 몸. 입력으로 움직이고, 위치를 sim에 넘긴다. 등 뒤 스택은 StackAnchor가 그린다.

const MODEL := "res://frost_camp/assets/models/characters/character-male-a.glb"
## 도끼 레벨별로 손에 드는 모델. 0레벨은 맨주먹이다.
const ROD := "res://frost_camp/scenes/fishing_rod.tscn"
const PICKAXE := "res://frost_camp/assets/models/survival/tool-pickaxe.glb"
## 싸우거나 쏜 뒤 총을 들고 있는 시간(초)
const GUN_HOLD_TIME := 1.2
const AXE_MODELS := [
	"",
	"res://frost_camp/assets/models/survival/tool-axe.glb",
	"res://frost_camp/assets/models/survival/tool-axe-upgraded.glb",
]

var sim: FrostSim
var joystick: Node
## 남은 총 들기 시간. 곰과 싸우거나 작살총을 쏘면 다시 찬다.
var _gun_left := 0.0

@onready var _pivot: Node3D = $Pivot
@onready var _model: Node3D = $Pivot/Model


func setup(frost_sim: FrostSim, virtual_joystick: Node) -> void:
	sim = frost_sim
	joystick = virtual_joystick
	position = Vector3(sim.player.pos.x, 0.0, sim.player.pos.y)
	$Pivot/StackAnchor.setup(sim.player.stack)
	_model.setup(MODEL)
	sim.tree_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.trees[i].pos))
	sim.bear_hit.connect(func(i: int, agent: SimAgent) -> void: _on_shot(agent, sim.bears[i].pos))
	sim.raider_hit.connect(func(i: int, agent: SimAgent) -> void: _on_shot(agent, sim.raid.bears[i].pos))
	sim.gun_fired.connect(func(i: int) -> void: _on_shot(sim.player, sim.raid.bears[i].pos))


func _physics_process(delta: float) -> void:
	var input := _read_input()
	velocity = Vector3(input.x, 0.0, input.y) * sim.agent_speed(sim.player)
	move_and_slide()
	if input.length() > 0.1:
		_pivot.rotation.y = atan2(-input.x, -input.y)
	sim.player.pos = Vector2(position.x, position.z)
	_model.set_moving(input.length() > 0.1)
	_model.set_frozen(sim.player.warmth <= 0.0)
	# 하는 일에 맞는 도구만 든다: 구멍 위에서는 낚싯대, 바위 앞에서는 곡괭이, 나무 앞에서는 도끼(도끼를 산 뒤),
	# 곰과 싸우거나 작살총을 쏜 뒤 잠깐은 총. 아무 일도 안 하면 맨손이다.
	_gun_left = maxf(_gun_left - delta, 0.0)
	var near := sim.tree_at(sim.player.pos)
	var tool := ""
	if _gun_left > 0.0:
		tool = _model.GUN
	elif sim.fishing_hole_at(sim.player.pos) != -1:
		tool = ROD
	elif near != -1:
		tool = PICKAXE if sim.trees[near].item == "crystal" else AXE_MODELS[mini(sim.find_zone("axe").level, AXE_MODELS.size() - 1)]
	_model.set_tool(tool)
	_model.set_holding(_gun_left > 0.0)


## 내가 친 것이면 휘두르고, 서 있을 때는 맞은 쪽을 바라본다.
func _on_hit(agent: SimAgent, target: Vector2) -> void:
	if agent != sim.player:
		return
	_model.play_action()
	if velocity.length() < 0.1:
		_face(target)


## 곰과 싸우거나 작살총을 쏘면 총을 들고 쏘는 동작을 하며, 서 있을 때는 그쪽을 본다.
func _on_shot(agent: SimAgent, target: Vector2) -> void:
	if agent != sim.player:
		return
	_gun_left = GUN_HOLD_TIME
	_model.set_tool(_model.GUN)
	_model.set_holding(true)
	_model.play_action(_model.SHOOT)
	if velocity.length() < 0.1:
		_face(target)


func _face(target: Vector2) -> void:
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
