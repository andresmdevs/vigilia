extends SceneTree
## ¿Por qué la noche se ve igual que el día?
##
## El reloj avanza (el HUD lo demuestra), así que el fallo tiene que estar en
## _aplicar(). Esto comprueba si las referencias a la escena llegaron vivas y
## si los valores del entorno cambian de verdad entre fases.

func _initialize() -> void:
	for _i in 120:
		await process_frame
	var r := get_first_node_in_group("reloj")
	if r == null:
		print("[ciclo] FALLA: no hay nodo en el grupo 'reloj'"); quit(1); return

	print("[ciclo] referencias exportadas:")
	print("   sol     = %s" % str(r.get("sol")))
	print("   entorno = %s" % str(r.get("entorno")))
	print("   _env    = %s" % str(r.get("_env")))
	print("   _cielo  = %s" % str(r.get("_cielo")))

	var sol := r.get("sol") as DirectionalLight3D
	var env := r.get("_env") as Environment
	print("\n[ciclo] valores por fase (forzando cada una):")
	for nombre in ["DIA", "ATARDECER", "NOCHE", "AMANECER"]:
		r.set("fase", r.get("Fase")[nombre] if r.get("Fase") else 0)
		r.set("_restante", 99.0)
		r.call("_aplicar", 0.0)
		await process_frame
		var e := sol.light_energy if sol else -1.0
		var c := sol.light_color if sol else Color.BLACK
		var niebla := env.fog_density if env else -1.0
		var amb := env.ambient_light_energy if env else -1.0
		print("   %-10s  sol_energia=%.3f  color=(%.2f,%.2f,%.2f)  niebla=%.4f  ambiente=%.3f" % [
			nombre, e, c.r, c.g, c.b, niebla, amb])

	# ¿De dónde sale la luz ambiental? Si viene del cielo, ambient_light_energy
	# no manda y oscurecer la noche por ahí no sirve de nada.
	if env != null:
		print("\n[ciclo] fuente de ambiente = %d  (0=fondo 1=desactivado 2=color 3=cielo)" % env.ambient_light_source)
		print("[ciclo] contribucion del cielo = %.2f" % env.ambient_light_sky_contribution)
		print("[ciclo] niebla activada = %s" % env.fog_enabled)
	quit()
