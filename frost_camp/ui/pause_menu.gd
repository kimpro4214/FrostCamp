extends CanvasLayer
## 게임 중 오른쪽 위 일시정지 버튼(또는 Esc). 누르면 게임이 멈추고 패널이 뜬다: 계속하기, 처음으로, 종료.
## 웹에서는 창을 닫을 수 없으니 종료 버튼을 숨긴다.

## 메뉴가 열렸다(main이 이때 저장한다)
signal opened

const UiStyle := preload("res://frost_camp/ui/ui_style.gd")
const PauseIcon := preload("res://frost_camp/assets/icons/pause.png")

var _button: Button
var _overlay: Control


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Button.new()
	_button.icon = PauseIcon
	_button.expand_icon = true
	_button.custom_minimum_size = Vector2(56, 56)
	_button.add_theme_stylebox_override("normal", UiStyle.panel(16, 6.0))
	_button.add_theme_stylebox_override("hover", UiStyle.panel(16, 6.0, Color(0.15, 0.2, 0.32, 0.92)))
	_button.add_theme_stylebox_override("pressed", UiStyle.panel(16, 6.0))
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left = -72.0
	_button.offset_top = 16.0
	_button.offset_right = -16.0
	_button.offset_bottom = 72.0
	_button.pressed.connect(open)
	add_child(_button)
	_build_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _overlay.visible:
			close()
		else:
			open()


## 게임 중일 때만 버튼을 보인다(시작 화면·컷신에서는 main이 숨긴다).
func set_available(available: bool) -> void:
	_button.visible = available
	if not available and _overlay.visible:
		close()


func open() -> void:
	if not _button.visible:
		return
	_overlay.visible = true
	opened.emit()
	get_tree().paused = true
	_overlay.find_child("Resume", true, false).grab_focus()


func close() -> void:
	_overlay.visible = false
	get_tree().paused = false


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.06, 0.12, 0.55)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(22, 36.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := UiStyle.label("일시정지", 44, UiStyle.ICE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_menu_button("계속하기", "Resume", close))
	box.add_child(_menu_button("처음으로", "Restart", func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene()))
	if not OS.has_feature("web"):
		box.add_child(_menu_button("종료", "Quit", func() -> void: get_tree().quit()))


func _menu_button(text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(280, 64)
	UiStyle.style_button(button, 30)
	button.pressed.connect(action)
	return button
