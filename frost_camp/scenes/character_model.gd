extends Node3D
## Kenney Mini Characters 모델 하나를 띄우고 걷기/서기 애니메이션과 얼음 덧칠을 맡는다.
## 플레이어·일꾼·손님이 같이 쓴다.

const SCALE := 2.3
const FrozenOverlay := preload("res://frost_camp/scenes/frozen_overlay.tres")

var _player: AnimationPlayer
var _meshes: Array[Node] = []
var _moving := false
var _frozen := false


func setup(model_path: String) -> void:
	var model: Node3D = load(model_path).instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = PI  # Kenney 캐릭터는 +Z를 보고, 이 게임의 앞은 -Z다.
	add_child(model)
	_meshes = model.find_children("*", "MeshInstance3D", true, false)
	_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	for anim_name in ["idle", "walk"]:
		_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_player.play("idle")


func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	_player.play("walk" if moving else "idle", 0.15)


func set_frozen(frozen: bool) -> void:
	if frozen == _frozen:
		return
	_frozen = frozen
	for mesh in _meshes:
		mesh.material_overlay = FrozenOverlay if frozen else null
