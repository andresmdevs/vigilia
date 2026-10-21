extends Node3D
## Reparte recursos por el mapa con el ritmo que marque la dificultad.
##
## En Calma el mapa está lleno y rebuscar es fácil; en Pesadilla escasea y cada
## pieza obliga a salir más lejos. Es la misma palanca que los zombies, en
## sentido contrario.

@export var pickup_scene: PackedScene
@export var area := 150.0

var _level: Node

const TIPOS := [
	{"tipo": "chatarra", "color": Color(0.78, 0.74, 0.70), "cantidad": 2},
	{"tipo": "tela",     "color": Color(0.80, 0.45, 0.40), "cantidad": 2},
	{"tipo": "madera",   "color": Color(0.72, 0.52, 0.28), "cantidad": 3},
	{"tipo": "clavos",   "color": Color(0.62, 0.66, 0.72), "cantidad": 4},
	# Las balas no van a la mochila: el jugador las mete directas en la pistola.
	{"tipo": "balas",    "color": Color(0.95, 0.80, 0.30), "cantidad": 8},
]

var _timer := 0.0


func _ready() -> void:
	if pickup_scene == null:
		push_warning("LootSpawner sin pickup_scene asignada")
		set_process(false)
		return
	_rearm()
	_level = get_tree().get_first_node_in_group("level")
	for i in 10:
		_spawn()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_rearm()
	if get_tree().get_nodes_in_group("loot").size() < int(GameConfig.actual()["loot_max"]):
		_spawn()


func _rearm() -> void:
	var rango: Vector2 = GameConfig.actual()["loot_intervalo"]
	_timer = randf_range(rango.x, rango.y)


func _spawn() -> void:
	var def: Dictionary = TIPOS.pick_random()
	var item := pickup_scene.instantiate()
	item.tipo = def["tipo"]
	item.color = def["color"]
	item.cantidad = def["cantidad"]
	item.add_to_group("loot")
	add_child(item)
	item.position = _sitio()


func _sitio() -> Vector3:
	# Los recursos se dejan en claros, no dentro de una casa ni en mitad de
	# la carretera. Si no hay suerte en 20 intentos, se suelta donde sea:
	# mejor un objeto mal puesto que un spawner que no suelta nada.
	for i in 20:
		var x := randf_range(-area, area)
		var z := randf_range(-area, area)
		if _level == null or not _level.has_method("height_at"):
			return Vector3(x, 0.6, z)
		if _level.is_clear(x, z, 10.0):
			return Vector3(x, _level.height_at(x, z) + 0.6, z)
	var fx := randf_range(-area, area)
	var fz := randf_range(-area, area)
	var fy := 0.6
	if _level != null and _level.has_method("height_at"):
		fy = _level.height_at(fx, fz) + 0.6
	return Vector3(fx, fy, fz)
