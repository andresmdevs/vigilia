extends CanvasLayer
## HUD de partida: estado, arma, mira y pantalla de muerte.
##
## Se construye por código, como el menú: la estructura la dicta el estado del
## jugador, y así no hay que mantener un .tscn de treinta nodos Control.

const TENUE := Color(0.72, 0.75, 0.78)

var _estado: Label
var _arma: Label
var _muerte: Control
var _marcador: Label
var _reloj_label: Label
var _player: Node
var _reloj: Node
var _muerto := false


func _ready() -> void:
	_estado = _texto(Vector2(18, 14), 15, Color(1, 1, 1, 0.9))
	_arma = _texto(Vector2(18, 0), 20, Color(1, 0.93, 0.78, 0.95))
	_arma.anchor_top = 1.0
	_arma.anchor_bottom = 1.0
	_arma.offset_top = -64
	_arma.offset_bottom = -20
	# Arriba a la derecha: el día y cuánto falta para que anochezca. Es la
	# información que manda sobre todas las demás, porque decide si sigues
	# rebuscando o te vas a atrancar.
	_reloj_label = Label.new()
	_reloj_label.add_theme_font_size_override("font_size", 17)
	_reloj_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_reloj_label.add_theme_constant_override("outline_size", 6)
	_reloj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reloj_label.anchor_left = 1.0
	_reloj_label.anchor_right = 1.0
	_reloj_label.offset_left = -320
	_reloj_label.offset_right = -22
	_reloj_label.offset_top = 14
	add_child(_reloj_label)

	_mira()
	_pantalla_muerte()


func _texto(pos: Vector2, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _mira() -> void:
	# Sin mira no se puede apuntar en tercera persona: el disparo sale de la
	# cámara, así que el centro de la pantalla es literalmente dónde pega.
	#
	# Cada brazo se dibuja dos veces, una negra algo más grande por debajo:
	# en blanco liso la mira desaparecía sobre el propio personaje, que es
	# justo el fondo que tiene casi siempre.
	for off in [Vector2(-13, 0), Vector2(13, 0), Vector2(0, -13), Vector2(0, 13)]:
		_brazo(off, 11.0 if off.y == 0.0 else 4.0, 4.0 if off.y == 0.0 else 11.0,
			Color(0, 0, 0, 0.55))
		_brazo(off, 9.0 if off.y == 0.0 else 2.0, 2.0 if off.y == 0.0 else 9.0,
			Color(1, 1, 1, 0.95))
	_brazo(Vector2.ZERO, 4.0, 4.0, Color(0, 0, 0, 0.55))
	_brazo(Vector2.ZERO, 2.0, 2.0, Color(1, 0.85, 0.4, 0.95))


func _brazo(off: Vector2, ancho: float, alto: float, color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.anchor_left = 0.5; r.anchor_right = 0.5
	r.anchor_top = 0.5; r.anchor_bottom = 0.5
	r.offset_left = off.x - ancho * 0.5
	r.offset_right = off.x + ancho * 0.5
	r.offset_top = off.y - alto * 0.5
	r.offset_bottom = off.y + alto * 0.5
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


func _pantalla_muerte() -> void:
	_muerte = Control.new()
	_muerte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muerte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muerte.visible = false
	add_child(_muerte)

	var fondo := ColorRect.new()
	fondo.color = Color(0.18, 0.02, 0.02, 0.72)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muerte.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muerte.add_child(centro)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	centro.add_child(col)

	var t := Label.new()
	t.text = "TE ALCANZARON"
	t.add_theme_font_size_override("font_size", 52)
	t.add_theme_color_override("font_color", Color(0.95, 0.92, 0.9))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	_marcador = Label.new()
	_marcador.add_theme_font_size_override("font_size", 19)
	_marcador.add_theme_color_override("font_color", TENUE)
	_marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_marcador)


func _pintar_reloj() -> void:
	if _reloj_label == null or _reloj == null or not is_instance_valid(_reloj):
		return
	var de_noche: bool = _reloj.call("es_noche")
	var restante: float = _reloj.call("para_amanecer") if de_noche else _reloj.call("para_anochecer")
	var etiqueta := "AMANECE EN" if de_noche else "ANOCHECE EN"

	# El color avisa antes que el número: ámbar cuando quedan menos de dos
	# minutos, rojo bajo el minuto. Se lee de reojo sin tener que leerlo.
	var color := Color(0.86, 0.88, 0.90)
	if de_noche:
		color = Color(0.55, 0.68, 0.95)
	elif restante < 60.0:
		color = Color(0.95, 0.35, 0.28)
	elif restante < 120.0:
		color = Color(0.95, 0.70, 0.30)
	_reloj_label.add_theme_color_override("font_color", color)

	_reloj_label.text = "DÍA %d · %s\n%s  %d:%02d" % [
		int(_reloj.get("dia")), _reloj.call("nombre_fase"),
		etiqueta, int(restante) / 60, int(restante) % 60,
	]


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _reloj == null or not is_instance_valid(_reloj):
		_reloj = get_tree().get_first_node_in_group("reloj")
	_pintar_reloj()
	if _player == null:
		return

	var vida := float(_player.get("health"))
	var bajas := int(_player.get("bajas"))

	if not _muerto and vida <= 0.0:
		_muerto = true
		_muerte.visible = true
		_marcador.text = "%d zombies abatidos · día %s\n\nR para volver al menú" % [
			bajas, GameConfig.actual()["nombre"]]
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if _muerto:
		if Input.is_action_just_pressed("restart"):
			get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
		return

	var bolsa := ""
	var res: Dictionary = _player.get("resources")
	if res != null and not res.is_empty():
		var partes: Array[String] = []
		for k in res:
			partes.append("%s %d" % [k, res[k]])
		bolsa = "  ·  ".join(partes)
	else:
		bolsa = "mochila vacía"

	_estado.text = "VIGILIA · %s  ·  %d FPS\nVIDA %d   ·   zombies %d   ·   bajas %d\n%s" % [
		GameConfig.actual()["nombre"],
		Engine.get_frames_per_second(),
		roundi(vida),
		get_tree().get_nodes_in_group("zombies").size(),
		bajas,
		bolsa,
	]

	var municion := int(_player.call("municion"))
	var arma_id := String(_player.get("arma_id"))
	var nombre: String = _player.ARMAS[arma_id]["nombre"] if _player.ARMAS.has(arma_id) else arma_id
	_arma.text = "%s%s\n[1] hacha   [2] pistola   ·   clic: atacar" % [
		nombre, ("   %d balas" % municion) if municion >= 0 else "",
	]
