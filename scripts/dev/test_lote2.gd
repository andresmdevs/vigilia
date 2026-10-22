extends SceneTree
## Pruebas del segundo lote de arreglos (salidos de la auditoría multi-agente).
## Cada una ejercita el camino real y está pensada para PODER fallar: si el
## bug volviera, la prueba lo cazaría.
##   Godot --path . res://scenes/main.tscn --script res://scripts/dev/test_lote2.gd

var fallos := 0


func _initialize() -> void:
	var espera := 0
	while get_nodes_in_group("zombies").is_empty() and espera < 1500:
		await process_frame
		espera += 1
	for _i in 60:
		await process_frame

	var j := get_first_node_in_group("player") as CharacterBody3D
	var nivel := get_first_node_in_group("level")
	var reloj := get_first_node_in_group("reloj")
	var sp := current_scene.get_node_or_null("Spawner")
	if sp:
		sp.set_process(false)

	await _t_loot(nivel)
	await _t_linterna(j, reloj)
	await _t_empujon(j)
	await _t_colision_zombi(j)
	await _t_disparo(j)
	await _t_carro()
	await _t_muerte(j)
	print("[lote2] ---- %s ----" % ("TODO OK" if fallos == 0 else "%d FALLOS" % fallos))
	quit(1 if fallos > 0 else 0)


func _ok(nombre: String, cond: bool, detalle: String) -> void:
	if not cond:
		fallos += 1
	print("[lote2] %-24s %-6s %s" % [nombre, "OK" if cond else "FALLA", detalle])


## El objeto debe quedar a 0,6 m sobre el terreno, esté donde esté. Antes
## quedaba a 0,6 m ABSOLUTOS: en una loma, enterrado.
func _t_loot(nivel: Node) -> void:
	var n := 0
	var en_loma := 0
	var peor := 0.0
	for p in get_nodes_in_group("loot"):
		var pos := (p as Node3D).global_position
		var suelo: float = nivel.call("height_at", pos.x, pos.z)
		peor = maxf(peor, absf((pos.y - suelo) - 0.6))
		if absf(suelo) > 1.5:
			en_loma += 1
		n += 1
	_ok("loot sobre el terreno", n > 0 and en_loma > 0 and peor < 0.25,
		"%d objetos (%d en lomas), desvío máx %.2f m" % [n, en_loma, peor])


## Con poca luz se enciende sola; tras pulsar F debe QUEDARSE apagada.
func _t_linterna(j: Node, reloj: Node) -> void:
	reloj.set("fase", 2)
	reloj.set("_restante", 999.0)
	for _k in 10:
		await physics_frame
	var lint := j.get("_linterna") as SpotLight3D
	var sola := lint.visible
	Input.action_press("flashlight")
	await physics_frame
	await physics_frame
	Input.action_release("flashlight")
	var siempre_apagada := true
	for _k in 60:
		await physics_frame
		if lint.visible:
			siempre_apagada = false
	_ok("linterna se deja apagar", sola and siempre_apagada,
		"se encendió sola=%s · apagada 60 frames tras F=%s" % [sola, siempre_apagada])
	reloj.set("fase", 0)


## Un golpe debe desplazar al zombi en la dirección del impacto. Se hace lejos
## del jugador, con el zombi en reposo, para que la persecución no lo tape.
func _t_empujon(j: Node3D) -> void:
	var z := get_nodes_in_group("zombies")[0] as CharacterBody3D
	z.global_position = j.global_position + Vector3(40, 0.3, 0)
	for _k in 40:
		await physics_frame
	var antes := z.global_position
	z.call("take_damage", 5.0, antes - Vector3(1, 0, 0))   # golpe desde el oeste
	for _k in 20:
		await physics_frame
	var dx := z.global_position.x - antes.x
	_ok("el golpe empuja", dx > 0.25, "desplazamiento hacia el este: %.2f m" % dx)


## Caminar contra un zombi no debe dejarte al otro lado. Medir la distancia
## final no sirve (si lo atraviesas también acabas lejos): se mira si pasaste.
func _t_colision_zombi(j: CharacterBody3D) -> void:
	var z := get_nodes_in_group("zombies")[0] as CharacterBody3D
	z.set_physics_process(false)
	j.get_node("CameraRig").set("_yaw", 0.0)
	z.global_position = j.global_position + Vector3(0, 0, -2.5)
	await physics_frame
	Input.action_press("move_forward")
	for _k in 90:
		await physics_frame
	Input.action_release("move_forward")
	var lo_atraveso := j.global_position.z < z.global_position.z
	_ok("no atraviesa zombies", not lo_atraveso,
		"jugador z=%.2f · zombi z=%.2f · máscara=%d" % [j.global_position.z, z.global_position.z, j.collision_mask])


