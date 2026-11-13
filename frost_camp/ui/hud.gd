extends CanvasLayer
## 화면 위 정보: 지갑의 돈, 등 뒤 적재량, 체력, 온기, 습격 알림.

const WARNING_COLOR := Color(1.0, 0.45, 0.35)
const CALM_COLOR := Color(0.85, 0.9, 1.0, 0.8)
const CLEAR_COLOR := Color(0.5, 1.0, 0.55)
## 방어 성공 문구를 띄워 두는 시간(초)
const CLEAR_SHOW_TIME := 2.5

var sim: FrostSim
var _raid_label: Label
var _clear_left := 0.0
var _toast: Label
## 고급 자원 알림 문구
const PREMIUM_TEXT := {"gold_salmon": "황금 연어! +$60", "gem": "보석! +$120"}

@onready var joystick: Control = $Joystick
@onready var _money_label: Label = $Top/Money
@onready var _stack_label: Label = $Top/Stack
@onready var _hp_label: Label = $Top/Hp
@onready var _warmth_label: Label = $Top/Warmth


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	sim.cash_collected.connect(func(_stall: int, _amount: int, _agent: SimAgent) -> void: _punch(_money_label))
	_raid_label = Label.new()
	_raid_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_raid_label.offset_top = 70.0
	_raid_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_raid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raid_label.add_theme_font_size_override("font_size", 34)
	_raid_label.add_theme_constant_override("outline_size", 10)
	_raid_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	add_child(_raid_label)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_top = -140.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 44)
	_toast.add_theme_constant_override("outline_size", 12)
	_toast.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.0))
	_toast.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_toast.modulate.a = 0.0
	add_child(_toast)
	sim.premium_found.connect(func(item: String, _pos: Vector2) -> void: _show_toast(PREMIUM_TEXT.get(item, item)))
	sim.crystal_glowed.connect(func(_i: int) -> void: _show_toast("광맥에 빛나는 빙결정이 나타났다!"))
	sim.raid_warning.connect(func(_wave: int, _pos: Vector2) -> void: _punch(_raid_label))
	sim.raid_cleared.connect(func(_wave: int) -> void:
		_clear_left = CLEAR_SHOW_TIME
		_punch(_raid_label))


func _process(_delta: float) -> void:
	_money_label.text = "$ %d" % sim.money
	var stack := sim.player.stack
	_stack_label.text = "%d / %d" % [stack.items.size(), stack.capacity]
	var player := sim.player
	if player.dazed_left > 0.0:
		_hp_label.text = "기절 %.1f" % player.dazed_left
		_hp_label.modulate = Color(0.7, 0.7, 0.75)
	else:
		_hp_label.text = "체력 %d" % ceili(player.hp)
		_hp_label.modulate = Color.WHITE
	_update_raid(_delta)
	if player.warmth <= 0.0:
		_warmth_label.text = "꽁꽁 얼었다"
	else:
		_warmth_label.text = "온기 %d%%" % ceili(player.warmth / player.max_warmth * 100.0)
	# 모닥불이 저절로 채워지지 않을 때 연료가 떨어져 가면 알린다.
	var fire: Dictionary = sim.heat_sources[0]
	if fire.fuel_max > 0.0 and not sim.is_fire_auto(fire) and fire.fuel < fire.fuel_max * 0.3:
		_warmth_label.text += " · 모닥불이 꺼졌다!" if fire.fuel <= 0.0 else " · 모닥불이 꺼져 간다"


## 습격 경고와 남은 곰, 방어 성공, 다음 습격까지 남은 시간을 한 줄로 보여 준다.
func _update_raid(delta: float) -> void:
	var raid := sim.raid
	_clear_left = maxf(_clear_left - delta, 0.0)
	_raid_label.visible = true
	match raid.state:
		Raid.State.WARNING:
			_raid_label.text = "북극곰이 몰려온다! %d" % ceili(raid.time_left)
			_raid_label.modulate = WARNING_COLOR
		Raid.State.ATTACKING:
			_raid_label.text = "습격 %d웨이브 · 남은 곰 %d" % [raid.wave, raid.alive_count()]
			_raid_label.modulate = WARNING_COLOR
		Raid.State.WAITING:
			if _clear_left > 0.0:
				_raid_label.text = "방어 성공!"
				_raid_label.modulate = CLEAR_COLOR
			else:
				_raid_label.text = "다음 습격 %d:%02d" % [int(raid.time_left) / 60, int(raid.time_left) % 60]
				_raid_label.modulate = CALM_COLOR
		_:
			_raid_label.visible = false


## 화면 가운데 위에 금빛 알림을 잠깐 띄운다.
func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_punch(_toast)
	var tween := _toast.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## 돈이 들어오면 숫자가 툭 커졌다가 돌아온다.
func _punch(label: Control) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.35, 1.35)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
