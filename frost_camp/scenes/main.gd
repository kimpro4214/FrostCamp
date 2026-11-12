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
const StructureView := preload("res://frost_camp/scenes/structure_view.gd")
const TowerView := preload("res://frost_camp/scenes/tower_view.gd")
const WoodpileScene := preload("res://frost_camp/scenes/woodpile.tscn")
const ConveyorView := preload("res://frost_camp/scenes/conveyor_view.gd")
## 습격 방향 화살표가 플레이어에서 떨어진 거리, 이보다 가까운 곰은 가리키지 않는다
const ARROW_RADIUS := 2.4
const ARROW_HIDE_DIST := 8.0
const Juice := preload("res://frost_camp/scenes/juice.gd")
const Sfx := preload("res://frost_camp/scenes/sfx.gd")
const ESCAPE_SAIL_TIME := 5.0
const MAX_FLYING_COINS := 10
const SNOW_OFFSET := Vector3(0.0, 8.0, 2.0)
const DECOR_DIR := "res://frost_camp/assets/models/"
## 걸을 때 발소리 간격(초)
const STEP_INTERVAL := 0.3

var sim: FrostSim
var _hit_stop_id := 0
var _sfx: Node
var _last_money := 0
var _last_stack := 0
var _step_timer := 0.0
var _raid_arrow: Node3D

@onready var _player: CharacterBody3D = $Player
@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD
@onready var _coin_template: Node3D = $Coins/Template


func _ready() -> void:
	sim = FrostSim.new(GameData.load_json(GameData.BALANCE_PATH), GameData.load_json(GameData.LAYOUT_PATH))
	_player.setup(sim, _hud.joystick)
	_sfx = Sfx.new()
	add_child(_sfx)
	_sfx.setup(sim)
	_connect_sounds()
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
		var purchase_zone := sim.zones[i]
		zone.setup(sim, purchase_zone, zone_names.get(purchase_zone.id, purchase_zone.id),
			func() -> bool: return sim.is_zone_available(purchase_zone))
	for i in sim.bears.size():
		var bear := BearScene.instantiate()
		$Bears.add_child(bear)
		bear.setup(sim, sim.bears[i], false)
	for region_name in sim.regions:
		var region := RegionScene.instantiate()
		$Regions.add_child(region)
		region.setup(sim, region_name)
	for i in sim.heat_sources.size():
		var heat := HeatScene.instantiate()
		$Heat.add_child(heat)
		heat.setup(sim, i)
	_place_decor(GameData.load_json(GameData.LAYOUT_PATH).decor)
	$Woodpile.setup(sim)
	var meat_pile: Node3D = WoodpileScene.instantiate()
	meat_pile.name = "MeatPile"
	add_child(meat_pile)
	meat_pile.setup(sim, "meat")
	for i in sim.towers.size():
		var tower := TowerView.new()
		$Towers.add_child(tower)
		tower.setup(sim, i)
	var conveyor := ConveyorView.new()
	conveyor.name = "Conveyor"
	add_child(conveyor)
	conveyor.setup(sim)
	sim.raid_started.connect(_on_raid_started)
	sim.bear_added.connect(func(i: int) -> void:
		var bear := BearScene.instantiate()
		$Bears.add_child(bear)
		bear.setup(sim, sim.bears[i], false)
		Juice.pop(bear, Vector3(0.3, 1.6, 0.3), 0.4))
	_raid_arrow = _make_arrow()
	_place_structures(zone_names.get("repair", "repair"))
	$Ship.setup(sim)
	sim.worker_hired.connect(_on_worker_hired)
	sim.zone_purchased.connect(_on_zone_purchased)
	sim.game_won.connect(_on_game_won)
	sim.tree_hit.connect(_on_hit)
	sim.bear_hit.connect(_on_hit)
	sim.raider_hit.connect(_on_hit)
	sim.tree_felled.connect(_on_tree_felled)
	sim.bear_killed.connect(_on_bear_killed)
	sim.raider_killed.connect(_on_bear_killed)
	sim.cash_collected.connect(_on_cash_collected)
	_camera.target = _player
	_camera.snap()
	_bake_navigation()


