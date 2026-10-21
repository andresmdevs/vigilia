extends SceneTree
## ¿El zombi se acerca o se aleja?
##
## Mide la distancia al jugador cada medio segundo. Es la prueba que convierte
## "parece que huyen" en un dato con el que se puede trabajar.

func _initialize() -> void:
	for _i in 150:
		await process_frame

	var jugador := get_first_node_in_group("player") as Node3D
	var zombies := get_nodes_in_group("zombies")
	if jugador == null or zombies.is_empty():
		print("[persec] FALLA: jugador=%s zombies=%d" % [jugador != null, zombies.size()])
		quit(1); return

	var z := zombies[0] as Node3D
	# Colocarlo a 12 m, bien dentro del radio de deteccion (24 m).
	z.global_position = jugador.global_position + Vector3(12.0, 0.5, 0.0)
	for _k in 10:
		await physics_frame

	print("[persec] estado inicial: nav_ready=%s  vida=%.0f" % [
		z.get("_nav_ready"), z.get("health")])

	var d0 := _dist(z, jugador)
	var muestras: Array[String] = []
	for paso in 10:
		for _k in 30:
			await physics_frame
		if not is_instance_valid(z):
			break
		var d := _dist(z, jugador)
		var v: Vector3 = z.get("velocity")
		muestras.append("%.1fm (v=%.1f)" % [d, Vector2(v.x, v.z).length()])
	print("[persec] distancia: %.1f -> %s" % [d0, " ".join(muestras)])

	if is_instance_valid(z):
		var df := _dist(z, jugador)
		var veredicto := "SE ACERCA" if df < d0 - 1.0 else ("SE ALEJA" if df > d0 + 1.0 else "NO SE MUEVE")
		print("[persec] VEREDICTO: %s  (%.1f -> %.1f m)" % [veredicto, d0, df])

		# ¿Está el zombi sobre el navmesh? Si el punto navegable más cercano
		# está lejos, la ruta empieza yendo hacia allá, o sea en otra dirección.
		var mapa := z.get_world_3d().navigation_map
		var cerca := NavigationServer3D.map_get_closest_point(mapa, z.global_position)
		print("[persec] navmesh: punto navegable mas cercano a %.2f m del zombi" % \
			z.global_position.distance_to(cerca))
		var cerca_j := NavigationServer3D.map_get_closest_point(mapa, jugador.global_position)
		print("[persec] navmesh: y a %.2f m del jugador" % \
			jugador.global_position.distance_to(cerca_j))
	quit()


func _dist(a: Node3D, b: Node3D) -> float:
	var d := a.global_position - b.global_position
	d.y = 0.0
	return d.length()
