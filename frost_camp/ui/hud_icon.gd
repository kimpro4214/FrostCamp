extends Control
## HUD에 쓰는 간단한 그림 아이콘(아이콘 팩에 없는 것): 동전, 하트, 눈송이.

@export_enum("coin", "heart", "snow") var kind := "coin"


func _init(icon_kind: String = "coin") -> void:
	kind = icon_kind
	custom_minimum_size = Vector2(40, 40)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	match kind:
		"coin":
			draw_circle(c, r, Color(0.85, 0.6, 0.1))
			draw_circle(c, r * 0.8, Color(1.0, 0.84, 0.3))
			draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.45), Vector2(r * 0.24, r * 0.9)), Color(0.85, 0.6, 0.1))
		"heart":
			var color := Color(1.0, 0.36, 0.38)
			draw_circle(c + Vector2(-r * 0.45, -r * 0.2), r * 0.52, color)
			draw_circle(c + Vector2(r * 0.45, -r * 0.2), r * 0.52, color)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.95, -r * 0.05), c + Vector2(r * 0.95, -r * 0.05), c + Vector2(0, r * 0.95)]), color)
		"snow":
			var color := Color(0.7, 0.9, 1.0)
			for i in 3:
				var dir := Vector2.from_angle(PI / 3.0 * i) * r
				draw_line(c - dir, c + dir, color, maxf(r * 0.22, 2.0))
			draw_circle(c, r * 0.22, color)