## 시설마다 체력 표시와 수리 존을 붙인다. 판매대는 계산대 모델, 적치장은 통나무 더미가 부서지는 대상이다.
func _place_structures(repair_name: String) -> void:
	for i in sim.structures.size():
		var structure := sim.structures[i]
		var target: Node3D = $Woodpile/Logs
		for j in sim.stalls.size():
			if sim.stalls[j].structure == structure:
				target = $Stalls.get_child(j).get_node("Counter")
		if structure == sim.meat_pile_structure:
			target = $MeatPile/Logs
		if structure == sim.conveyor.structure:
			target = $Conveyor.model
		for j in sim.towers.size():
			if sim.towers[j].structure == structure:
				target = $Towers.get_child(j).model
		var view := StructureView.new()
		$Structures.add_child(view)
		view.setup(sim, i, target)
		var zone := ZoneScene.instantiate()
		$Zones.add_child(zone)
		zone.setup(sim, structure.repair, repair_name, structure.is_broken)


## sim 이벤트마다 효과음을 붙인다.
func _connect_sounds() -> void:
	sim.tree_hit.connect(func(i: int, _a: SimAgent) -> void: _sfx.play_at("chop", sim.trees[i].pos))
	sim.bear_hit.connect(func(i: int, _a: SimAgent) -> void: _sfx.play_at("punch", sim.bears[i].pos))
	sim.tree_felled.connect(func(i: int, _a: SimAgent) -> void: _sfx.play_at("fell", sim.trees[i].pos))
	sim.bear_killed.connect(func(i: int, _a: SimAgent) -> void: _sfx.play_at("punch_heavy", sim.bears[i].pos))
	sim.cash_collected.connect(func(i: int, _amount: int, _a: SimAgent) -> void: _sfx.play_at("coins", sim.stalls[i].cash_pos))
	sim.zone_purchased.connect(func(_id: String, _level: int) -> void: _sfx.play("purchase"))
	sim.worker_hired.connect(func(_i: int) -> void: _sfx.play("hire"))
	sim.game_won.connect(func() -> void: _sfx.play("win"))
	sim.structure_hit.connect(func(i: int, _damage: int) -> void: _sfx.play_at("crack", sim.structures[i].pos))
	sim.structure_broken.connect(func(i: int) -> void: _sfx.play_at("break", sim.structures[i].pos))
	sim.structure_repaired.connect(func(_i: int) -> void: _sfx.play("purchase"))
	sim.raider_hit.connect(func(i: int, _a: SimAgent) -> void: _sfx.play_at("punch", sim.raid.bears[i].pos))
	sim.raider_killed.connect(func(i: int, _a: SimAgent) -> void: _sfx.play_at("punch_heavy", sim.raid.bears[i].pos))
	sim.tower_fired.connect(func(t: int, _r: int) -> void: _sfx.play_at("shoot", sim.towers[t].pos))
	sim.raid_warning.connect(func(_wave: int, _pos: Vector2) -> void: _sfx.play("raid"))
	sim.raid_cleared.connect(func(_wave: int) -> void: _sfx.play("hire"))


## 돈이 줄면(구매 존에 넣는 중) 틱, 등 뒤 스택이 늘면 집는 소리, 줄면 내려놓는 소리, 걸으면 발소리.
func _play_player_sounds(delta: float) -> void:
	if sim.money < _last_money:
		_sfx.play("pay")
	_last_money = sim.money
	var stack_size := sim.player.stack.items.size()
	if stack_size > _last_stack:
		_sfx.play("pickup")
	elif stack_size < _last_stack:
		_sfx.play("drop")
	_last_stack = stack_size
	if _player.velocity.length() > 0.1:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = STEP_INTERVAL
			_sfx.play("step")
	else:
		_step_timer = 0.0


