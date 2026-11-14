extends CanvasLayer
## 화면 위 정보: 왼쪽 위에 둥근 칩(돈, 등짐, 체력 막대, 온기 막대), 가운데 위에 습격 배너, 가운데에 고급 자원 알림.
## 보스 레이드 중에는 습격 배너 대신 곰왕 체력 막대와 남은 용병, 아래쪽에 무기 버튼 3개(1, 2, 3 키)를 띄운다.

const UiStyle := preload("res://frost_camp/ui/ui_style.gd")
const HudIcon := preload("res://frost_camp/ui/hud_icon.gd")
const BasketIcon := preload("res://frost_camp/assets/icons/shoppingBasket.png")
const WarningIcon := preload("res://frost_camp/assets/icons/warning.png")
const WARNING_COLOR := Color(1.0, 0.45, 0.35)
const CALM_COLOR := Color(0.85, 0.9, 1.0)
const CLEAR_COLOR := Color(0.5, 1.0, 0.55)
const HP_COLOR := Color(1.0, 0.36, 0.38)
const WARMTH_COLOR := Color(0.45, 0.8, 1.0)
const FROZEN_COLOR := Color(0.6, 0.65, 0.75)
## 방어 성공 문구를 띄워 두는 시간(초)
const CLEAR_SHOW_TIME := 2.5
## 고급 자원 알림 문구
const PREMIUM_TEXT := {"gold_salmon": "황금 연어! +$60", "gem": "보석! +$120"}

var sim: FrostSim
var _money_label: Label
var _stack_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _warmth_bar: ProgressBar
var _warmth_text: Label
var _fire_label: Label
var _raid_panel: PanelContainer
var _raid_icon: TextureRect
var _raid_label: Label
var _toast: Label
var _clear_left := 0.0
var _raid_ui: Control
var _boss_bar: ProgressBar
var _merc_label: Label
var _weapon_buttons := {}
const WEAPON_NAMES := {"harpoon": "1  작살총", "spread": "2  산탄 작살", "cannon": "3  얼음 대포"}

@onready var joystick: Control = $Joystick


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	_build_chips()
	_build_raid_banner()
	_build_toast()
	_build_raid_ui()
	sim.cash_collected.connect(func(_stall: int, _amount: int, _agent: SimAgent) -> void: _punch(_money_label))
	sim.raid_warning.connect(func(_wave: int, _pos: Vector2) -> void: _punch(_raid_panel))
	sim.raid_cleared.connect(func(_wave: int) -> void:
		_clear_left = CLEAR_SHOW_TIME
		_punch(_raid_panel))
	sim.premium_found.connect(func(item: String, _pos: Vector2) -> void: _show_toast(PREMIUM_TEXT.get(item, item)))
	sim.crystal_glowed.connect(func(_i: int) -> void: _show_toast("광맥에 빛나는 빙결정이 나타났다!"))


func _process(delta: float) -> void:
	var player := sim.player
	_money_label.text = "$ %d" % sim.money
	_stack_label.text = "%d / %d" % [player.stack.items.size(), player.stack.capacity]
	_hp_bar.value = player.hp / player.max_hp * 100.0
	_hp_text.text = "기절 %.1f" % player.dazed_left if player.dazed_left > 0.0 else "%d" % ceili(player.hp)
	_warmth_bar.value = player.warmth / player.max_warmth * 100.0
	_set_bar_color(_warmth_bar, WARMTH_COLOR if player.warmth > 0.0 else FROZEN_COLOR)
	_warmth_text.text = "얼었다" if player.warmth <= 0.0 else "%d%%" % ceili(_warmth_bar.value)
	# 모닥불이 저절로 채워지지 않을 때 연료가 떨어져 가면 알린다.
	var fire: Dictionary = sim.heat_sources[0]
	var low: bool = fire.fuel_max > 0.0 and not sim.is_fire_auto(fire) and fire.fuel < fire.fuel_max * 0.3
	_fire_label.visible = low
	if low:
		_fire_label.text = "모닥불이 꺼졌다! 원목을 넣자" if fire.fuel <= 0.0 else "모닥불이 꺼져 간다"
	_update_raid(delta)
	_update_boss_raid()


## 왼쪽 위 칩 네 개: 돈, 등짐, 체력, 온기. 그 아래 모닥불 알림 한 줄.
func _build_chips() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(16, 16)
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_money_label = UiStyle.label("$ 0", 34, UiStyle.GOLD)
	_money_label.custom_minimum_size.x = 150
	row.add_child(_chip(HudIcon.new("coin"), [_money_label]))
	var basket := TextureRect.new()
	basket.texture = BasketIcon
	basket.custom_minimum_size = Vector2(40, 40)
	basket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	basket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stack_label = UiStyle.label("0 / 10", 30)
	row.add_child(_chip(basket, [_stack_label]))
	_hp_bar = _bar(HP_COLOR)
	_hp_text = UiStyle.label("10", 24)
	row.add_child(_chip(HudIcon.new("heart"), [_hp_bar, _hp_text]))
	_warmth_bar = _bar(WARMTH_COLOR)
	_warmth_text = UiStyle.label("100%", 24)
	row.add_child(_chip(HudIcon.new("snow"), [_warmth_bar, _warmth_text]))
	_fire_label = UiStyle.label("", 26, Color(1.0, 0.6, 0.3))
	_fire_label.visible = false
	column.add_child(_fire_label)


