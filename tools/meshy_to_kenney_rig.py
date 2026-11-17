# Meshy에서 받은 리깅 없는 T자세 캐릭터(.glb)를 게임용으로 바꾼다.
# 1) 삼각형 수를 줄이고 텍스처를 작게 한다.
# 2) Kenney Mini Characters의 뼈대(7개)와 애니메이션을 그대로 옮겨 붙인다.
#    뼈 위치는 메시 모양에 맞춰 옮기고, 각 정점은 위치로 머리/몸통/팔/다리 뼈 하나에만 묶는다(Kenney도 부위별 통짜다).
# 쓰는 법:
#   blender -b -P tools/meshy_to_kenney_rig.py -- <meshy.glb> <kenney.glb> <out.glb> [삼각형 수]
import sys
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
meshy_path, kenney_path, out_path = argv[0], argv[1], argv[2]
target_tris = int(argv[3]) if len(argv) > 3 else 8000
TEXTURE_SIZE = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- Kenney 뼈대와 애니메이션 ---
bpy.ops.import_scene.gltf(filepath=kenney_path)
armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
for o in list(bpy.context.scene.objects):
	if o.type == "MESH":
		bpy.data.objects.remove(o)
kenney_height = 0.6713  # Kenney 캐릭터 키(머리 메시 꼭대기)

# --- Meshy 메시 ---
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=meshy_path)
mesh_obj = next(o for o in bpy.context.scene.objects if o not in before and o.type == "MESH")
for o in bpy.context.scene.objects:
	o.select_set(False)
mesh_obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh_obj.parent = None

# 줄이기. 가져온 메시는 UV 이음매마다 정점이 갈라져 있어, 먼저 붙여야 줄일 때 틈이 안 생긴다.
bm = bmesh.new()
bm.from_mesh(mesh_obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.to_mesh(mesh_obj.data)
bm.free()
tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
dec = mesh_obj.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, target_tris / tris)
bpy.ops.object.modifier_apply(modifier="dec")

# 크기와 위치: 키를 Kenney에 맞추고, 발을 0에, 가운데를 원점에 둔다.
co = [v.co for v in mesh_obj.data.vertices]
lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
s = kenney_height / (hi.z - lo.z)
for v in mesh_obj.data.vertices:
	v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * s, (v.co.y - (lo.y + hi.y) / 2) * s, (v.co.z - lo.z) * s))
co = [v.co for v in mesh_obj.data.vertices]
half_span = max(abs(c.x) for c in co)

# --- 메시에서 부위 경계 재기 (Blender는 Z가 위) ---
# 팔: 몸 바깥쪽(반폭의 60% 너머) 정점들의 높이 평균
arm_pts = [c for c in co if abs(c.x) > half_span * 0.6]
arm_z = sum(c.z for c in arm_pts) / len(arm_pts)
arm_top = max(c.z for c in arm_pts)
arm_bottom = min(c.z for c in arm_pts)
# 어깨 x: 팔 높이 바로 아래(겨드랑이 밑) 몸통의 반폭
body_band = [abs(c.x) for c in co if arm_bottom - 0.04 < c.z < arm_bottom - 0.01]
shoulder_x = max(body_band) if body_band else half_span * 0.3
# 엉덩이(다리 시작): Kenney 비율을 쓴다. 목: 팔 위쪽 끝
hip_z = 0.17625 / kenney_height * (hi.z - lo.z) * s
neck_z = arm_top
print("measure half_span=%.3f arm_z=%.3f arm=[%.3f,%.3f] shoulder_x=%.3f hip=%.3f" % (half_span, arm_z, arm_bottom, arm_top, shoulder_x, hip_z))

# --- 뼈 옮기기 ---
bpy.context.view_layer.objects.active = armature
for o in bpy.context.scene.objects:
	o.select_set(o == armature)
bpy.ops.object.mode_set(mode="EDIT")
eb = armature.data.edit_bones
def move(name, head):
	b = eb[name]
	d = head - b.head
	b.head += d
	b.tail += d
# 뼈대 오브젝트의 변환을 생각해 월드 좌표를 뼈대 로컬로 바꾼다.
inv = armature.matrix_world.inverted()
def local(x, y, z):
	return inv @ Vector((x, y, z))
move("torso", local(0, 0, hip_z))
move("leg-left", local(shoulder_x * 0.55, 0, hip_z))
move("leg-right", local(-shoulder_x * 0.55, 0, hip_z))
move("arm-left", local(shoulder_x, 0, arm_z))
move("arm-right", local(-shoulder_x, 0, arm_z))
move("head", local(0, 0, neck_z))
bpy.ops.object.mode_set(mode="OBJECT")

# --- 정점마다 뼈 하나 ---
groups = {n: mesh_obj.vertex_groups.new(name=n) for n in ["root", "torso", "head", "arm-left", "arm-right", "leg-left", "leg-right"]}
for v in mesh_obj.data.vertices:
	c = v.co
	if c.z > neck_z:
		g = "head"
	elif abs(c.x) > shoulder_x and c.z > hip_z:
		g = "arm-left" if c.x > 0 else "arm-right"
	elif c.z < hip_z:
		g = "leg-left" if c.x > 0 else "leg-right"
	else:
		g = "torso"
	groups[g].add([v.index], 1.0, "REPLACE")
mesh_obj.parent = armature
mesh_obj.matrix_parent_inverse = armature.matrix_world.inverted()
mod = mesh_obj.modifiers.new("arm", "ARMATURE")
mod.object = armature

# --- 재질: 금속성을 끄고 노멀/금속 텍스처는 버린다. 색 텍스처는 작게. ---
for mat in mesh_obj.data.materials:
	nodes = mat.node_tree.nodes
	bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
	for inp in ("Metallic", "Roughness", "Normal"):
		for link in list(bsdf.inputs[inp].links):
			mat.node_tree.links.remove(link)
	bsdf.inputs["Metallic"].default_value = 0.0
	bsdf.inputs["Roughness"].default_value = 1.0
	mat.use_backface_culling = True
	for n in list(nodes):
		if n.type == "TEX_IMAGE":
			if n.outputs["Color"].links and n.outputs["Color"].links[0].to_socket == bsdf.inputs["Base Color"]:
				n.image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
			else:
				nodes.remove(n)

bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85, export_animations=True, export_animation_mode="ACTIONS")
print("done tris=%d -> %s" % (sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons), out_path))
