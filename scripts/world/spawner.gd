extends Node3D
## Hace llegar zombies de a poco, en momentos y sitios al azar.
##
## El ritmo y el tope salen de la dificultad elegida en el menú, no de este
## archivo. Cuando exista el ciclo día/noche, la noche solo tendrá que
## apretar esos mismos números.

@export var zombie_scene: PackedScene
## Aparecen lejos del jugador: ver a uno materializarse delante rompe el juego.
@export var spawn_min_distance := 45.0
@export var spawn_max_distance := 80.0

## De noche llegan muchos más y mucho más seguido. Es el contrato del juego:
## el día se usa para prepararse porque la noche cobra.
@export var noche_ritmo := 0.4
@export var noche_tope := 2.0

var _timer := 0.0
var _level: Node
var _reloj: Node


func _ready() -> void:
	if zombie_scene == null:
		push_warning("Spawner sin zombie_scene asignada")
		set_process(false)
		return
	_rearm()
	_level = get_tree().get_first_node_in_group("level")
	_reloj = get_tree().get_first_node_in_group("reloj")
	# El navmesh del mapa grande se hornea en hilo: soltar zombies antes de
	# que termine los deja pidiendo rutas que no existen.
	if _level != null and _level.has_method("height_at") and not _level.nav_ready:
		await _level.navigation_ready
	for i in 3:
		_spawn()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_rearm()
	var tope := float(GameConfig.actual()["zombie_max"])
	if _de_noche():
		tope *= noche_tope
	if get_tree().get_nodes_in_group("zombies").size() < int(tope):
		_spawn()


func _rearm() -> void:
	var rango: Vector2 = GameConfig.actual()["zombie_intervalo"]
	_timer = randf_range(rango.x, rango.y)
	if _de_noche():
		_timer *= noche_ritmo


func _de_noche() -> bool:
	return _reloj != null and is_instance_valid(_reloj) and bool(_reloj.call("es_noche"))


func _spawn() -> void:
	var origen := Vector3.ZERO
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if jugador != null:
		origen = jugador.global_position

	var angulo := randf() * TAU
	var radio := randf_range(spawn_min_distance, spawn_max_distance)
	var pos := origen + Vector3(cos(angulo) * radio, 0.0, sin(angulo) * radio)

	if _level != null and _level.has_method("height_at"):
		var borde: float = _level.size * 0.5 - 12.0
		pos.x = clampf(pos.x, -borde, borde)
		pos.z = clampf(pos.z, -borde, borde)
		pos.y = _level.height_at(pos.x, pos.z) + 0.3
	else:
		pos.y = 0.3

	var zombie := zombie_scene.instantiate() as Node3D
	add_child(zombie)
	# Pegarlo al navmesh: uno que nazca fuera no sabrá llegar hasta ti.
	var mapa := get_world_3d().navigation_map
	var en_malla := NavigationServer3D.map_get_closest_point(mapa, pos)
	if en_malla.distance_to(pos) < 12.0:
		pos = en_malla + Vector3(0, 0.2, 0)
	zombie.global_position = pos
