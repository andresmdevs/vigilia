extends Control
## Menú de inicio: mapa y dificultad.
##
## La interfaz se construye por código a propósito. Un .tscn con treinta nodos
## Control es tedioso de mantener a mano, y acá la estructura la dicta la tabla
## de GameConfig: añadir una dificultad o un mapa no debe obligar a tocar la
## escena, solo la tabla.

const FONDO := Color(0.055, 0.063, 0.078)
const TEXTO := Color(0.88, 0.89, 0.91)
const TENUE := Color(0.52, 0.55, 0.60)
const ACENTO := Color(0.85, 0.32, 0.28)

var _botones_dif: Array[Button] = []
var _detalle: Label


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(560, 0)
	centro.add_child(col)

	_titulo(col, "VIGILIA", 58, TEXTO)
	_titulo(col, "Rebusca de día. Atranca de noche. Arregla el carro. Sal de ahí.", 15, TENUE)
	col.add_child(_espacio(18))

	_titulo(col, "MAPA", 13, ACENTO)
	for i in GameConfig.MAPAS.size():
		var m: Dictionary = GameConfig.MAPAS[i]
		var b := Button.new()
		b.text = "  %s — %s" % [m["nombre"], m["lema"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.disabled = GameConfig.MAPAS.size() == 1
		b.tooltip_text = "Por ahora hay un solo mapa"
		col.add_child(b)

	col.add_child(_espacio(14))
	_titulo(col, "DIFICULTAD", 13, ACENTO)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	col.add_child(fila)

	for dif in GameConfig.PRESETS:
		var preset: Dictionary = GameConfig.PRESETS[dif]
		var b := Button.new()
		b.text = preset["nombre"]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(180, 46)
		b.pressed.connect(_elegir.bind(dif))
		fila.add_child(b)
		_botones_dif.append(b)

	_detalle = Label.new()
	_detalle.add_theme_font_size_override("font_size", 14)
	_detalle.add_theme_color_override("font_color", TENUE)
	_detalle.custom_minimum_size = Vector2(0, 76)
	col.add_child(_detalle)

	col.add_child(_espacio(10))

	var jugar := Button.new()
	jugar.text = "EMPEZAR"
	jugar.custom_minimum_size = Vector2(0, 54)
	jugar.add_theme_font_size_override("font_size", 20)
	jugar.pressed.connect(_empezar)
	col.add_child(jugar)

	_elegir(GameConfig.difficulty)


func _titulo(padre: Node, texto: String, tam: int, color: Color) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	padre.add_child(l)


func _espacio(alto: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	return c


func _elegir(dif) -> void:
	GameConfig.difficulty = dif
	var i := 0
	for d in GameConfig.PRESETS:
		_botones_dif[i].button_pressed = (d == dif)
		i += 1

	var p: Dictionary = GameConfig.PRESETS[dif]
	var zi: Vector2 = p["zombie_intervalo"]
	var li: Vector2 = p["loot_intervalo"]
	_detalle.text = "%s\n\nZombies: uno cada %.0f–%.0f s, hasta %d a la vez, %.0f de daño\nRecursos: uno cada %.0f–%.0f s, hasta %d en el mapa" % [
		p["lema"], zi.x, zi.y, p["zombie_max"], p["zombie_dano"], li.x, li.y, p["loot_max"],
	]


func _empezar() -> void:
	get_tree().change_scene_to_file(GameConfig.mapa()["escena"])
