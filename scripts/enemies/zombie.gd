extends CharacterBody3D
## Zombie básico: espera, detecta al jugador, lo persigue por el navmesh y
## zarpazo cuando lo alcanza.
##
## Usa el mismo modelo que el jugador con las animaciones Zombie_* de la
## librería, teñido de verde. Para el prototipo sale gratis; cuando haya un
## modelo propio solo se cambia la escena hija.

@export_group("Movimiento")
@export var chase_speed := 3.2
@export var turn_speed := 6.0

@export_group("Percepción")
@export var detect_radius := 24.0
@export var lose_radius := 32.0

@export_group("Vida")
@export var max_health := 100.0
## Empujón al recibir un golpe. Da sensación de impacto sin necesidad de una
## animación de dolor, que además se prestaría a dejarlos bloqueados a golpes.
@export var knockback := 4.0

@export_group("Ataque")
@export var attack_range := 1.7
@export var attack_damage := 12.0
@export var attack_cooldown := 1.6
## Momento dentro de la animación en que el zarpazo conecta.
@export var attack_hit_delay := 0.45

enum State { IDLE, CHASE, ATTACK, DEAD }

const ANIMS := {
	State.IDLE: "Zombie_Idle",
	State.CHASE: "Zombie_Walk_Fwd",
	State.ATTACK: "Zombie_Scratch",
	State.DEAD: "Death01",
}

const FLASH := 0.18
const COLOR_BASE := Color(0.62, 0.78, 0.55)
const COLOR_GOLPE := Color(1.0, 0.3, 0.25)

signal murio(pos: Vector3)

@onready var visual: Node3D = $Visual
@onready var agent: NavigationAgent3D = $NavigationAgent3D

var _state := State.IDLE
var _anim: AnimationPlayer
var _player: Node3D
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
var _cooldown := 0.0
var _attack_elapsed := 0.0
var _attack_landed := false
var _nav_ready := false
var health: float
var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0


func _ready() -> void:
	add_to_group("zombies")
	# Daño y velocidad los manda la dificultad elegida, no el inspector: así
	# un solo sitio define qué tan duro es el juego.
	var cfg := GameConfig.actual()
	attack_damage = float(cfg["zombie_dano"])
	chase_speed = float(cfg["zombie_velocidad"])
	health = max_health
	_anim = _find_animation_player(visual)
	_tint(visual, COLOR_BASE)
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = attack_range * 0.8
	# El navmesh se hornea en el mismo frame en que arranca el nivel; pedirle
	# una ruta antes de que exista devuelve basura.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_nav_ready = true
	_play(State.IDLE)


## Encaja un golpe. `desde` es de dónde vino, para empujarlo en esa dirección.
func take_damage(amount: float, desde: Vector3) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash = FLASH
	var empuje := global_position - desde
	empuje.y = 0.0
	if empuje.length_squared() > 0.001:
		velocity += empuje.normalized() * knockback
	if health <= 0.0:
		_morir()


func _morir() -> void:
	_state = State.DEAD
	remove_from_group("zombies")
	# Deja de estorbar al instante; el cuerpo se queda un momento por estética.
	set_collision_layer_value(3, false)
	velocity = Vector3.ZERO
	_play(State.DEAD)
	murio.emit(global_position)
	await get_tree().create_timer(4.0).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		var c := COLOR_BASE.lerp(COLOR_GOLPE, _flash / FLASH)
		for m in _mats:
			m.albedo_color = c

	if _state == State.DEAD:
		# Que el cadáver no quede flotando si murió en pendiente.
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity = Vector3.ZERO
		move_and_slide()
		return

	_cooldown = maxf(0.0, _cooldown - delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if _player == null or not _nav_ready:
		_halt()
		move_and_slide()
		return

	var to_player := _player.global_position - global_position
	var dist := Vector3(to_player.x, 0.0, to_player.z).length()

	match _state:
		State.IDLE:
			_halt()
			if dist <= detect_radius:
				_set_state(State.CHASE)
		State.CHASE:
			if dist > lose_radius:
				_set_state(State.IDLE)
			elif dist <= attack_range and _cooldown <= 0.0:
				_set_state(State.ATTACK)
			else:
				_chase(delta)
		State.ATTACK:
			_halt()
			_face(to_player, delta)
			_attack_elapsed += delta
			if not _attack_landed and _attack_elapsed >= attack_hit_delay:
				_attack_landed = true
				if dist <= attack_range * 1.25 and _player.has_method("take_damage"):
					_player.take_damage(attack_damage)
			if _attack_elapsed >= attack_cooldown:
				_cooldown = 0.2
				_set_state(State.CHASE)

	move_and_slide()


func _chase(delta: float) -> void:
	agent.target_position = _player.global_position
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		_halt()
		return
	dir = dir.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_face(dir, delta)


func _halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face(dir: Vector3, delta: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	if next == State.ATTACK:
		_attack_elapsed = 0.0
		_attack_landed = false
	_play(next)


func _play(state: State) -> void:
	if _anim == null:
		return
	var anim_name: String = ANIMS.get(state, "")
	if anim_name != "" and _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.2)


func _tint(node: Node, color: Color) -> void:
	# Tiñe multiplicando sobre la textura, así conserva el detalle del modelo.
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			for i in mesh.get_surface_override_material_count():
				var base := mesh.get_active_material(i)
				if base is StandardMaterial3D:
					var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					mat.albedo_color = color
					mesh.set_surface_override_material(i, mat)
					_mats.append(mat)
		_tint(child, color)


func _find_animation_player(root: Node) -> AnimationPlayer:
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
