extends SceneTree
## ¿Están invertidos los controles?
##
## Comprueba, para varios ángulos de cámara, que cada tecla mueve al personaje
## hacia donde debe RESPECTO A LA CÁMARA. También mide si los pies patinan:
## compara la velocidad real contra la que sugiere la animación.

func _initialize() -> void:
	for _i in 150:
		await process_frame
	var j := get_first_node_in_group("player") as CharacterBody3D
	if j == null:
		print("[mov] FALLA: sin jugador"); quit(1); return
	var rig := j.get_node("CameraRig") as Node3D

	print("[mov] --- direccion por tecla, a varios angulos de camara ---")
	for grados in [0.0, 90.0, 180.0, -90.0]:
		rig.set("_yaw", deg_to_rad(grados))
		await process_frame
		for par in [["move_forward", "adelante"], ["move_back", "atras"],
					["move_left", "izquierda"], ["move_right", "derecha"]]:
			var v := await _medir(j, par[0])
			# Ejes de la camara en el plano del suelo
			var cam_frente := -rig.global_transform.basis.z
			cam_frente.y = 0.0
			cam_frente = cam_frente.normalized()
			var cam_dcha := rig.global_transform.basis.x
			cam_dcha.y = 0.0
			cam_dcha = cam_dcha.normalized()

			var esperado := {
				"adelante": cam_frente, "atras": -cam_frente,
				"izquierda": -cam_dcha, "derecha": cam_dcha,
			}[par[1]] as Vector3
			var real := Vector3(v.x, 0.0, v.z).normalized()
			var acuerdo := real.dot(esperado)
			var veredicto := "OK" if acuerdo > 0.85 else ("INVERTIDO" if acuerdo < -0.5 else "DESVIADO")
			print("[mov] cam %+4.0f  %-10s  coincidencia=%+.2f  %s" % [
				grados, par[1], acuerdo, veredicto])

	print("[mov] --- patinaje de pies ---")
	for accion in [["move_forward", false], ["move_forward", true]]:
		Input.action_press(accion[0])
		if accion[1]:
			Input.action_press("sprint")
		for _k in 60:
			await physics_frame
		var p0 := j.global_position
		for _k in 60:
			await physics_frame
		var recorrido := (j.global_position - p0)
		recorrido.y = 0.0
		var ap := j.get("_anim") as AnimationPlayer
		print("[mov] %-10s  avance real=%.2f m/s  anim=%s a x%.2f" % [
			"corriendo" if accion[1] else "caminando",
			recorrido.length() / (60.0 / 60.0),
			ap.current_animation if ap else "?",
			ap.speed_scale if ap else 0.0])
		Input.action_release(accion[0])
		Input.action_release("sprint")
		for _k in 30:
			await physics_frame
	quit()


func _medir(j: CharacterBody3D, accion: String) -> Vector3:
	Input.action_press(accion)
	for _k in 25:
		await physics_frame
	var v: Vector3 = j.velocity
	Input.action_release(accion)
	for _k in 25:
		await physics_frame
	return v
