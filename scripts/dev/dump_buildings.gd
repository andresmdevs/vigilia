extends SceneTree
func _initialize() -> void:
	for n in ["Building_Small_1", "Building_Medium_2_001", "Building_Large_2"]:
		var ps := load("res://assets/buildings/%s.gltf" % n) as PackedScene
		if ps == null:
			print("  %s: no carga" % n); continue
		var root := ps.instantiate()
		var caja := _aabb(root)
		print("  %-24s base_y=%+.2f  alto=%.1fm  ancho=%.1fm  fondo=%.1fm" % [
			n, caja.position.y, caja.size.y, caja.size.x, caja.size.z])
		root.free()
	quit()

func _aabb(n: Node) -> AABB:
	var total := AABB()
	var primero := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var caja: AABB = (c as MeshInstance3D).get_aabb()
			total = caja if primero else total.merge(caja)
			primero = false
		var sub := _aabb(c)
		if sub.size.length_squared() > 0.0:
			total = sub if primero else total.merge(sub)
			primero = false
	return total
