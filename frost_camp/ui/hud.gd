extends CanvasLayer
## 화면 위 정보: 지갑의 돈과 등 뒤 적재량.

var sim: FrostSim

@onready var joystick: Control = $Joystick
@onready var _money_label: Label = $Top/Money
@onready var _stack_label: Label = $Top/Stack


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim


func _process(_delta: float) -> void:
	_money_label.text = "$ %d" % sim.money
	var stack := sim.player.stack
	_stack_label.text = "%d / %d" % [stack.items.size(), stack.capacity]
