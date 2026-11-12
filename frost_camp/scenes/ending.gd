extends CanvasLayer
## 탈출 컷신. 영화 비율 띠가 내려오고, 플레이어가 부두를 걸어 배에 오르고, 뱃고동과 함께
## 카메라가 배 옆으로 돌아간 뒤, 배가 얼음을 밀어내며 바다로 나아간다. 제목이 뜨고 흰색으로 덮이면 결과 화면을 띄운다.

const BAR_HEIGHT := 90.0
const DOCK_START := Vector3(26.0, 0.0, -3.0)
const DECK_SPOT := Vector3(-0.8, 1.0, 0.0)  # 배 기준 갑판 위 자리
const BOARD_TIME := 2.2
const SAIL_TIME := 8.0
const TITLE_TIME := 2.5
const FADE_TIME := 0.9

var _top: ColorRect
var _bottom: ColorRect
var _title: Label
var _subtitle: Label
var _white: ColorRect
var _camera: Camera3D
var _ship: Node3D
var _follow := false


func _ready() -> void:
	layer = 5
	_top = _bar(true)
	_bottom = _bar(false)
	_title = _label(72, -40.0)
	_subtitle = _label(30, 40.0)
	_white = ColorRect.new()
	_white.color = Color(1, 1, 1, 0)
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)


## main이 엔딩 때 부른다. 끝나면 결과 화면을 띄운다.
func play(main: Node3D, sim: FrostSim) -> void:
	var player: Node3D = main.get_node("Player")
	var model: Node3D = player.get_node("Pivot/Model")
	var pivot: Node3D = player.get_node("Pivot")
	var sfx: Node = main.get("_sfx")
	_ship = main.get_node("Ship")
	player.set_physics_process(false)
	main.get_node("HUD").visible = false

	# 1. 띠가 내려오고 카메라가 부두를 잡는다.
	_camera = Camera3D.new()
	main.add_child(_camera)
	_camera.global_position = Vector3(22.0, 7.0, 9.0)
	_camera.look_at(Vector3(29.0, 0.5, -3.0))
	_camera.make_current()
	var bars := create_tween().set_parallel()
	bars.tween_property(_top, "offset_bottom", BAR_HEIGHT, 0.6)
	bars.tween_property(_bottom, "offset_top", -BAR_HEIGHT, 0.6)

	# 2. 플레이어가 부두를 걸어 배에 오른다.
	player.global_position = DOCK_START
	pivot.rotation.y = -PI / 2.0  # +X(바다)를 본다
	model.set_moving(true)
	var deck := _ship.global_position + DECK_SPOT
	var walk := create_tween()
	walk.tween_property(player, "global_position", Vector3(deck.x, 0.0, deck.z), BOARD_TIME * 0.75)
	walk.tween_property(player, "global_position", deck, BOARD_TIME * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await walk.finished
	model.set_moving(false)
	player.reparent(_ship)

	# 3. 뱃고동, 카메라가 배 옆 낮은 곳으로 돈다.
	sfx.play("raid")
	var swing := create_tween()
	swing.tween_method(func(t: float) -> void:
		_camera.global_position = Vector3(22.0, 7.0, 9.0).lerp(_ship.global_position + Vector3(-2.0, 2.5, 10.0), t)
		_camera.look_at(_ship.global_position + Vector3(1.0, 1.5, 0.0)), 0.0, 1.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await swing.finished

	# 4. 배가 얼음을 밀어내며 나아가고, 카메라는 뒤 옆에서 따라간다.
	_follow = true
	_ship.sail_away(SAIL_TIME)
	await get_tree().create_timer(SAIL_TIME * 0.55).timeout

	# 5. 제목이 뜬다.
	sfx.play("win")
	var seconds := int(sim.time)
	_title.text = "섬 탈출!"
	_subtitle.text = "%d:%02d 만에 얼음섬을 떠났다" % [seconds / 60, seconds % 60]
	for label in [_title, _subtitle]:
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(0.6, 0.6)
		var pop := create_tween().set_parallel()
		pop.tween_property(label, "modulate:a", 1.0, 0.4)
		pop.tween_property(label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(TITLE_TIME).timeout

	# 6. 흰색으로 덮고 결과 화면을 띄운 뒤 걷어 낸다.
	var fade := create_tween()
	fade.tween_property(_white, "color:a", 1.0, FADE_TIME)
	await fade.finished
	_follow = false
	_title.visible = false
	_subtitle.visible = false
	main.get_node("Result").show_result(sim)
	create_tween().tween_property(_white, "color:a", 0.0, FADE_TIME)


func _process(_delta: float) -> void:
	if _follow:
		var ship_pos := _ship.global_position
		var want := ship_pos + Vector3(-9.0, 4.0, 8.0)
		_camera.global_position = _camera.global_position.lerp(want, 0.08)
		_camera.look_at(ship_pos + Vector3(5.0, 1.0, 0.0))


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


func _label(size: int, y: float) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.offset_top = y
	label.offset_bottom = y
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.2))
	label.modulate.a = 0.0
	add_child(label)
	return label
