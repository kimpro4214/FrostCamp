# Meshy에서 받은 소품(.glb, 리깅 없음)을 게임용으로 줄인다.
# 정점을 붙이고 삼각형 수를 줄인 뒤, 금속성을 끄고 색 텍스처만 작게 남긴다. 가운데를 원점에, 키를 1로 맞춘다.
# 쓰는 법:
#   blender -b -P tools/meshy_prop.py -- <meshy.glb> <out.glb> [삼각형 수] [텍스처 크기]
import sys
import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
target_tris = int(argv[2]) if len(argv) > 2 else 3000
texture_size = int(argv[3]) if len(argv) > 3 else 512

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
obj.parent = None

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

co = [v.co for v in obj.data.vertices]
lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
center = (lo + hi) / 2
s = 1.0 / (hi.z - lo.z)
for v in obj.data.vertices:
	v.co = (v.co - center) * s

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

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85)
print("done tris=%d size=%s -> %s" % (sum(len(p.vertices) - 2 for p in obj.data.polygons), tuple(round(x * s, 3) for x in (hi - lo)), out))
