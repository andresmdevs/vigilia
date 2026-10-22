extends Node
## Utilidades de desarrollo. Completamente inerte en una partida normal.
##
## Captura automática, para revisar el juego sin abrir el editor y para
## comparar el antes/después de un cambio visual:
##
##   Godot --path . -- --shot /ruta/salida.png [--walk]
##
## Con --walk mantiene pulsado "adelante" durante el calentamiento, para que
## la captura muestre al personaje en movimiento y no en reposo. Sirve para
## verificar locomoción, orientación del modelo y mezcla de animaciones.

const WARMUP_FRAMES := 240


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--combate"):
		_probar_combate()
		return
	var fa := args.find("--fase")
	if fa != -1 and fa + 2 < args.size():
		_capturar_fase(args[fa + 1], args[fa + 2])
		return
	var ic := args.find("--ciclo")
	if ic != -1:
		_recorrer_ciclo(args[ic + 1] if ic + 1 < args.size() else "user://")
		return
	var idx := args.find("--shot")
	if idx == -1:
		return

	var path := "user://shot.png"
	if idx + 1 < args.size():
		path = args[idx + 1]
	_shoot(path, args.has("--walk"))


## Fuerza una fase concreta y la captura. Sin esperas ni bucles: la versión
## que recorría el ciclo entero se colgaba, y una prueba que se cuelga es peor
## que ninguna.
func _capturar_fase(nombre: String, ruta: String) -> void:
	for _i in 100:
		await get_tree().process_frame
	var r := get_tree().get_first_node_in_group("reloj")
	if r == null:
		push_error("sin reloj"); get_tree().quit(1); return
	var fases := {"dia": 0, "atardecer": 1, "noche": 2, "amanecer": 3}
	r.set("fase", fases.get(nombre, 0))
	r.set("_restante", 999.0)
	r.call("_aplicar", 0.0)
	# 180 frames para que el FPS medido sea estable y no el del arranque.
	for _k in 180:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ruta)
	var sol := r.get("sol") as DirectionalLight3D
	print("[fase] %-10s fps=%d  draw_calls=%d  triangulos=%d  sol=%.2f" % [
		nombre, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		sol.light_energy if sol else -1.0])
	get_tree().quit()


## Recorre el ciclo completo con el reloj acelerado y captura cada fase. Sin
## esto habría que esperar siete minutos reales para ver si la noche se ve
## bien, que es justo el tipo de comprobación que uno acaba no haciendo.
func _recorrer_ciclo(carpeta: String) -> void:
	for _i in 90:
		await get_tree().process_frame
	var reloj := get_tree().get_first_node_in_group("reloj")
	if reloj == null:
		print("[ciclo] FALLA: no hay reloj en la escena")
		get_tree().quit(1); return

	reloj.set("dura_dia", 2.0)
	reloj.set("dura_atardecer", 2.0)
	reloj.set("dura_noche", 2.0)
	reloj.set("dura_amanecer", 2.0)
	# Acortar las duraciones no basta: _restante ya traía los 210 s del día
	# desde _ready(), así que hay que reiniciarlo para que el recorte valga.
	reloj.set("_restante", 2.0)

	for nombre in ["dia", "atardecer", "noche", "amanecer"]:
		# Esperar a estar bien dentro de la fase, no en plena transición.
		# Con tope: un bucle de espera sin límite no falla, se cuelga, y eso
		# es peor que un test que no existe.
		var espera := 0
		while String(reloj.call("nombre_fase")).to_lower().replace("í", "i") != nombre:
			await get_tree().process_frame
			espera += 1
			if espera > 1200:
				print("[ciclo] FALLA: nunca llegó la fase '%s' (sigue en %s)" % [
					nombre, reloj.call("nombre_fase")])
				get_tree().quit(1)
				return
		for _k in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var ruta := "%s/ciclo-%s.png" % [carpeta, nombre]
		get_viewport().get_texture().get_image().save_png(ruta)
		print("[ciclo] %-10s guardada  ·  zombies=%d" % [
			nombre, get_tree().get_nodes_in_group("zombies").size()])
	get_tree().quit()


