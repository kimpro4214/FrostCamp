extends Node3D
## Kenney Mini Characters 뼈대를 쓰는 모델 하나를 띄우고 걷기/서기/휘두르기/총 들기·쏘기 애니메이션, 손에 든 도구, 얼음 덧칠을 맡는다.
## 플레이어·일꾼·손님이 같이 쓴다. 몸 모델은 도중에 바꿀 수 있다(방한복 단계).

const SCALE := 2.3
const FrozenOverlay := preload("res://frost_camp/scenes/frozen_overlay.tres")
const ACTION := "attack-melee-right"
## 총을 쏠 때와 총을 든 채 서 있을 때의 애니메이션
const SHOOT := "holding-right-shoot"
const HOLD := "holding-right"
const GUN := "res://frost_camp/assets/models/characters/weapon-shooter.glb"
## 오른손 뼈(어깨) 기준으로 도구를 쥐는 위치와 방향. 이 모델의 팔은 뼈의 -X 쪽으로 뻗어 있어서 손은 어깨에서 -X로 약 0.3이다.
const TOOL_ROTATION := Vector3(PI / 2.0 - 0.6, 0.0, 0.0)  # 손잡이를 앞으로, 조금 위로 세운다
const TOOL_POSITION := Vector3(-0.3, 0.0, 0.0)
const TOOL_SCALE := 1.4
## 총은 손잡이가 원점이고 총구가 +Z라 따로 맞춘다(같은 팩의 모델이라 크기는 그대로).
const GUN_ROTATION := Vector3(0.0, -PI / 2.0, 0.0)  # 총구(+Z)를 팔 방향(뼈의 -X)으로
const GUN_POSITION := Vector3(-0.3, 0.0, 0.0)
const GUN_SCALE := 1.0
## 위 도구 위치를 맞춘 Kenney 모델의 어깨~손끝 길이. 팔 길이가 다른 모델은 이 비율로 도구 위치를 늘이거나 줄인다.
const KENNEY_REACH := 0.284

var _player: AnimationPlayer
var _meshes: Array[Node] = []
var _moving := false
var _acting := false
var _frozen := false
var _holding := false
var _hand: BoneAttachment3D
var _tool_path := ""
var _body: Node3D
var _body_path := ""
## 이 모델의 팔 길이 / KENNEY_REACH
var _reach_scale := 1.0
## 오른팔 뼈의 방향. 다른 도구로 다시 내보낸 모델은 뼈 축이 Kenney와 달라, 도구를 이만큼 되돌려 붙인다.
var _hand_turn := Basis()


func setup(model_path: String) -> void:
	set_body(model_path)


## 몸 모델을 바꾼다. 애니메이션 상태, 손에 든 도구, 얼음 덧칠은 그대로 이어 간다.
func set_body(model_path: String) -> void:
	if model_path == _body_path:
		return
	_body_path = model_path
	if _body:
		_body.queue_free()
	_acting = false
	var model: Node3D = load(model_path).instantiate()
	_body = model
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI  # Kenney 캐릭터는 +Z를 보고, 이 게임의 앞은 -Z다.
	add_child(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	for anim_name in ["idle", "walk", HOLD]:
		_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_player.animation_finished.connect(_on_animation_finished)
	_player.play(_rest_animation())
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_hand = BoneAttachment3D.new()
	_hand.bone_name = "arm-right"
	skeleton.add_child(_hand)
	# get_bone_global_rest()를 부르면 이 뒤로 자세가 메시에 반영되지 않아, 부모를 따라 직접 곱한다.
	var arm := Transform3D()
	var bone := skeleton.find_bone("arm-right")
	while bone != -1:
		arm = skeleton.get_bone_rest(bone) * arm
		bone = skeleton.get_bone_parent(bone)
	var shoulder := absf(arm.origin.x)
	_hand_turn = arm.basis.orthonormalized().inverse()
	var half_span := 0.0
	for mesh: MeshInstance3D in _meshes:
		var box := mesh.mesh.get_aabb()
		half_span = maxf(half_span, maxf(box.end.x, -box.position.x))
	_reach_scale = (half_span - shoulder) / KENNEY_REACH
	var tool := _tool_path
	_tool_path = ""
	set_tool(tool)
	if _frozen:
		_frozen = false
		set_frozen(true)


func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if not _acting:
		_player.play(_rest_animation(), 0.15)


## 총을 든 자세인지. 든 채 서 있으면 총 드는 자세, 걸으면 걷는다.
func set_holding(holding: bool) -> void:
	if holding == _holding:
		return
	_holding = holding
	if not _acting:
		_player.play(_rest_animation(), 0.15)


## 한 번 휘두르거나(기본) 쏜다(SHOOT). 하는 중에 다시 부르면 처음부터 다시 한다.
func play_action(anim_name: String = ACTION) -> void:
	_acting = true
	_player.play(anim_name, 0.05)
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
	var gun := model_path == GUN
	var turn := Basis.from_euler(GUN_ROTATION if gun else TOOL_ROTATION).scaled(Vector3.ONE * (GUN_SCALE if gun else TOOL_SCALE))
	var offset := (GUN_POSITION if gun else TOOL_POSITION) * _reach_scale
	tool.transform = Transform3D(_hand_turn, Vector3.ZERO) * Transform3D(turn, offset)
	_hand.add_child(tool)


func set_frozen(frozen: bool) -> void:
	if frozen == _frozen:
		return
	_frozen = frozen
	for mesh in _meshes:
		mesh.material_overlay = FrozenOverlay if frozen else null


func _rest_animation() -> String:
	if _moving:
		return "walk"
	return HOLD if _holding else "idle"


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ACTION or anim_name == SHOOT:
		_acting = false
		_player.play(_rest_animation(), 0.1)
