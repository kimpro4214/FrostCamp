# Meshy에서 받은 네발 동물(.glb, 리깅 없음, 네 다리로 선 자세)을 게임용으로 바꾼다.
# 1) 정점을 붙이고 삼각형 수를 줄인 뒤, 금속성을 끄고 색 텍스처만 작게 남긴다.
# 2) 키를 1로, 발을 0에, 가운데를 원점에 맞춘다.
# 3) 배 높이(키 × 비율) 밑의 면을 앞뒤·좌우 넷으로 나눠 다리 4개(LegFL, LegFR, LegBL, LegBR)로 떼고, 나머지는 Body로 둔다.
#    다리마다 원점을 맨 위 가운데(엉덩이)에 두어, 게임에서 x축으로 돌리면 다리가 앞뒤로 흔들린다.
# 동물의 머리는 glTF +Z(Blender -Y), 왼쪽은 +X로 본다.
# 쓰는 법:
#   blender -b -P tools/meshy_quadruped.py -- <meshy.glb> <out.glb> [삼각형 수] [텍스처 크기] [배 높이 비율]
import sys
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
target_tris = int(argv[2]) if len(argv) > 2 else 3000
texture_size = int(argv[3]) if len(argv) > 3 else 512
belly = float(argv[4]) if len(argv) > 4 else 0.38

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
obj.parent = None
for o in list(bpy.context.scene.objects):
	if o != obj:
		bpy.data.objects.remove(o)

# UV 이음매에서 갈라진 정점을 먼저 붙여야 줄일 때 틈이 안 생긴다.
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.to_mesh(obj.data)
bm.free()
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
dec = obj.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, target_tris / tris)
bpy.ops.object.modifier_apply(modifier="dec")

# 키 1, 발 0, 가운데 원점
co = [v.co for v in obj.data.vertices]
lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
s = 1.0 / (hi.z - lo.z)
for v in obj.data.vertices:
	v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * s, (v.co.y - (lo.y + hi.y) / 2) * s, (v.co.z - lo.z) * s))
obj.name = "Body"

# 재질: 금속성을 끄고 노멀/금속 텍스처는 버린다. 색 텍스처는 작게.
for mat in obj.data.materials:
	nodes = mat.node_tree.nodes
	bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
	for inp in ("Metallic", "Roughness", "Normal"):
		for link in list(bsdf.inputs[inp].links):
			mat.node_tree.links.remove(link)
	bsdf.inputs["Metallic"].default_value = 0.0
	bsdf.inputs["Roughness"].default_value = 1.0
	for n in list(nodes):
		if n.type == "TEX_IMAGE":
			if n.outputs["Color"].links and n.outputs["Color"].links[0].to_socket == bsdf.inputs["Base Color"]:
				n.image.scale(texture_size, texture_size)
			else:
				nodes.remove(n)

# 다리 떼기: 모든 정점이 배 높이 밑인 면을 사분면별로 나눈다(앞 = Blender -Y).
QUADRANTS = {"LegFL": (1, -1), "LegFR": (-1, -1), "LegBL": (1, 1), "LegBR": (-1, 1)}
for name, (sx, sy) in QUADRANTS.items():
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.mode_set(mode="EDIT")
	bm = bmesh.from_edit_mesh(obj.data)
	count = 0
	for f in bm.faces:
		c = f.calc_center_median()
		f.select = all(v.co.z < belly for v in f.verts) and c.x * sx > 0 and c.y * sy > 0
		count += f.select
	bmesh.update_edit_mesh(obj.data)
	bpy.ops.mesh.separate(type="SELECTED")
	bpy.ops.object.mode_set(mode="OBJECT")
	leg = next(o for o in bpy.context.selected_objects if o != obj)
	leg.name = name
	pts = [leg.matrix_world @ v.co for v in leg.data.vertices]
	top = Vector((sum(p.x for p in pts) / len(pts), sum(p.y for p in pts) / len(pts), max(p.z for p in pts)))
	bpy.context.scene.cursor.location = top
	bpy.ops.object.select_all(action="DESELECT")
	leg.select_set(True)
	bpy.context.view_layer.objects.active = leg
	bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
	print("%s faces=%d hip=(%.3f, %.3f, %.3f)" % (name, count, top.x, top.y, top.z))

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85)
print("done body_tris=%d -> %s" % (sum(len(p.vertices) - 2 for p in obj.data.polygons), out))
