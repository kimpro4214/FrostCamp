extends RefCounted
## 화면 UI가 같이 쓰는 모양: 둥근 패널, 버튼, 글자. 시작 화면·HUD·결과 화면이 같은 느낌을 갖게 한다.

const PANEL_COLOR := Color(0.09, 0.13, 0.21, 0.88)
const BORDER_COLOR := Color(0.55, 0.75, 0.95, 0.9)
const GOLD := Color(1.0, 0.84, 0.3)
const ICE := Color(0.62, 0.86, 1.0)
const OUTLINE := Color(0.06, 0.08, 0.14)


## 둥근 모서리와 얇은 테두리가 있는 반투명 패널
static func panel(radius := 18, margin := 18.0, color := PANEL_COLOR) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(2)
	box.border_color = BORDER_COLOR
	box.set_content_margin_all(margin)
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 6
	return box


## 큰 금빛 버튼(보통, 올림, 누름 세 모양)
static func style_button(button: Button, font_size := 32) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = GOLD.darkened(0.15 if state == "pressed" else 0.0).lightened(0.12 if state == "hover" else 0.0)
		box.set_corner_radius_all(16)
		box.set_content_margin_all(14.0)
		box.border_color = Color(1, 1, 1, 0.9) if state == "focus" else GOLD.darkened(0.35)
		box.set_border_width_all(3)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.2, 0.12, 0.02))


## 테두리 있는 글자
static func label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(font_size / 6, 4))
	return l
