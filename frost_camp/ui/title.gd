extends CanvasLayer
## 시작 화면. 캠프 위에 제목과 (저장이 있으면 이어하기,) 시작·종료 버튼, 조작 안내를 띄운다. 시작을 누르면(또는 Enter·Space) 사라지고 규칙 슬라이드로 넘어간다.
## 웹에서는 창을 닫을 수 없으니 종료 버튼을 숨긴다.

signal started
## 저장이 있을 때 "이어하기"를 눌렀다
signal continued

const UiStyle := preload("res://frost_camp/ui/ui_style.gd")
const Records := preload("res://frost_camp/ui/records.gd")

var _root: Control


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.16, 0.45)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := UiStyle.label("얼음 위의 작은 상점", 76, UiStyle.ICE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UiStyle.label("곰을 잡고, 물건을 팔고, 쇄빙선을 완성해 섬을 탈출하자", 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var records := Records.read()
	if records.best_time > 0.0:
		var best := UiStyle.label("최고 기록 %s, 탈출 %d번" % [Records.format_time(records.best_time), int(records.clears)], 24, UiStyle.GOLD)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(best)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	box.add_child(gap)
	var save := SaveGame.read()
	var resume: Button = null
	if not save.is_empty():
		var seconds := int(save.sim.time)
		resume = Button.new()
		resume.text = "이어하기  %d:%02d" % [seconds / 60, seconds % 60]
		resume.custom_minimum_size = Vector2(320, 76)
		resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UiStyle.style_button(resume, 34)
		resume.pressed.connect(_continue)
		box.add_child(resume)
	var start := Button.new()
	start.text = "새로 시작" if resume else "시작하기"
	start.custom_minimum_size = Vector2(320, 76)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(start, 36)
	start.pressed.connect(_start)
	box.add_child(start)
	if not OS.has_feature("web"):
		var quit := Button.new()
		quit.text = "종료"
		quit.custom_minimum_size = Vector2(200, 56)
		quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UiStyle.style_button(quit, 26)
		quit.modulate = Color(0.8, 0.85, 0.95)
		quit.pressed.connect(func() -> void: get_tree().quit())
		box.add_child(quit)
	var help := PanelContainer.new()
	help.add_theme_stylebox_override("panel", UiStyle.panel(14, 16.0))
	help.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(help)
	var tips := UiStyle.label(
		("이동: 화면을 끌어서" if UiStyle.is_touch() else "이동: 방향키, WASD")
		+ "\n멈춰 서 있으면 베고, 낚고, 사고, 판다", 24)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_child(tips)
	# 오른쪽 아래 작은 버전 표시(project.godot의 application/config/version)
	var version := UiStyle.label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 20, Color(0.8, 0.86, 0.95, 0.8))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -120.0
	version.offset_top = -40.0
	version.offset_right = -16.0
	version.offset_bottom = -12.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(version)
	(resume if resume else start).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start()


func _start() -> void:
	if not visible:
		return
	visible = false
	started.emit()
	queue_free()


func _continue() -> void:
	if not visible:
		return
	visible = false
	continued.emit()

