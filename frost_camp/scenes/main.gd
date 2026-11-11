extends Node3D
## 메인 씬. sim을 만들고, layout 데이터대로 도형을 배치하고, 매 물리 프레임 sim을 돌린다.

const TreeScene := preload("res://frost_camp/scenes/tree.tscn")
const StallScene := preload("res://frost_camp/scenes/stall.tscn")

var sim: FrostSim

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	sim = FrostSim.new(GameData.load_json(GameData.BALANCE_PATH), GameData.load_json(GameData.LAYOUT_PATH))
	_player.setup(sim, _hud.joystick)
	_hud.setup(sim)
	for i in sim.trees.size():
		var tree := TreeScene.instantiate()
		$Trees.add_child(tree)
		tree.setup(sim, i)
	for i in sim.stalls.size():
		var stall := StallScene.instantiate()
		$Stalls.add_child(stall)
		stall.setup(sim, i)
	_camera.target = _player
	_camera.snap()


func _physics_process(delta: float) -> void:
	sim.tick(delta)
