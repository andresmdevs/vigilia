extends SceneTree
## Diagnostico: imprime el arbol que genera el importador de Godot para el
## personaje y para la libreria de animaciones, y las rutas de las pistas.
## Sirve para saber si las animaciones aplican directo o hay que retargetear.
##   Godot --headless --path . --script res://scripts/dev/dump_rig.gd

func _initialize() -> void:
	_dump("res://assets/characters/Superhero_Male_FullBody.gltf", "PERSONAJE")
	_dump("res://assets/animations/UAL2_Standard.glb", "LIBRERIA")
	quit()


func _dump(path: String, label: String) -> void:
	print("\n########## %s : %s ##########" % [label, path])
	var ps := load(path) as PackedScene
	if ps == null:
		print("  !! no se pudo cargar")
		return
	var root := ps.instantiate()
	_tree(root, 0)

	var ap := _find(root, "AnimationPlayer") as AnimationPlayer
	if ap == null:
		print("  (sin AnimationPlayer)")
		root.free()
		return
	print("  AnimationPlayer.root_node = ", ap.root_node)
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		print("  libreria '%s' -> %d animaciones" % [lib_name, lib.get_animation_list().size()])
		var first: StringName = lib.get_animation_list()[0]
		var anim := lib.get_animation(first)
		print("  muestra '%s': %d pistas, %.2fs" % [first, anim.get_track_count(), anim.length])
		for i in mini(6, anim.get_track_count()):
			print("     pista[%d] %s" % [i, anim.track_get_path(i)])
	root.free()


func _tree(n: Node, d: int) -> void:
	if d > 3:
		return
	print("  %s- %s (%s)" % ["  ".repeat(d), n.name, n.get_class()])
	for c in n.get_children():
		if d == 2 and n.get_child_count() > 4:
			print("      %s... (%d hijos)" % ["  ".repeat(d), n.get_child_count()])
			return
		_tree(c, d + 1)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f != null:
			return f
	return null
