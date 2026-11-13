extends Node3D
## Kenney Mini Characters 모델 하나를 띄우고 걷기/서기/휘두르기 애니메이션, 손에 든 도구, 얼음 덧칠을 맡는다.
## 플레이어·일꾼·손님이 같이 쓴다.

const SCALE := 2.3
const FrozenOverlay := preload("res://frost_camp/scenes/frozen_overlay.tres")
const ACTION := "attack-melee-right"
## 오른손 뼈(어깨) 기준으로 도구를 쥐는 위치와 방향. 이 모델의 팔은 뼈의 -X 쪽으로 뻗어 있어서 손은 어깨에서 -X로 약 0.3이다.
const TOOL_ROTATION := Vector3(PI / 2.0 - 0.6, 0.0, 0.0)  # 손잡이를 앞으로, 조금 위로 세운다
const TOOL_POSITION := Vector3(-0.3, 0.0, 0.0)
const TOOL_SCALE := 1.4

var _player: AnimationPlayer
var _meshes: Array[Node] = []
var _moving := false
var _acting := false
var _frozen := false
var _hand: BoneAttachment3D
var _tool_path := ""


func setup(model_path: String) -> void:
	var model: Node3D = load(model_path).instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI  # Kenney 캐릭터는 +Z를 보고, 이 게임의 앞은 -Z다.
	add_child(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	for anim_name in ["idle", "walk"]:
		_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_animation_finished)
	_player.play("idle")
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_hand = BoneAttachment3D.new()
	_hand.bone_name = "arm-right"
	skeleton.add_child(_hand)


func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if not _acting:
		_player.play("walk" if moving else "idle", 0.15)


## 한 번 휘두른다. 휘두르는 중에 다시 부르면 처음부터 다시 휘두른다.
func play_action() -> void:
	_acting = true
	_player.play(ACTION, 0.05)
	_player.seek(0.0, true)


## 오른손에 도구 모델을 쥐여 준다. 빈 문자열이면 맨손이다.
func set_tool(model_path: String) -> void:
	if model_path == _tool_path:
		return
	_tool_path = model_path
	for child in _hand.get_children():
		child.queue_free()
	if model_path == "":
		return
	var tool: Node3D = load(model_path).instantiate()
	tool.rotation = TOOL_ROTATION
	tool.position = TOOL_POSITION
	tool.scale = Vector3.ONE * TOOL_SCALE
	_hand.add_child(tool)


func set_frozen(frozen: bool) -> void:
	if frozen == _frozen:
		return
	_frozen = frozen
	for mesh in _meshes:
		mesh.material_overlay = FrozenOverlay if frozen else null


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ACTION:
		_acting = false
		_player.play("walk" if _moving else "idle", 0.1)
