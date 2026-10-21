extends SceneTree
## Inspecciona los modelos importados: tipo de recurso, superficies y
## triángulos. El conteo importa porque cada árbol se repite cientos de veces
## en el MultiMesh: 2.000 triángulos por pino son 4 millones en pantalla.
func _initialize() -> void:
	var dir := DirAccess.open("res://assets/nature")
	if dir == null:
		print("no existe assets/nature"); quit(1); return
	var total := 0
	for f in dir.get_files():
		if not f.ends_with(".obj"):
			continue
		var res := load("res://assets/nature/" + f)
		if res == null:
			print("  %-26s NO CARGA" % f); continue
		var tris := 0
		var surfs := 0
		if res is ArrayMesh:
			var m := res as ArrayMesh
			surfs = m.get_surface_count()
			tris = m.get_faces().size() / 3
			total += tris
		var tam := Vector3.ZERO
		if res is Mesh:
			tam = (res as Mesh).get_aabb().size
		print("  %-26s sup=%d tris=%-5d alto=%.2fm ancho=%.2fm" % [f, surfs, tris, tam.y, tam.x])
	print("  --- total de los modelos usados: %d triangulos" % total)
	quit()
