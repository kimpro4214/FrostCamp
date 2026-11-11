extends Control
## 가상 조이스틱. 화면 어디든 누른 곳이 중심이 되고, 끌어당긴 방향과 세기를 vector로 낸다.

const RADIUS := 80.0
const KNOB_RADIUS := 30.0

var vector := Vector2.ZERO
var _touch := -1
var _origin := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_origin = event.position
		elif not event.pressed and event.index == _touch:
			_touch = -1
			vector = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch:
		vector = ((event.position - _origin) / RADIUS).limit_length(1.0)
		queue_redraw()


func _draw() -> void:
	if _touch == -1:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.25))
	draw_circle(_origin + vector * RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.6))
