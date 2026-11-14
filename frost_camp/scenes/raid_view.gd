extends Node3D
## 보스 레이드의 겉모습과 입력.
## - 기지의 빙하 동굴 입구: 푸른 얼음 문과 빛 원판. 서 있으면 차오르고, 작살총이 없으면 잠겨 보인다.
## - 레이드 영역: 어두운 얼음 바닥, 둘레의 얼음 기둥.
## - 곰왕(북극곰 모델 2.5배, 짙은 청회색, 얼음 뿔 왕관)과 작은 곰, 바닥의 빨간 경고 원, 작살·포탄.
## - 출발·귀환 때 흰 섬광과 함께 플레이어를 옮긴다.
## - 레이드 중 마우스 클릭(또는 짧게 톡 친 터치)한 바닥 자리로 쏜다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const BearScene := preload("res://frost_camp/scenes/bear.tscn")
const BOSS_SCALE := 2.5
const MINION_SCALE := 0.7
const BOSS_FUR := Color(0.2, 0.26, 0.38)
const MINION_FUR := Color(0.55, 0.6, 0.7)
const CROWN_COLOR := Color(0.6, 0.9, 1.0, 0.9)
const SLAM_COLOR := Color(1.0, 0.2, 0.15, 0.45)
const PORTAL_COLOR := Color(0.45, 0.85, 1.0, 0.75)
const FLOOR_COLOR := Color(0.32, 0.42, 0.58)
const PILLARS := 14
const TAP_TIME := 0.25
const TAP_MOVE := 20.0
## 무기별 작살 색과 굵기
const SHOT_LOOK := {
	"harpoon": [Color(0.75, 0.8, 0.88), 0.05], "spread": [Color(0.6, 0.95, 1.0), 0.04],
	"cannon": [Color(0.5, 0.85, 1.0), 0.22], "merc": [Color(1.0, 0.85, 0.4), 0.03],
}

var sim: FrostSim
var raid: BossRaid
var _main: Node3D
var _player: Node3D
var _camera: Camera3D
var _boss: Node3D
var _boss_body: Node3D
var _boss_fill: Node3D
var _minions := {}
var _slams := {}
var _portal_fill: MeshInstance3D
var _portal_label: Label3D
var _flash: ColorRect
var _walk := 0.0
var _touch_start := {}


func setup(main: Node3D, frost_sim: FrostSim) -> void:
	_main = main
	sim = frost_sim
	raid = sim.boss_raid
	_player = main.get_node("Player")
	_camera = main.get_node("Camera3D")
	if not raid.is_available():
		return
	_build_portal()
	_build_arena()
	_boss = _make_bear(BOSS_SCALE, BOSS_FUR)
	_boss_body = _boss.get_node("Body")
	_boss_fill = _boss.get_node("HpBar/Fill")
	_boss.get_node("HpBar").position.y = 2.1 * BOSS_SCALE * 0.75
	_boss.get_node("HpBar").scale = Vector3(2.5, 1.5, 1.0)
	_add_crown(_boss_body)
	_boss.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	raid.started.connect(_on_started)
	raid.ended.connect(_on_ended)
	raid.shot.connect(_on_shot)
	raid.slam_warned.connect(_on_slam_warned)
	raid.slammed.connect(_on_slammed)
	raid.minion_spawned.connect(_on_minion_spawned)
	raid.minion_killed.connect(_on_minion_killed)
	raid.boss_hit.connect(func(damage: int) -> void:
		Juice.float_text(self, _boss.global_position + Vector3(0.0, 4.5, 0.0), "-%d" % damage, Color(1.0, 0.5, 0.4), 72))
	raid.agent_hit.connect(func(_pos: Vector2) -> void: _camera.add_trauma(0.25))


func _process(delta: float) -> void:
	if _portal_fill == null:
		return
	var ready := raid.can_start()
	_portal_fill.scale = Vector3.ONE * maxf(raid.portal_progress(), 0.001)
	_portal_label.text = "빙하 동굴\n곰왕 레이드" if ready or raid.active else "빙하 동굴\n작살총 필요"
	_portal_label.modulate = Color.WHITE if ready else Color(0.7, 0.78, 0.9)
	if not raid.active:
		return
	# 플레이어가 영역 밖으로 나가지 못하게 붙잡는다.
	var here := Vector2(_player.position.x, _player.position.z)
	var clamped := raid._clamp_arena(here)
	if clamped != here:
		_player.position = Vector3(clamped.x, _player.position.y, clamped.y)
	_sync_bear(_boss, _boss_body, raid.boss.pos, delta)
	_boss_fill.scale.x = maxf(float(raid.boss.hp) / raid.boss.max_hp, 0.001)
	_boss_fill.position.x = -0.6 * (1.0 - _boss_fill.scale.x)
	for i in _minions:
		var m: Dictionary = raid.minions[i] if i < raid.minions.size() else {}
		if m.is_empty():
			continue
		_sync_bear(_minions[i], _minions[i].get_node("Body"), m.pos, delta)
	for i in _slams:
		var s: Dictionary = raid.slams[i] if i < raid.slams.size() else {}
		if s.is_empty() or s.done:
			continue
		var t: float = 1.0 - s.left / float(raid.config.slam_warning)
		_slams[i].scale = Vector3(t, 1.0, t) * float(raid.config.slam_radius)


