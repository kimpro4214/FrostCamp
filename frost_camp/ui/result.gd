extends CanvasLayer
## 엔딩 결과 화면. 탈출 시간에 따른 별 등급과 플레이 기록(시간, 번 돈, 잡은 곰, 일꾼)을 줄마다 보여 주고 다시 시작할 수 있다.

const UiStyle := preload("res://frost_camp/ui/ui_style.gd")
const StarIcon := preload("res://frost_camp/assets/icons/star.png")
const EMPTY_STAR := Color(0.3, 0.34, 0.45)
## 이 시간(분) 안에 탈출하면 별 3개, 다음 값 안이면 2개, 아니면 1개
const STAR_MINUTES := [25.0, 30.0]

var _rows: GridContainer
var _stars: HBoxContainer

@onready var _box: VBoxContainer = $Center/Panel/Box


func _ready() -> void:
	visible = false
	$Center/Panel.add_theme_stylebox_override("panel", UiStyle.panel(22, 40.0))
	$Center/Panel/Box/Stats.visible = false
	var title: Label = $Center/Panel/Box/Title
	title.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	title.add_theme_constant_override("outline_size", 10)
	_stars = HBoxContainer.new()
	_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars.add_theme_constant_override("separation", 12)
	for i in 3:
		var star := TextureRect.new()
		star.texture = StarIcon
		star.custom_minimum_size = Vector2(64, 64)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_stars.add_child(star)
	_box.add_child(_stars)
	_box.move_child(_stars, 1)
	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.add_theme_constant_override("h_separation", 48)
	_rows.add_theme_constant_override("v_separation", 10)
	_box.add_child(_rows)
	_box.move_child(_rows, 2)
	var again: Button = $Center/Panel/Box/Again
	UiStyle.style_button(again, 30)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())


func show_result(sim: FrostSim) -> void:
	var seconds := int(sim.time)
	var minutes := sim.time / 60.0
	var stars := 3 if minutes <= STAR_MINUTES[0] else (2 if minutes <= STAR_MINUTES[1] else 1)
	for i in 3:
		_stars.get_child(i).modulate = UiStyle.GOLD if i < stars else EMPTY_STAR
	for child in _rows.get_children():
		child.queue_free()
	for row in [
		["탈출 시간", "%d:%02d" % [seconds / 60, seconds % 60]],
		["번 돈", "$%d" % sim.total_earned],
		["잡은 곰", "%d마리" % sim.bears_killed],
		["고용한 일꾼", "%d명" % sim.workers.size()],
	]:
		var key := UiStyle.label(row[0], 30, Color(0.8, 0.88, 1.0))
		var value := UiStyle.label(row[1], 34, Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(key)
		_rows.add_child(value)
	visible = true
	$Center/Panel/Box/Again.grab_focus()
	var panel: Control = $Center/Panel
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.7, 0.7)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