## 꾸밈용 모델을 배치한다. 모델 크기에 맞춘 충돌 상자를 붙여 지나가지 못하게 한다.
func _place_decor(entries: Array) -> void:
	for entry in entries:
		var model: Node3D = load(DECOR_DIR + entry.model + ".glb").instantiate()
		model.scale = Vector3.ONE * float(entry.scale)
		var body := StaticBody3D.new()
		body.position = Vector3(entry.pos[0], 0.0, entry.pos[1])
		body.rotation.y = deg_to_rad(float(entry.rot))
		body.add_child(model)
		$Decor.add_child(body)
		var box := AABB()
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			box = box.merge(body.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb())
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = box.size
		shape.position = box.get_center()
		body.add_child(shape)


## 웨이브가 오면 습격 곰마다 겉모습을 붙인다. 겉모습은 곰이 쓰러지면 스스로 사라진다.
func _on_raid_started(_wave: int) -> void:
	for raider in sim.raid.bears:
		var view := BearScene.instantiate()
		$Bears.add_child(view)
		view.setup(sim, raider, true)
		Juice.pop(view, Vector3(0.3, 1.6, 0.3), 0.35)


## 땅에 눕힌 빨간 삼각형. 경고 중에는 곰이 나올 곳을, 습격 중에는 가장 가까운 곰을 가리킨다.
func _make_arrow() -> Node3D:
	var pivot := Node3D.new()
	var arrow := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.8, 1.0, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.3, 0.25)
	mesh.material = material
	arrow.mesh = mesh
	arrow.rotation.x = -PI / 2.0  # 꼭짓점(+Y)이 앞(-Z)을 보게 눕힌다
	arrow.position = Vector3(0.0, 0.15, -ARROW_RADIUS)
	pivot.add_child(arrow)
	pivot.visible = false
	add_child(pivot)
	return pivot


func _update_arrow() -> void:
	var target := Vector2.INF
	var here := sim.player.pos
	if sim.raid.state == Raid.State.WARNING:
		target = sim.raid.spawn_pos
	elif sim.raid.state == Raid.State.ATTACKING:
		for raider in sim.raid.bears:
			if raider.is_alive() and (target == Vector2.INF or here.distance_to(raider.pos) < here.distance_to(target)):
				target = raider.pos
	_raid_arrow.visible = target != Vector2.INF and here.distance_to(target) > ARROW_HIDE_DIST
	if _raid_arrow.visible:
		var dir := target - here
		_raid_arrow.position = _player.position
		_raid_arrow.rotation.y = atan2(-dir.x, -dir.y)


func _on_worker_hired(index: int) -> void:
	var worker := WorkerScene.instantiate()
	$Workers.add_child(worker)
	worker.setup(sim, index)
	Juice.pop(worker.get_node("Pivot"), Vector3(0.2, 1.6, 0.2), 0.4)


## 플레이어가 친 한 방마다 화면을 살짝 흔들고 아주 짧게 멈춘다. 일꾼이 친 것은 흔들지 않는다.
func _on_hit(_index: int, agent: SimAgent) -> void:
	if agent == sim.player:
		_camera.add_trauma(0.12)
		_hit_stop(0.03)


func _on_tree_felled(_index: int, agent: SimAgent) -> void:
	if agent == sim.player:
		_camera.add_trauma(0.45)
		_hit_stop(0.07)


## 내가 잡았을 때만 크게 흔든다(포탑이 잡은 습격 곰은 흔들지 않는다).
func _on_bear_killed(_index: int, agent: SimAgent) -> void:
	if agent == sim.player:
		_camera.add_trauma(0.7)
		_hit_stop(0.12)


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


func _process(delta: float) -> void:
	_play_player_sounds(delta)
	_update_arrow()
	# 눈은 플레이어 위 하늘에서 내린다(입자는 월드 좌표라 걸어도 같이 미끄러지지 않는다).
	$Snow.position = _player.position + SNOW_OFFSET
