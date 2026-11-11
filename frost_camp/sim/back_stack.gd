class_name BackStack
extends RefCounted
## 등 뒤 스택. 아이템 id를 쌓은 순서대로 들고 있다.

var capacity: int
var items: Array[String] = []


func _init(stack_capacity: int) -> void:
	capacity = stack_capacity


func free_space() -> int:
	return capacity - items.size()


func push(item: String) -> bool:
	if items.size() >= capacity:
		return false
	items.append(item)
	return true


## 가장 위에 있는 같은 종류 아이템 하나를 꺼낸다.
func take(item: String) -> bool:
	var index := items.rfind(item)
	if index == -1:
		return false
	items.remove_at(index)
	return true