## 레이드 중 클릭(또는 짧은 톡)한 바닥 자리로 쏜다. 버튼 위 클릭은 UI가 먼저 가져간다.
func _unhandled_input(event: InputEvent) -> void:
	if raid == null or not raid.active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shoot_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_start[event.index] = [event.position, Time.get_ticks_msec()]
		elif _touch_start.has(event.index):
			var start: Array = _touch_start[event.index]
			_touch_start.erase(event.index)
			var quick: bool = Time.get_ticks_msec() - start[1] < TAP_TIME * 1000.0
			if quick and event.position.distance_to(start[0]) < TAP_MOVE:
				_shoot_at(event.position)


func _shoot_at(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.001:
		return
	var hit := origin + direction * (-origin.y / direction.y)
	var target := Vector2(hit.x, hit.z)
	if raid.shoot(target):
		_player.call("aim_and_shoot", target)


func _on_started() -> void:
	_teleport()
	_boss.visible = true
	_boss.position = Vector3(raid.boss.pos.x, 0.0, raid.boss.pos.y)
	Juice.pop(_boss, Vector3(0.3, 1.6, 0.3), 0.5)  # 몸통은 크기를 바꿔 두었으니 뿌리를 튕긴다


func _on_ended(won: bool, reward: int) -> void:
	_boss.visible = false
	for i in _minions:
		_minions[i].queue_free()
	_minions.clear()
	for i in _slams:
		_slams[i].queue_free()
	_slams.clear()
	_teleport()
	var hud := _main.get_node("HUD")
	if won:
		hud.show_toast("곰왕 처치! +$%d, 보석 +%d" % [reward, int(raid.config.gems)])
	else:
		hud.show_toast("후퇴... 다시 도전하자")


## 흰 섬광 속에서 플레이어 몸을 sim이 정한 자리로 옮기고 카메라를 붙인다.
func _teleport() -> void:
	_flash.color.a = 1.0
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)
	_player.position = Vector3(sim.player.pos.x, 0.0, sim.player.pos.y)
	_camera.snap()


func _on_shot(from: Vector2, to: Vector2, weapon: String) -> void:
	var look: Array = SHOT_LOOK.get(weapon, SHOT_LOOK.harpoon)
	var bolt := MeshInstance3D.new()
	var mesh: Mesh
	if weapon == "cannon":
		mesh = SphereMesh.new()
		mesh.radius = look[1]
		mesh.height = look[1] * 2.0
	else:
		mesh = CylinderMesh.new()
		mesh.top_radius = look[1]
		mesh.bottom_radius = look[1]
		mesh.height = 0.8
	mesh.material = _material(look[0], true)
	bolt.mesh = mesh
	add_child(bolt)
	var a := Vector3(from.x, 0.9, from.y)
	var b := Vector3(to.x, 0.9, to.y)
	bolt.look_at_from_position(a, b, Vector3.UP)
	if weapon != "cannon":
		bolt.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", b, 0.12 if weapon != "cannon" else 0.3)
	tween.tween_callback(func() -> void:
		if weapon == "cannon":
			var burst := Juice.make_burst(self, look[0], 18, 0.25)
			burst.global_position = b
			burst.restart()
			_camera.add_trauma(0.35)
		bolt.queue_free())


func _on_slam_warned(index: int) -> void:
	var s: Dictionary = raid.slams[index]
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.04
	mesh.material = _material(SLAM_COLOR, true)
	disc.mesh = mesh
	disc.position = Vector3(s.pos.x, 0.05, s.pos.y)
	disc.scale = Vector3(0.01, 1.0, 0.01)
	add_child(disc)
	_slams[index] = disc


func _on_slammed(index: int) -> void:
	if not _slams.has(index):
		return
	var disc: Node3D = _slams[index]
	_slams.erase(index)
	var burst := Juice.make_burst(self, Color(0.9, 0.95, 1.0), 16, 0.22)
	burst.global_position = disc.global_position + Vector3(0.0, 0.3, 0.0)
	burst.restart()
	_camera.add_trauma(0.3)
	Juice.pop(_boss, Vector3(1.2, 0.8, 1.2), 0.2)
	var tween := disc.create_tween()
	tween.tween_property(disc, "scale:y", 6.0, 0.08)
	tween.tween_property(disc, "scale", Vector3(0.01, 1.0, 0.01), 0.2)
	tween.tween_callback(disc.queue_free)


