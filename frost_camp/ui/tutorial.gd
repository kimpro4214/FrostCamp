extends CanvasLayer
## 규칙 설명 슬라이드. 시작하기를 누른 뒤 5장을 "다음"으로 넘기고, 마지막 장의 "시작"으로 게임이 흐른다.
## "이전"으로 앞 장으로 돌아가고, "건너뛰기"로 바로 시작할 수도 있다. Enter·Space는 "다음"과 같다.

signal finished

const UiStyle := preload("res://frost_camp/ui/ui_style.gd")
const HudIcon := preload("res://frost_camp/ui/hud_icon.gd")
const ICON_DIR := "res://frost_camp/assets/icons/"
## [제목, 아이콘(아이콘 파일 이름 또는 hud_icon 종류), 설명]
const SLIDES := [
	["목표: 섬을 탈출하자", "trophy", "얼음섬에 갇혔다. 돈을 모아 항구를 열고\n쇄빙선 부품 다섯 개를 모두 사면 탈출한다."],
	["서 있으면 저절로 일한다", "star", "나무, 바위, 얼음 구멍, 곰 옆에 서 있으면 저절로 일한다.\n판매대 옆에 서 있으면 팔고, 돈 더미 위에 서면 줍는다."],
	["구매 존과 일꾼", "home", "바닥의 둥근 존 위에 서 있으면 돈이 들어가며 산다.\n일꾼을 고용하면 베고, 낚고, 나르고, 돈을 걷어 준다."],
	["추위와 모닥불", "snow", "모닥불 원 밖에 오래 있으면 얼어서 느려진다.\n모닥불은 원목을 넣어야 계속 탄다.\n키우면 땅을 넓힐 수 있고, 일꾼이 불을 지핀다."],
	["습격과 레이드", "warning", "북극곰이 정해진 길목으로 쳐들어와 시설과 일꾼을 노린다.\n방벽, 포탑, 작살총으로 막자.\n힘이 붙으면 빙하 동굴의 곰왕을 잡으러 가자."],
]

var _index := 0
var _title: Label
var _icon_slot: CenterContainer
var _body: Label
var _dots: HBoxContainer
var _next: Button
var _prev: Button


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.08, 0.16, 0.55)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(24, 36.0))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	_title = UiStyle.label("", 44, UiStyle.ICE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_icon_slot = CenterContainer.new()
	_icon_slot.custom_minimum_size = Vector2(0, 110)
	box.add_child(_icon_slot)
	_body = UiStyle.label("", 26)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(640, 120)
	box.add_child(_body)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	box.add_child(_dots)
	for i in SLIDES.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		_dots.add_child(dot)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	_prev = Button.new()
	_prev.text = "이전"
	_prev.custom_minimum_size = Vector2(200, 64)
	UiStyle.style_button(_prev, 28)
	_prev.modulate = Color(0.8, 0.85, 0.95)
	_prev.pressed.connect(func() -> void:
		if _index > 0:
			_show(_index - 1))
	buttons.add_child(_prev)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(240, 64)
	UiStyle.style_button(_next, 30)
	_next.pressed.connect(_advance)
	buttons.add_child(_next)
	var skip := Button.new()
	skip.text = "건너뛰기"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 22)
	skip.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	skip.add_theme_color_override("font_hover_color", Color.WHITE)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(_finish)
	box.add_child(skip)
	box.move_child(skip, 0)
	_show(0)
	_next.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	if _index + 1 >= SLIDES.size():
		_finish()
	else:
		_show(_index + 1)


func _show(i: int) -> void:
	_index = i
	var slide: Array = SLIDES[i]
	_title.text = slide[0]
	_body.text = slide[2]
	for child in _icon_slot.get_children():
		child.queue_free()
	var icon: Control
	if slide[1] == "snow":
		icon = HudIcon.new("snow")
		icon.custom_minimum_size = Vector2(96, 96)
	else:
		var texture := TextureRect.new()
		texture.texture = load(ICON_DIR + slide[1] + ".png")
		texture.custom_minimum_size = Vector2(96, 96)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.modulate = UiStyle.GOLD
		icon = texture
	_icon_slot.add_child(icon)
	for d in _dots.get_child_count():
		(_dots.get_child(d) as ColorRect).color = UiStyle.GOLD if d == i else Color(0.35, 0.42, 0.55)
	_next.text = "시작!" if i + 1 >= SLIDES.size() else "다음"
	_prev.disabled = i == 0
	_prev.modulate.a = 0.35 if i == 0 else 1.0


func _finish() -> void:
	if not visible:
		return
	visible = false
	finished.emit()
	queue_free()