## A/B: un zombi entre la cámara y el jugador NO debe recibir el tiro; uno
## delante, sí. Mira a nivel para que el rayo pase a la altura del cuerpo.
func _t_disparo(j: CharacterBody3D) -> void:
	j.call("_equipar", "pistola")
	var rig := j.get_node("CameraRig")
	rig.set("_yaw", 0.0)
	rig.set("_pitch", 0.0)
	for _k in 5:
		await process_frame
	var z := get_nodes_in_group("zombies")[0] as CharacterBody3D
	z.set_physics_process(false)

	z.global_position = j.global_position + Vector3(0, 0, 2.0)   # detrás
	await physics_frame
	var v0: float = z.get("health")
	j.call("_disparo", j.get("ARMAS")["pistola"])
	await physics_frame
	var detras_intacto := is_equal_approx(float(z.get("health")), v0)

	z.global_position = j.global_position + Vector3(0, 0, -6.0)  # delante
	await physics_frame
	var v1: float = z.get("health")
	j.call("_disparo", j.get("ARMAS")["pistola"])
	await physics_frame
	var delante_herido := float(z.get("health")) < v1
	_ok("disparo no da atrás", detras_intacto and delante_herido,
		"zombi detrás intacto=%s · zombi delante herido=%s" % [detras_intacto, delante_herido])


## Los carros deben tener casco convexo, y su superficie no puede ser plana:
## con la caja del AABB todos los rayos daban a la altura del techo.
func _t_carro() -> void:
	var convexos := 0
	var cajas := 0
	var variacion := 0.0
	for nodo in _todos(current_scene):
		if not (nodo is CollisionShape3D):
			continue
		var cs := nodo as CollisionShape3D
		var padre := cs.get_parent()
		var malla: MeshInstance3D = null
		for h in padre.get_children():
			if h is MeshInstance3D and (h as MeshInstance3D).mesh \
					and (h as MeshInstance3D).mesh.resource_path.contains("vehicles"):
				malla = h
		if malla == null:
			continue
		if cs.shape is ConvexPolygonShape3D:
			convexos += 1
			if variacion == 0.0:
				variacion = _variacion(padre as Node3D, malla)
		elif cs.shape is BoxShape3D:
			cajas += 1
	_ok("carro sigue su silueta", convexos > 0 and cajas == 0 and variacion > 0.2,
		"%d convexos, %d cajas · relieve del techo al capó: %.2f m" % [convexos, cajas, variacion])


func _variacion(carro: Node3D, mi: MeshInstance3D) -> float:
	var caja := mi.global_transform * mi.get_aabb()
	var espacio := carro.get_world_3d().direct_space_state
	var alturas: Array[float] = []
	for ix in 7:
		for iz in 7:
			var x := lerpf(caja.position.x, caja.end.x, 0.05 + 0.9 * ix / 6.0)
			var z := lerpf(caja.position.z, caja.end.z, 0.05 + 0.9 * iz / 6.0)
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(x, caja.end.y + 3.0, z), Vector3(x, caja.position.y - 1.0, z))
			var r := espacio.intersect_ray(q)
			if not r.is_empty() and r["collider"] == carro:
				alturas.append(float(r["position"].y))
	if alturas.size() < 3:
		return 0.0
	return alturas.max() - alturas.min()


## Debe decir el día (un número), no el nombre de la dificultad.
func _t_muerte(j: Node) -> void:
	j.set("health", 0.0)
	for _k in 10:
		await process_frame
	var hud := current_scene.get_node_or_null("HUD")
	var marcador := hud.get("_marcador") as Label if hud else null
	var texto := marcador.text if marcador else ""
	var i := texto.find("día ")
	var con_numero := i != -1 and texto.substr(i + 4, 1).is_valid_int()
	var sin_dificultad := not (texto.contains("ACECHO") or texto.contains("CALMA") or texto.contains("PESADILLA"))
	_ok("muerte muestra el día", con_numero and sin_dificultad, "\"%s\"" % texto.get_slice("\n", 0))


func _todos(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_todos(c))
	return out
