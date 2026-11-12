extends CanvasLayer
## 엔딩 결과 화면. 플레이 시간, 번 돈, 잡은 곰 수, 고용한 일꾼 수를 보여 주고 다시 시작할 수 있다.

@onready var _stats: Label = $Center/Panel/Box/Stats


func _ready() -> void:
	visible = false
	$Center/Panel/Box/Again.pressed.connect(func() -> void: get_tree().reload_current_scene())


func show_result(sim: FrostSim) -> void:
	var seconds := int(sim.time)
	_stats.text = "플레이 시간  %d:%02d\n번 돈  $%d\n잡은 곰  %d마리\n고용한 일꾼  %d명" % [
		seconds / 60, seconds % 60, sim.total_earned, sim.bears_killed, sim.workers.size()]
	visible = true
	$Center/Panel/Box/Again.grab_focus()
