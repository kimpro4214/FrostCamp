extends Node3D
## 메인 씬. sim을 만들고, layout 데이터대로 도형을 배치하고, 매 물리 프레임 sim을 돌린다.
## 일꾼이 쓸 길찾기 메시는 배치가 끝난 뒤 굽는다.

const TreeScene := preload("res://frost_camp/scenes/tree.tscn")
const StallScene := preload("res://frost_camp/scenes/stall.tscn")
const ZoneScene := preload("res://frost_camp/scenes/zone.tscn")
const BearScene := preload("res://frost_camp/scenes/bear.tscn")
const RegionScene := preload("res://frost_camp/scenes/region.tscn")
const WorkerScene := preload("res://frost_camp/scenes/worker.tscn")
const HeatScene := preload("res://frost_camp/scenes/heat.tscn")
const Juice := preload("res://frost_camp/scenes/juice.gd")
const ESCAPE_SAIL_TIME := 5.0
const MAX_FLYING_COINS := 10
const SNOW_OFFSET := Vector3(0.0, 8.0, 2.0)

var sim: FrostSim
var _hit_stop_id := 0

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _coin_template: Node3D = $Coins/Template


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
	var zone_names: Dictionary = GameData.load_json(GameData.TEXT_PATH).zones
	for i in sim.zones.size():
		var zone := ZoneScene.instantiate()
		$Zones.add_child(zone)
		zone.setup(sim, i, zone_names.get(sim.zones[i].id, sim.zones[i].id))
	for i in sim.bears.size():
		var bear := BearScene.instantiate()
		$Bears.add_child(bear)
		bear.setup(sim, i)
	for region_name in sim.regions:
		var region := RegionScene.instantiate()
		$Regions.add_child(region)
		region.setup(sim, region_name)
	for i in sim.heat_sources.size():
		var heat := HeatScene.instantiate()
		$Heat.add_child(heat)
		heat.setup(sim, i)
	$Woodpile.setup(sim)
	$Ship.setup(sim)
	sim.worker_hired.connect(_on_worker_hired)
	sim.zone_purchased.connect(_on_zone_purchased)
	sim.game_won.connect(_on_game_won)
	sim.tree_felled.connect(_on_tree_felled)
	sim.bear_killed.connect(_on_bear_killed)
	sim.cash_collected.connect(_on_cash_collected)
	_camera.target = _player
	_camera.snap()
	_bake_navigation()


func _on_worker_hired(index: int) -> void:
	var worker := WorkerScene.instantiate()
	$Workers.add_child(worker)
	worker.setup(sim, index)
	Juice.pop(worker.get_node("Pivot"), Vector3(0.2, 1.6, 0.2), 0.4)


func _on_tree_felled(_index: int) -> void:
	_camera.add_trauma(0.35)
	_hit_stop(0.05)


func _on_bear_killed(_index: int) -> void:
	_camera.add_trauma(0.6)
	_hit_stop(0.1)


## 돈 더미에서 동전이 튀어나와 주운 사람에게 빨려 들어간다.
func _on_cash_collected(stall_index: int, amount: int, agent: SimAgent) -> void:
	var collector: Node3D = _player
	if agent is Worker:
		collector = $Workers.get_child(sim.workers.find(agent))
	var stall := sim.stalls[stall_index]
	var start := Vector3(stall.cash_pos.x, 0.3, stall.cash_pos.y)
	var count := clampi(amount / stall.price, 1, MAX_FLYING_COINS)
	for i in count:
		var coin: Node3D = _coin_template.duplicate()
		coin.visible = true
		coin.position = start + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
		$Coins.add_child(coin)
		var from := coin.position
		var tween := coin.create_tween()
		tween.tween_interval(i * 0.03)
		tween.tween_method(func(t: float) -> void:
			var to := collector.position + Vector3(0.0, 1.2, 0.0)
			coin.position = from.lerp(to, t) + Vector3(0.0, sin(t * PI) * 1.5, 0.0)
			coin.rotation.y = t * TAU, 0.0, 1.0, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(coin.queue_free)


## 아주 잠깐 시간을 거의 멈춰 충격을 살린다. 가장 최근 호출만 시간을 되돌린다.
func _hit_stop(duration: float) -> void:
	_hit_stop_id += 1
	var my_id := _hit_stop_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _hit_stop_id:
		Engine.time_scale = 1.0


## 구매로 판매대가 열리거나 얼음벽이 사라지면 길이 바뀌므로 한 프레임 뒤 길찾기 메시를 다시 굽는다.
func _on_zone_purchased(_id: String, _level: int) -> void:
	await get_tree().process_frame
	_bake_navigation()


## 탈출 연출: 조작을 멈추고, 카메라가 배를 따라가고, 배가 떠난 뒤 결과 화면을 띄운다.
func _on_game_won() -> void:
	_player.set_physics_process(false)
	_hud.visible = false
	_camera.target = $Ship
	await get_tree().create_timer(1.5).timeout
	await $Ship.sail_away(ESCAPE_SAIL_TIME)
	$Result.show_result(sim)


func _bake_navigation() -> void:
	$NavigationRegion3D.bake_navigation_mesh(false)


func _physics_process(delta: float) -> void:
	sim.tick(delta)


func _process(_delta: float) -> void:
	# 눈은 플레이어 위 하늘에서 내린다(입자는 월드 좌표라 걸어도 같이 미끄러지지 않는다).
	$Snow.position = _player.position + SNOW_OFFSET
