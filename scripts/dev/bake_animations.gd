extends SceneTree
## Funde las librerías de animación de Quaternius en un único recurso que la
## escena del jugador referencia directo, sin arrastrar en runtime los .glb
## completos (que traen además un maniquí de muestra cada uno).
##
## UAL1 es locomoción y combate básico; UAL2 son acciones especializadas.
## UAL1 va primero a propósito: si un nombre existe en ambas, gana la v1,
## que es la que mueve al personaje.
##
## Sobre el ciclo: el importador de Godot ya reconoce el sufijo "_Loop" del
## .glb, se lo quita al nombre y activa LOOP_LINEAR por su cuenta (por eso en
## el proyecto la animación se llama Walk y no Walk_Loop). El chequeo de abajo
## queda como red de seguridad para assets de otro origen.
##
##   Godot --headless --path . --script res://scripts/dev/bake_animations.gd

const SOURCES := [
	"res://assets/animations/UAL1_Standard.glb",
	"res://assets/animations/UAL2_Standard.glb",
]
const OUT := "res://assets/animations/anim_library.res"


func _initialize() -> void:
	var baked := AnimationLibrary.new()
	var collisions: Array[String] = []

	for src in SOURCES:
		var packed := load(src) as PackedScene
		if packed == null:
			push_error("no se pudo cargar " + src)
			quit(1); return

		var root := packed.instantiate()
		var player := _find_player(root)
		if player == null:
			push_error("sin AnimationPlayer: " + src)
			root.free(); quit(1); return

		var source := player.get_animation_library("")
		var added := 0
		for anim_name in source.get_animation_list():
			if baked.has_animation(anim_name):
				collisions.append(anim_name)
				continue
			var anim: Animation = source.get_animation(anim_name).duplicate(true)
			if anim_name.ends_with("_Loop"):
				anim.loop_mode = Animation.LOOP_LINEAR
			baked.add_animation(anim_name, anim)
			added += 1
		root.free()
		print("[bake] %-28s -> %d animaciones" % [src.get_file(), added])

	if not collisions.is_empty():
		print("[bake] %d nombres repetidos (se conservó el de UAL1): %s" % [
			collisions.size(), ", ".join(collisions)])

	if ResourceSaver.save(baked, OUT) != OK:
		push_error("no se pudo guardar " + OUT)
		quit(1); return
	print("[bake] total %d animaciones -> %s" % [baked.get_animation_list().size(), OUT])
	quit()


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_player(c)
		if f != null:
			return f
	return null
