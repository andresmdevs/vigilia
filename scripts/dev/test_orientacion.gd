extends SceneTree
## ¿Hacia dónde MIRA el modelo, comparado con hacia dónde AVANZA?
##
## test_movimiento.gd daba 16/16 y aun así el jugador veía el personaje
## invertido, porque solo medía la velocidad. Esto mide lo que el jugador ve:
## el frente real del modelo, sacado del pie (foot -> ball apunta a los dedos).

func _initialize() -> void:
	for _i in 150:
		await process_frame
	var j := get_first_node_in_group("player") as CharacterBody3D
	if j == null:
		print("[orient] FALLA: sin jugador"); quit(1); return

	Input.action_press("move_forward")
	for _k in 40:
		await physics_frame
	var avance := Vector3(j.velocity.x, 0, j.velocity.z).normalized()
	var frente := _frente(j)
	Input.action_release("move_forward")
	_reportar("JUGADOR", avance, frente)

	var zs := get_nodes_in_group("zombies")
	if not zs.is_empty():
		var z := zs[0] as CharacterBody3D
		z.global_position = j.global_position + Vector3(10, 0.5, 0)
		for _k in 60:
			await physics_frame
		var za := Vector3(z.velocity.x, 0, z.velocity.z).normalized()
		_reportar("ZOMBI  ", za, _frente(z))
	quit()


func _reportar(quien: String, avance: Vector3, frente: Vector3) -> void:
	if frente == Vector3.ZERO or avance == Vector3.ZERO:
		print("[orient] %s sin datos (avance=%s frente=%s)" % [quien, avance, frente]); return
	var acuerdo := frente.dot(avance)
	var v := "MIRA AL FRENTE" if acuerdo > 0.7 else ("DE ESPALDAS (INVERTIDO)" if acuerdo < -0.7 else "DE LADO")
	print("[orient] %s  frente·avance = %+.2f  ->  %s" % [quien, acuerdo, v])


func _frente(cuerpo: Node3D) -> Vector3:
	var sk := _skel(cuerpo)
	if sk == null:
		return Vector3.ZERO
	var pie := sk.find_bone("foot_l")
	var punta := sk.find_bone("ball_l")
	if pie < 0 or punta < 0:
		print("[orient] huesos no encontrados: foot_l=%d ball_l=%d" % [pie, punta])
		return Vector3.ZERO
	var a := sk.global_transform * sk.get_bone_global_pose(pie).origin
	var b := sk.global_transform * sk.get_bone_global_pose(punta).origin
	var d := b - a
	d.y = 0.0
	return d.normalized()


func _skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _skel(c)
		if s != null:
			return s
	return null