func _on_minion_spawned(index: int) -> void:
	var bear := _make_bear(MINION_SCALE, MINION_FUR)
	var m: Dictionary = raid.minions[index]
	bear.position = Vector3(m.pos.x, 0.0, m.pos.y)
	Juice.pop(bear, Vector3(0.3, 1.6, 0.3), 0.35)
	_minions[index] = bear


func _on_minion_killed(index: int) -> void:
	if not _minions.has(index):
		return
	var bear: Node3D = _minions[index]
	_minions.erase(index)
	var tween := bear.create_tween()
	tween.tween_property(bear.get_node("Body"), "rotation:z", PI / 2.0, 0.25)
	tween.tween_property(bear, "scale", Vector3(1.0, 0.01, 1.0), 0.25)
	tween.tween_callback(bear.queue_free)


## 북극곰 모델을 스크립트 없이 꺼내 크기와 털색을 바꾼다(움직임은 이 화면이 직접 맞춘다).
func _make_bear(size: float, fur: Color) -> Node3D:
	var bear: Node3D = BearScene.instantiate()
	bear.set_script(null)
	var material := _material(fur, false)
	for part in bear.get_node("Body").get_children():
		if not part.name in ["Nose", "EyeL", "EyeR"]:
			part.material_override = material
	bear.get_node("Body").scale = Vector3.ONE * size
	bear.get_node("HpBar").visible = size >= BOSS_SCALE
	add_child(bear)
	return bear


func _sync_bear(bear: Node3D, body: Node3D, pos: Vector2, delta: float) -> void:
	var target := Vector3(pos.x, 0.0, pos.y)
	var step := target - bear.position
	var moving := step.length() > 0.001
	if moving:
		body.rotation.y = atan2(-step.x, -step.z)
	bear.position = target
	_walk = _walk + delta * 7.0 if moving else 0.0
	var swing := sin(_walk) * 0.45 if moving else 0.0
	for leg in ["LegFL", "LegBR"]:
		body.get_node(leg).rotation.x = swing
	for leg in ["LegFR", "LegBL"]:
		body.get_node(leg).rotation.x = -swing


func _add_crown(body: Node3D) -> void:
	var material := _material(CROWN_COLOR, true)
	material.emission_enabled = true
	material.emission = Color(0.4, 0.8, 1.0)
	for k in 5:
		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.07
		mesh.height = 0.3 + 0.12 * (2 - absi(k - 2))
		mesh.material = material
		spike.mesh = mesh
		spike.position = Vector3(-0.24 + k * 0.12, 1.38, -1.28)
		body.add_child(spike)


func _build_portal() -> void:
	var root := Node3D.new()
	root.position = Vector3(raid.portal_pos.x, 0.0, raid.portal_pos.y)
	add_child(root)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.3
	base_mesh.bottom_radius = 1.3
	base_mesh.height = 0.04
	base_mesh.material = _material(Color(0.2, 0.35, 0.55, 0.8), true)
	base.mesh = base_mesh
	base.position.y = 0.02
	root.add_child(base)
	_portal_fill = MeshInstance3D.new()
	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = 1.3
	fill_mesh.bottom_radius = 1.3
	fill_mesh.height = 0.05
	fill_mesh.material = _material(PORTAL_COLOR, true)
	_portal_fill.mesh = fill_mesh
	_portal_fill.position.y = 0.03
	root.add_child(_portal_fill)
	var ice := _material(Color(0.6, 0.88, 1.0, 0.7), true)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.5, 2.6, 0.5)
		mesh.material = ice
		post.mesh = mesh
		post.position = Vector3(side * 1.3, 1.3, -0.6)
		root.add_child(post)
	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(3.2, 0.35, 0.5)
	top_mesh.material = ice
	top.mesh = top_mesh
	top.position = Vector3(0.0, 2.55, -0.6)
	root.add_child(top)
	_portal_label = Label3D.new()
	_portal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_portal_label.no_depth_test = true
	_portal_label.font_size = 64
	_portal_label.outline_size = 14
	_portal_label.position.y = 3.3
	root.add_child(_portal_label)


func _build_arena() -> void:
	var floor := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = raid.arena_radius + 1.5
	mesh.bottom_radius = raid.arena_radius + 1.5
	mesh.height = 0.06
	mesh.material = _material(FLOOR_COLOR, false)
	floor.mesh = mesh
	floor.position = Vector3(raid.arena_center.x, 0.03, raid.arena_center.y)
	add_child(floor)
	var ice := _material(Color(0.55, 0.8, 1.0, 0.85), true)
	for k in PILLARS:
		var pillar := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(1.2, 3.5 + (k % 3) * 1.2, 1.2)
		pm.material = ice
		pillar.mesh = pm
		var at := raid.arena_center + Vector2.from_angle(TAU * k / PILLARS) * (raid.arena_radius + 2.0)
		pillar.position = Vector3(at.x, pm.size.y / 2.0, at.y)
		add_child(pillar)


static func _material(color: Color, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