## Prueba automática del bucle de combate: acerca al jugador a un zombi, le
## pega con el hacha y luego le dispara, y reporta qué pasó. Verifica de
## verdad que muere, en vez de confiar en que el código compila.
func _probar_combate() -> void:
	for _i in 120:
		await get_tree().process_frame

	var jugador := get_tree().get_first_node_in_group("player")
	var zombies := get_tree().get_nodes_in_group("zombies")
	if jugador == null or zombies.is_empty():
		print("[test] FALLA: sin jugador (%s) o sin zombies (%d)" % [jugador != null, zombies.size()])
		get_tree().quit(1); return

	# --- HACHA ---
	var z := zombies[0] as Node3D
	var vida_ini: float = z.get("health")
	jugador.global_position = z.global_position + Vector3(0, 0, 1.4)
	jugador.call("_equipar", "hacha")
	await get_tree().physics_frame
	# Apuntar la CÁMARA al zombi, no girar el modelo a mano.
	#
	# La versión anterior hacía Visual.look_at() antes de atacar, que es justo
	# el paso que el juego hace por su cuenta (y hacía mal). Al forzarlo, la
	# prueba esquivaba el camino real y daba verde con el arco del hacha roto.
	# Una prueba que evita el código que debe ejercitar es peor que ninguna.
	_mirar_a(jugador, z.global_position)
	await get_tree().physics_frame

	var golpes := 0
	while is_instance_valid(z) and float(z.get("health")) > 0.0 and golpes < 10:
		jugador.call("_atacar")
		golpes += 1
		for _k in 8:
			await get_tree().physics_frame
	print("[test] hacha: vida %.0f -> %.0f en %d golpes  |  bajas=%d" % [
		vida_ini, (z.get("health") if is_instance_valid(z) else 0.0), golpes, jugador.get("bajas")])

	# --- PISTOLA ---
	var vivos := get_tree().get_nodes_in_group("zombies")
	if vivos.is_empty():
		print("[test] no quedan zombies para probar la pistola")
		get_tree().quit(); return
	var z2 := vivos[0] as Node3D
	jugador.call("_equipar", "pistola")
	var mun_ini: int = jugador.call("municion")
	# Colocar la cámara mirando al zombi: el tiro sale de la cámara.
	jugador.global_position = z2.global_position + Vector3(0, 0, 6.0)
	await get_tree().physics_frame
	_mirar_a(jugador, z2.global_position)
	for _k in 4:
		await get_tree().physics_frame

	var vida2_ini: float = z2.get("health")
	var tiros := 0
	while is_instance_valid(z2) and float(z2.get("health")) > 0.0 and tiros < 12:
		# Por _atacar() y no por _disparo(): es el camino real del jugador, el
		# único que descuenta munición. Probar el atajo no prueba nada.
		jugador.call("_atacar")
		tiros += 1
		for _j in 4:
			await get_tree().physics_frame
	print("[test] pistola: vida %.0f -> %.0f en %d tiros  |  municion %d -> %d" % [
		vida2_ini, (z2.get("health") if is_instance_valid(z2) else 0.0), tiros,
		mun_ini, jugador.call("municion")])
	print("[test] bajas totales = %d" % jugador.get("bajas"))

	# --- EL CASO QUE SE NOS ESCAPABA: golpear mientras te mueves de lado ---
	# Es el patrón natural de pelea cuerpo a cuerpo (el zombi corre más rápido
	# que tú, así que lo rodeas), y era justo donde el hacha fallaba siempre.
	jugador.call("_equipar", "hacha")
	var vivos2 := get_tree().get_nodes_in_group("zombies")
	if not vivos2.is_empty():
		var z3 := vivos2[0] as Node3D
		jugador.global_position = z3.global_position + Vector3(0, 0, 1.5)
		_mirar_a(jugador, z3.global_position)
		Input.action_press("move_left")       # strafe: las piernas van a 90°
		for _k in 20:
			await get_tree().physics_frame
		var v_antes: float = z3.get("health")
		jugador.call("_atacar")
		for _k in 10:
			await get_tree().physics_frame
		var v_despues: float = z3.get("health") if is_instance_valid(z3) else 0.0
		Input.action_release("move_left")
		print("[test] golpe en strafe: vida %.0f -> %.0f  %s" % [
			v_antes, v_despues, "PEGA" if v_despues < v_antes else "FALLA"])

	# Con el cargador a cero no debe poder disparar.
	# Equipar la pistola explícitamente: el caso de strafe de arriba dejó el
	# hacha en la mano, y sin esto estaríamos midiendo hachazos.
	jugador.call("_equipar", "pistola")
	jugador.set("_municion", {"hacha": -1, "pistola": 0})
	var antes: int = jugador.get("bajas")
	for _k in 5:
		jugador.call("_atacar")
		for _j in 3:
			await get_tree().physics_frame
	print("[test] sin balas: municion=%d  bajas sin cambio=%s" % [
		jugador.call("municion"), antes == int(jugador.get("bajas"))])
	get_tree().quit()


## Apunta la cámara del jugador a un punto del mundo, como haría el ratón.
func _mirar_a(jugador: Node, objetivo: Vector3) -> void:
	var cuerpo := jugador as Node3D
	if cuerpo == null:
		return
	var rig := cuerpo.get_node("CameraRig") as Node3D
	var d: Vector3 = objetivo - cuerpo.global_position
	d.y = 0.0
	if d.length_squared() > 0.0001:
		rig.set("_yaw", atan2(-d.x, -d.z))


func _shoot(path: String, walking: bool) -> void:
	if walking:
		Input.action_press("move_forward")
	# Damos unos frames para que el nivel se construya y la luz se asiente.
	for _i in WARMUP_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var err := get_viewport().get_texture().get_image().save_png(path)
	if err == OK:
		print("[dev] captura guardada en ", path)
		print("[dev] fps=%d  draw_calls=%d  triangulos=%s  objetos=%d" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			String.num_uint64(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
			Performance.get_monitor(Performance.OBJECT_COUNT),
		])
	else:
		push_error("[dev] no se pudo guardar la captura (error %d)" % err)
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador is CharacterBody3D:
		var cb := jugador as CharacterBody3D
		print("[dev] jugador y=%.2f  en_suelo=%s  vel=(%.1f, %.1f, %.1f)" % [
			cb.global_position.y, cb.is_on_floor(), cb.velocity.x, cb.velocity.y, cb.velocity.z])
	var arma := get_tree().get_first_node_in_group("player")
	if arma != null:
		var h := arma.find_child("Arma", true, false)
		if h != null:
			var m := h.get_child(0) if h.get_child_count() > 0 else null
			if m is MeshInstance3D:
				var mundo: Vector3 = (m as MeshInstance3D).mesh.get_aabb().size * m.global_transform.basis.get_scale()
				print("[dev] arma: malla=%.2fm  escala_hueso=%.2f  tamano_final=%.2fm" % [
					(m as MeshInstance3D).mesh.get_aabb().size.z,
					h.global_transform.basis.get_scale().x,
					maxf(mundo.x, maxf(mundo.y, mundo.z))])
	get_tree().quit()
