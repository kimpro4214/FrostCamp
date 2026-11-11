extends Node3D
## 메인 씬. sim을 만들고, layout 데이터대로 도형을 배치하고, 매 물리 프레임 sim을 돌린다.
## 일꾼이 쓸 길찾기 메시는 배치가 끝난 뒤 굽는다.

const TreeScene := preload("res://frost_camp/scenes/tree.tscn")
const StallScene := preload("res://frost_camp/scenes/stall.tscn")
const ZoneScene := preload("res://frost_camp/scenes/zone.tscn")
const BearScene := preload("res://frost_camp/scenes/bear.tscn")
const RegionScene := preload("res://frost_camp/scenes/region.tscn")
const WorkerScene := preload("res://frost_camp/scenes/worker.tscn")

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
	for i in sim.zones.size():
		var zone := ZoneScene.instantiate()
		$Zones.add_child(zone)
		zone.setup(sim, i)
	for i in sim.bears.size():
		var bear := BearScene.instantiate()
		$Bears.add_child(bear)
		bear.setup(sim, i)
	for region_name in sim.regions:
		var region := RegionScene.instantiate()
		$Regions.add_child(region)
		region.setup(sim, region_name)
	$Woodpile.setup(sim)
	sim.worker_hired.connect(_on_worker_hired)
	sim.zone_purchased.connect(_on_zone_purchased)
	_camera.target = _player
	_camera.snap()
	_bake_navigation()


func _on_worker_hired(index: int) -> void:
	var worker := WorkerScene.instantiate()
	$Workers.add_child(worker)
	worker.setup(sim, index)


## 구매로 판매대가 열리거나 얼음벽이 사라지면 길이 바뀌므로 한 프레임 뒤 길찾기 메시를 다시 굽는다.
func _on_zone_purchased(_id: String, _level: int) -> void:
	await get_tree().process_frame
	_bake_navigation()


func _bake_navigation() -> void:
	$NavigationRegion3D.bake_navigation_mesh(false)


func _physics_process(delta: float) -> void:
	sim.tick(delta)
