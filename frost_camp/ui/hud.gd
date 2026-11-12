extends CanvasLayer
## 화면 위 정보: 지갑의 돈, 등 뒤 적재량, 체력, 온기.

var sim: FrostSim

@onready var joystick: Control = $Joystick
@onready var _money_label: Label = $Top/Money
@onready var _stack_label: Label = $Top/Stack
@onready var _hp_label: Label = $Top/Hp
@onready var _warmth_label: Label = $Top/Warmth


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim


func _process(_delta: float) -> void:
	_money_label.text = "$ %d" % sim.money
	var stack := sim.player.stack
	_stack_label.text = "%d / %d" % [stack.items.size(), stack.capacity]
	var player := sim.player
	if player.dazed_left > 0.0:
		_hp_label.text = "DAZED %.1f" % player.dazed_left
		_hp_label.modulate = Color(0.7, 0.7, 0.75)
	else:
		_hp_label.text = "HP %d" % ceili(player.hp)
		_hp_label.modulate = Color.WHITE
	if player.warmth <= 0.0:
		_warmth_label.text = "FROZEN"
	else:
		_warmth_label.text = "WARM %d%%" % ceili(player.warmth / player.max_warmth * 100.0)