func _chip(icon: Control, parts: Array) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiStyle.panel(22, 8.0))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(box)
	box.add_child(icon)
	for part in parts:
		part.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(part)
	return chip


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 18)
	bar.show_percentage = false
	bar.value = 100.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.03, 0.05, 0.1, 0.9)
	back.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("background", back)
	_set_bar_color(bar, color)
	return bar


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null or fill.bg_color != color:
		fill = StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(9)
		bar.add_theme_stylebox_override("fill", fill)


func _build_raid_banner() -> void:
	_raid_panel = PanelContainer.new()
	_raid_panel.add_theme_stylebox_override("panel", UiStyle.panel(20, 10.0))
	_raid_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_raid_panel.offset_top = 84.0
	_raid_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_raid_panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_raid_panel.add_child(box)
	_raid_icon = TextureRect.new()
	_raid_icon.texture = WarningIcon
	_raid_icon.custom_minimum_size = Vector2(36, 36)
	_raid_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_raid_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_raid_icon)
	_raid_label = UiStyle.label("", 30)
	box.add_child(_raid_label)


func _build_toast() -> void:
	_toast = UiStyle.label("", 44, Color(1.0, 0.82, 0.25))
	_toast.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.0))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.offset_top = -140.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)


## 습격 경고와 남은 곰, 방어 성공, 다음 습격까지 남은 시간을 배너 한 줄로 보여 준다. 경고·습격 중에만 경고 아이콘을 띄운다.
func _update_raid(delta: float) -> void:
	var raid := sim.raid
	_clear_left = maxf(_clear_left - delta, 0.0)
	_raid_panel.visible = true
	_raid_icon.visible = raid.state == Raid.State.WARNING or raid.state == Raid.State.ATTACKING
	match raid.state:
		Raid.State.WARNING:
			_raid_label.text = "북극곰이 몰려온다! %d" % ceili(raid.time_left)
			_raid_label.modulate = WARNING_COLOR
		Raid.State.ATTACKING:
			_raid_label.text = "습격 %d웨이브, 남은 곰 %d" % [raid.wave, raid.alive_count()]
			_raid_label.modulate = WARNING_COLOR
		Raid.State.WAITING:
			if _clear_left > 0.0:
				_raid_label.text = "방어 성공!"
				_raid_label.modulate = CLEAR_COLOR
			else:
				_raid_label.text = "다음 습격 %d:%02d" % [int(raid.time_left) / 60, int(raid.time_left) % 60]
				_raid_label.modulate = CALM_COLOR
		_:
			_raid_panel.visible = false


## 레이드 화면: 위쪽 곰왕 체력 막대와 남은 용병, 아래쪽 무기 버튼
func _build_raid_ui() -> void:
	_raid_ui = Control.new()
	_raid_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raid_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_ui.visible = false
	add_child(_raid_ui)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiStyle.panel(20, 10.0))
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 82.0
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_raid_ui.add_child(top)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	top.add_child(box)
	var title := UiStyle.label("빙하 곰왕", 26, Color(0.7, 0.88, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_boss_bar = _bar(Color(0.55, 0.75, 1.0))
	_boss_bar.custom_minimum_size = Vector2(320, 20)
	_boss_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_boss_bar)
	_merc_label = UiStyle.label("", 20)
	_merc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_merc_label)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_top = -96.0
	bottom.offset_bottom = -20.0
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.add_theme_constant_override("separation", 14)
	_raid_ui.add_child(bottom)
	for weapon in BossRaid.WEAPONS:
		var button := Button.new()
		button.text = WEAPON_NAMES[weapon]
		button.custom_minimum_size = Vector2(200, 64)
		button.focus_mode = Control.FOCUS_NONE
		UiStyle.style_button(button, 24)
		button.pressed.connect(func() -> void: sim.boss_raid.select_weapon(weapon))
		bottom.add_child(button)
		_weapon_buttons[weapon] = button
	var hint := UiStyle.label("화면을 클릭하면 그쪽으로 쏜다. 빨간 원을 피하자!", 22, Color(0.85, 0.9, 1.0))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -132.0
	hint.offset_bottom = -102.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raid_ui.add_child(hint)


func _update_boss_raid() -> void:
	var raid := sim.boss_raid
	_raid_ui.visible = raid.active
	if not raid.active:
		return
	_raid_panel.visible = false
	_boss_bar.value = float(raid.boss.hp) / raid.boss.max_hp * 100.0
	_merc_label.text = "용병 %d" % raid.mercs().size()
	for weapon in _weapon_buttons:
		var button: Button = _weapon_buttons[weapon]
		var owned := raid.has_weapon(weapon)
		button.disabled = not owned
		button.text = WEAPON_NAMES[weapon] if owned else WEAPON_NAMES[weapon] + " (잠김)"
		var chosen: bool = raid.weapon == weapon
		var ready: bool = not chosen or raid.cooldown <= 0.0
		button.modulate = Color(1, 1, 1, 1) if chosen and ready else (Color(1, 1, 1, 0.65) if chosen else Color(0.65, 0.7, 0.8, 0.85))


func _unhandled_key_input(event: InputEvent) -> void:
	if not sim or not sim.boss_raid.active or not event.pressed:
		return
	var keys := {KEY_1: "harpoon", KEY_2: "spread", KEY_3: "cannon"}
	if event is InputEventKey and keys.has(event.keycode):
		sim.boss_raid.select_weapon(keys[event.keycode])


## 화면 가운데 위에 금빛 알림을 잠깐 띄운다.
func show_toast(text: String) -> void:
	_show_toast(text)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_punch(_toast)
	var tween := _toast.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


## 숫자나 배너가 툭 커졌다가 돌아온다.
func _punch(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.25, 1.25)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
