extends SkeletonModifier3D
## Kenney Mini Characters의 서기·걷기 애니메이션은 팔을 T자에서 30°쯤만 내려, 팔을 벌린 A자 자세로 걷는다.
## 애니메이션이 뼈를 놓은 뒤 두 팔을 몸 쪽으로 더 내린다. 도구를 쓰는 동작에서는 influence를 0으로 둔다.

## 더 내리는 각도
const DROP := deg_to_rad(40.0)

var _left := -1
var _right := -1


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if _left == -1:
		_left = skeleton.find_bone("arm-left")
		_right = skeleton.find_bone("arm-right")
	# 팔은 몸통 좌표에서 ±X로 뻗어 있다. 몸통 좌표의 Z축으로 돌리면 팔이 아래로 내려온다.
	_lower(skeleton, _left, -DROP)
	_lower(skeleton, _right, DROP)


func _lower(skeleton: Skeleton3D, bone: int, angle: float) -> void:
	var turn := Quaternion(Vector3.BACK, angle)
	skeleton.set_bone_pose_rotation(bone, turn * skeleton.get_bone_pose_rotation(bone))
