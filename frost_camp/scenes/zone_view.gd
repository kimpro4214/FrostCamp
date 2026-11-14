extends Node3D
## 구매 존(또는 수리 존)의 겉모습. 낸 돈만큼 안쪽 원판이 차고, 위에 종류 아이콘·이름·남은 금액 배지를 띄운다.
## 지금 살 수 없으면 숨는다. 모닥불 단계만 모자라면 흐리게 보이며 자물쇠와 "모닥불 N단계 필요"를 띄운다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const ICON_DIR := "res://frost_camp/assets/icons/"
const GOLD := Color(1.0, 0.84, 0.3)
const LOCKED_COLOR := Color(0.7, 0.8, 0.95)
## 흰 눈 위에서도 보이게 아이콘을 짙은 남색으로 칠한다
const ICON_COLOR := Color(0.16, 0.24, 0.42)
## 효과 종류 → 아이콘 파일(Kenney Game Icons)
const EFFECT_ICONS := {
	"unlock": "home", "hire": "singleplayer", "haul": "shoppingCart", "tower": "target", "gun": "target",
	"stat": "plus", "holes": "plus", "bears": "plus", "walls": "plus", "fire": "plus",
}

var sim: FrostSim
var zone: PurchaseZone
var display_name: String
var _available: Callable
var _icon: Sprite3D
var _price: Label3D
var _icon_texture: Texture2D
var _locked_texture: Texture2D

@onready var _base: MeshInstance3D = $Base
@onready var _fill: MeshInstance3D = $Fill
@onready var _label: Label3D = $Label


## available은 존이 지금 보여야 하는지 돌려주는 함수다(구매 존은 선행 조건, 수리 존은 부서짐).
func setup(frost_sim: FrostSim, purchase_zone: PurchaseZone, zone_name: String, available: Callable) -> void:
	sim = frost_sim
	zone = purchase_zone
	display_name = zone_name
	_available = available
	position = Vector3(zone.pos.x, 0.0, zone.pos.y)
	var radius := float(sim.balance.purchase.zone_radius)
	scale = Vector3(radius, 1.0, radius)
	_icon_texture = load(ICON_DIR + _icon_name() + ".png")
	_locked_texture = load(ICON_DIR + "locked.png")
	_icon = Sprite3D.new()
	_icon.texture = _icon_texture
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.pixel_size = 0.01
	_icon.position.y = 1.55
	add_child(_icon)
	_label.font_size = 44
	_label.position.y = 0.85
	_price = Label3D.new()
	_price.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_price.no_depth_test = true
	_price.font_size = 60
	_price.outline_size = 14
	_price.outline_modulate = Color(0.25, 0.15, 0.0)
	_price.pixel_size = 0.008
	_price.position.y = 0.45
	add_child(_price)
	sim.zone_purchased.connect(func(id: String, _level: int) -> void:
		if id == zone.id:
			Juice.pop(_base, Vector3(1.4, 1.0, 1.4)))


func _process(_delta: float) -> void:
	visible = _available.call()
	if not visible:
		return
	var title := display_name if zone.costs.size() == 1 else "%s %d단계" % [display_name, zone.level + 1]
	_label.text = title
	var fire := sim.fire_needed(zone)
	_base.transparency = 0.6 if fire > 0 else 0.0
	_icon.texture = _locked_texture if fire > 0 else _icon_texture
	_icon.modulate = LOCKED_COLOR if fire > 0 else ICON_COLOR
	if fire > 0:
		_fill.visible = false
		_price.text = "모닥불 %d단계 필요" % fire
		_price.modulate = LOCKED_COLOR
		_price.font_size = 44
		return
	_price.text = "$ %d" % zone.remaining()
	_price.modulate = GOLD
	_price.font_size = 60
	var progress := float(zone.paid) / zone.cost()
	_fill.scale = Vector3(progress, 1.0, progress)
	_fill.visible = progress > 0.0


## 수리 존은 렌치, 구매 존은 효과 종류에 맞는 아이콘
func _icon_name() -> String:
	if zone.id.begins_with("repair"):
		return "wrench"
	if zone.id.begins_with("weapon_"):
		return "target"
	for key in zone.effect:
		if EFFECT_ICONS.has(key):
			return EFFECT_ICONS[key]
	return "star"
