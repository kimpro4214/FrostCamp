extends CanvasLayer
## 쇄빙선 부품 구매 컷신(약 2.5초). 영화 띠가 내려오고 카메라가 배로 날아가면, 부품이 위에서 떨어져 쿵 박힌다.
## 흰 섬광, 화면 흔들림, 묵직한 소리와 함께 "선체 완성! (2/5)"가 뜨고, 카메라가 플레이어로 돌아온다.
## 그동안 시간과 플레이어 입력은 멈춘다. 마지막 부품은 이 컷신 대신 엔딩이 나온다.

const UiStyle := preload("res://frost_camp/ui/ui_style.gd")
const BAR_HEIGHT := 70.0
const FLY_TIME := 0.6
const DROP_HEIGHT := 7.0
const DROP_TIME := 0.45
const HOLD_TIME := 1.0
## 배 기준 카메라 자리와 바라볼 곳
const VIEW_OFFSET := Vector3(-5.0, 5.5, 8.0)
const LOOK_OFFSET := Vector3(0.0, 1.0, 0.0)
## 부품 해금 이름 → ship.tscn의 Parts 아래 노드 이름
const PART_NODES := {"ship_hull": "Hull", "ship_engine": "Engine", "ship_blade": "Blade", "ship_mast": "Mast", "ship_fuel": "Fuel"}

var _top: ColorRect
var _bottom: ColorRect
var _white: ColorRect
var _banner: Label


func _ready() -> void:
	layer = 6
	_top = _bar(true)
	_bottom = _bar(false)
	_white = ColorRect.new()
	_white.color = Color(1, 1, 1, 0)
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)
	_banner = UiStyle.label("", 64, UiStyle.GOLD)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 120.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)


## main이 부품을 산 직후 부른다. 끝나면 스스로 사라지고 게임을 다시 흐르게 한다.
func play(main: Node3D, sim: FrostSim, part: String, part_name: String) -> void:
	var player: Node3D = main.get_node("Player")
	var follow: Camera3D = main.get_node("Camera3D")
	var ship: Node3D = main.get_node("Ship")
	var hud: CanvasLayer = main.get_node("HUD")
	var sfx: Node = main.get("_sfx")
	main.started = false
	player.set_physics_process(false)
	hud.visible = false

	# 1. 띠가 내려오고 카메라가 배로 날아간다.
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.global_transform = follow.global_transform
	camera.make_current()
	var to := ship.global_position + VIEW_OFFSET
	var look := ship.global_position + LOOK_OFFSET
	var bars := create_tween().set_parallel()
	bars.tween_property(_top, "offset_bottom", BAR_HEIGHT, 0.3)
	bars.tween_property(_bottom, "offset_top", -BAR_HEIGHT, 0.3)
	var start := camera.global_position
	var fly := create_tween()
	fly.tween_method(func(t: float) -> void:
		camera.global_position = start.lerp(to, t)
		camera.look_at(look), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fly.finished

	# 2. 부품이 위에서 떨어져 쿵 박힌다. 섬광과 흔들림, 묵직한 소리.
	var node: Node3D = ship.get_node_or_null("Parts/" + PART_NODES.get(part, ""))
	if node:
		var rest := node.position
		node.position = rest + Vector3(0.0, DROP_HEIGHT, 0.0)
		var drop := create_tween()
		drop.tween_property(node, "position", rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await drop.finished
	sfx.play("break", 4.0)
	sfx.play("raid")
	_white.color.a = 0.85
	create_tween().tween_property(_white, "color:a", 0.0, 0.35)
	var base := camera.global_position
	var shake := create_tween()
	shake.tween_method(func(t: float) -> void:
		var amount := (1.0 - t) * 0.35
		camera.global_position = base + Vector3(sin(t * 60.0) * amount, cos(t * 47.0) * amount, 0.0)
		camera.look_at(look), 0.0, 1.0, 0.4)
	var owned := 0
	for p in sim.balance.ending.ship_parts:
		if sim.unlocked.has(p):
			owned += 1
	_banner.text = "%s 완성! (%d/%d)" % [part_name, owned, sim.balance.ending.ship_parts.size()]
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(HOLD_TIME).timeout

	# 3. 카메라가 플레이어로 돌아오고 띠가 걷힌다.
	var back := create_tween().set_parallel()
	back.tween_property(_banner, "modulate:a", 0.0, 0.3)
	back.tween_property(_top, "offset_bottom", 0.0, 0.3)
	back.tween_property(_bottom, "offset_top", 0.0, 0.3)
	var from := camera.global_position
	var home := create_tween()
	home.tween_method(func(t: float) -> void:
		camera.global_transform = Transform3D(camera.global_transform.basis, from).interpolate_with(follow.global_transform, t), 0.0, 1.0, FLY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await home.finished
	follow.make_current()
	camera.queue_free()
	hud.visible = true
	player.set_physics_process(true)
	main.started = true
	queue_free()


func _bar(top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		bar.offset_bottom = 0.0
	else:
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
	add_child(bar)
	return bar
