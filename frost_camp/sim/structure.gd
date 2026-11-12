class_name Structure
extends RefCounted
## 기지 시설 하나의 체력. 체력이 0이 되면 부서져 작동을 멈추고,
## 앞에 생기는 수리 존에 돈을 다 넣으면 체력이 가득 찬 채로 다시 작동한다.

var kind: String
var pos: Vector2
var max_hp: int
var hp: int
## 수리 존. 부서져 있을 때만 쓴다. 넣은 돈은 존을 떠나도 남는다.
var repair: PurchaseZone


func _init(structure_kind: String, structure_pos: Vector2, repair_pos: Vector2, config: Dictionary) -> void:
	kind = structure_kind
	pos = structure_pos
	max_hp = int(config.hp)
	hp = max_hp
	repair = PurchaseZone.new("repair_" + kind, repair_pos, {"costs": [int(config.repair_cost)]})
	repair.level = 1  # 멀쩡할 때는 다 고친 상태로 둔다.


func is_broken() -> bool:
	return hp <= 0


## damage만큼 깎는다. 이번에 부서졌으면 true. 이미 부서져 있으면 아무 일도 없다.
func take_hit(damage: int) -> bool:
	if is_broken():
		return false
	hp = maxi(hp - damage, 0)
	if hp > 0:
		return false
	repair.level = 0
	repair.paid = 0
	return true


## 수리 존이 다 찼으면 체력을 채우고 true.
func try_finish_repair() -> bool:
	if not is_broken() or not repair.try_complete():
		return false
	hp = max_hp
	return true
