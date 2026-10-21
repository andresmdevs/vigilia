extends CharacterBody3D
## Controlador del jugador en tercera persona.
##
## Regla central: el CharacterBody3D nunca rota, solo se traslada. Quien rota
## es `Visual` (gira hacia donde camina) y `CameraRig` (gira con el mouse).
## Separarlos evita que la cámara y el personaje se peleen por la orientación,
## que es el bug clásico de los controladores en tercera persona.

@export_group("Movimiento")
## Ajustadas a lo que representan las animaciones, no al revés. Antes el
## personaje caminaba a 4 m/s con un ciclo de andar y corría a 7,2 acelerando
## Sprint 1,8x: las piernas iban mucho más rápido que el avance real.
@export var walk_speed := 2.4
@export var sprint_speed := 6.4
@export var acceleration := 14.0
@export var friction := 16.0
@export var turn_speed := 12.0
@export var jump_velocity := 8.0
@export var air_control := 0.35
## Margen antes de darnos por caídos. Perder el contacto con el suelo un solo
## frame (al pasar un borde o montarse en algo) disparaba la animación de
## salto y se veía como un tic. También es lo que permite saltar justo
## después de salir de una plataforma, que se siente mejor.
@export var coyote_time := 0.12

## Catálogo de armas. Igual que la tabla de dificultad: todo lo que define un
## arma vive aquí y en ningún otro sitio, para que equilibrar el combate sea
## editar números y no tocar lógica.
##
## `largo` es el tamaño real en metros; el soporte deduce la escala de ahí, así
## que da igual en qué escala venga el modelo del pack.
const ARMAS := {
	"hacha": {
		"nombre": "HACHA",
		"modelo": "res://assets/weapons/Axe.obj",
		"largo": 0.8,
		"cuerpo_a_cuerpo": true,
		"dano": 52.0,
		"alcance": 2.6,
		"arco_grados": 90.0,
		"cadencia": 0.65,
		"anim": "Sword_Regular_A",
		"idle": "Idle",
		"municion_inicial": -1,
	},
	"pistola": {
		"nombre": "PISTOLA",
		"modelo": "res://assets/weapons/Pistol_1.obj",
		"largo": 0.22,
		"cuerpo_a_cuerpo": false,
		"dano": 38.0,
		"alcance": 70.0,
		"arco_grados": 0.0,
		"cadencia": 0.3,
		"anim": "",
		"idle": "Pistol_Idle",
		"municion_inicial": 24,
	},
}
const ORDEN_ARMAS := ["hacha", "pistola"]

@export_group("Vida")
@export var max_health := 100.0

signal health_changed(current: float, maximum: float)
signal arma_cambiada(id: String, municion: int)
signal municion_cambiada(municion: int)
signal baja_confirmada(total: int)
signal resources_changed(resources: Dictionary)
signal died

var health: float
## tipo -> cantidad. Base de la economía de crafteo que viene después.
var resources := {}

@export_group("Animación")
## Velocidad (m/s) a la que CADA animación se ve natural a velocidad x1.
## Una sola cifra global no servía: Walk y Sprint representan cosas distintas,
## y usar la misma referencia para ambas es lo que hacía patinar los pies.
const VEL_NATURAL := {
	"walk": 1.8,
	"run": 6.4,
}

## Estado -> animación, explícito a propósito.
##
## Ojo con los nombres: el importador de Godot le quita el sufijo "_Loop" a las
## animaciones del .glb, así que acá va el nombre YA importado (Walk_Carry, no
## Walk_Carry_Loop). Si algún día no encaja una, revisar con dump_rig.gd.
##
## Locomoción sale de UAL1; el salto, de UAL2.
## Al ir armado el personaje usa la pose de pistola, que UAL1 trae lista.
const ANIMS := {
	"idle": "Pistol_Idle",
	"walk": "Walk",
	"run": "Sprint",
	"jump": "NinjaJump_Idle",
}

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
var _anim: AnimationPlayer = null
var _anim_state := ""
var _airborne_for := 0.0

var arma_id := "hacha"
var bajas := 0
var _municion := {}
var _ataque_cd := 0.0
## Mientras dura, el personaje mira hacia donde apunta la cámara en vez de
## hacia donde camina: atacar de espaldas a la mira sería absurdo.
var _apuntando := 0.0
var _soporte: Node3D
var _linterna: SpotLight3D
var _reloj: Node
var linterna_encendida := false


func _ready() -> void:
	_anim = _find_animation_player(visual)
	_attach_weapon()
	for id in ARMAS:
		_municion[id] = int(ARMAS[id]["municion_inicial"])
	health = max_health
	# Los zombies buscan al jugador por grupo, no por ruta de nodo: así la
	# escena se puede reorganizar sin romperles la referencia.
	add_to_group("player")
	_equipar(arma_id)
	_montar_linterna()
	_reloj = get_tree().get_first_node_in_group("reloj")


## Cuelga el arma del hueso de la mano derecha. Se hace por código y no en la
## escena porque el esqueleto vive dentro de un .gltf importado: tocarlo desde
## el .tscn es frágil y se rompe en cada reimportación.
func _attach_weapon() -> void:
	var skel := _find_skeleton(visual)
	if skel == null:
		push_warning("no se encontró el esqueleto del jugador")
		return
	if skel.find_bone("hand_r") < 0:
		push_warning("el esqueleto no tiene hueso hand_r")
		return

	var attach := BoneAttachment3D.new()
	attach.name = "ManoDerecha"
	skel.add_child(attach)
	attach.bone_name = "hand_r"

	_soporte = preload("res://scripts/player/weapon_holder.gd").new()
	_soporte.name = "Arma"
	attach.add_child(_soporte)


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for c in root.get_children():
		var f := _find_skeleton(c)
		if f != null:
			return f
	return null


## Linterna colgada del rig de la cámara, no de la mano: alumbra a donde
## miras, que es lo que el jugador espera y lo que hace la noche jugable.
func _montar_linterna() -> void:
	_linterna = SpotLight3D.new()
	_linterna.name = "Linterna"
	_linterna.light_color = Color(1.0, 0.95, 0.82)
	_linterna.light_energy = 6.0
	_linterna.spot_range = 34.0
	_linterna.spot_angle = 26.0
	_linterna.spot_angle_attenuation = 0.6
	_linterna.spot_attenuation = 1.2
	_linterna.shadow_enabled = true
	_linterna.position = Vector3(0.25, -0.1, 0.0)
	_linterna.visible = false
	camera_rig.add_child(_linterna)


func _actualizar_linterna() -> void:
	if _linterna == null:
		return
	if Input.is_action_just_pressed("flashlight"):
		linterna_encendida = not linterna_encendida
	# Se enciende sola cuando cae la tarde: nadie quiere morir a oscuras por
	# no haber descubierto que existía una tecla.
	if _reloj != null and is_instance_valid(_reloj) and bool(_reloj.call("hay_poca_luz")):
		if not linterna_encendida and not _linterna.visible:
			linterna_encendida = true
	_linterna.visible = linterna_encendida and health > 0.0


func _equipar(id: String) -> void:
	if not ARMAS.has(id):
		return
	arma_id = id
	var arma: Dictionary = ARMAS[id]
	if _soporte != null:
		_soporte.target_length = float(arma["largo"])
		_soporte.weapon_mesh = load(arma["modelo"])
	# Forzar la relectura de la animación de reposo, que cambia con el arma.
	_anim_state = ""
	arma_cambiada.emit(id, municion())


func municion() -> int:
	return int(_municion.get(arma_id, -1))


func _atacar() -> void:
	var arma: Dictionary = ARMAS[arma_id]
	_ataque_cd = float(arma["cadencia"])
	_apuntando = 0.45

	if bool(arma["cuerpo_a_cuerpo"]):
		_golpe(arma)
	else:
		if municion() <= 0:
			return
		_municion[arma_id] = municion() - 1
		municion_cambiada.emit(municion())
		_disparo(arma)

	var anim: String = arma["anim"]
	if _anim != null and anim != "" and _anim.has_animation(anim):
		_anim.play(anim, 0.08)
		_anim_state = "ataque"


## Golpe en arco: alcanza a todo zombi dentro del radio y del ángulo frontal.
## Resolverlo con geometría en vez de con un área física es más barato y, sobre
## todo, predecible: el jugador entiende enseguida dónde pega el hacha.
func _golpe(arma: Dictionary) -> void:
	var frente := -visual.global_transform.basis.z
	var alcance := float(arma["alcance"])
	var limite := cos(deg_to_rad(float(arma["arco_grados"]) * 0.5))
	for nodo in get_tree().get_nodes_in_group("zombies"):
		var z := nodo as Node3D
		if z == null or not is_instance_valid(z):
			continue
		var d := z.global_position - global_position
		d.y = 0.0
		if d.length() > alcance or d.length_squared() < 0.001:
			continue
		if d.normalized().dot(frente) < limite:
			continue
		_impactar(z, float(arma["dano"]))


func _disparo(arma: Dictionary) -> void:
	var cam := get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
	if cam == null:
		return
	# Se dispara desde la cámara y no desde el arma: es lo que hace que el tiro
	# vaya donde apunta la mira, que es lo que el jugador espera.
	var desde := cam.global_position
	var hasta := desde - cam.global_transform.basis.z * float(arma["alcance"])
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.collision_mask = 1 | 4      # mundo y zombies: una pared tapa el tiro
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return
	var tocado := golpe.get("collider") as Node3D
	if tocado != null and tocado.is_in_group("zombies"):
		_impactar(tocado, float(arma["dano"]))


func _impactar(z: Node3D, dano: float) -> void:
	if not z.has_method("take_damage"):
		return
	var vivo_antes: bool = z.get("health") != null and float(z.get("health")) > 0.0
	z.take_damage(dano, global_position)
	if vivo_antes and float(z.get("health")) <= 0.0:
		bajas += 1
		baja_confirmada.emit(bajas)


func recoger(tipo: String, cantidad: int) -> void:
	# Las balas no van a la mochila: entran directas al arma de fuego.
	if tipo == "balas":
		_municion["pistola"] = int(_municion.get("pistola", 0)) + cantidad
		if arma_id == "pistola":
			municion_cambiada.emit(municion())
		return
	resources[tipo] = int(resources.get(tipo, 0)) + cantidad
	resources_changed.emit(resources)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()


func _physics_process(delta: float) -> void:
	_ataque_cd = maxf(0.0, _ataque_cd - delta)
	_apuntando = maxf(0.0, _apuntando - delta)

	_actualizar_linterna()

	if health > 0.0:
		if Input.is_action_just_pressed("weapon_1"):
			_equipar(ORDEN_ARMAS[0])
		elif Input.is_action_just_pressed("weapon_2"):
			_equipar(ORDEN_ARMAS[1])
		if Input.is_action_pressed("attack") and _ataque_cd <= 0.0:
			_atacar()

	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if health <= 0.0:
		stick = Vector2.ZERO

	# El input es relativo a la cámara: "adelante" es hacia donde miras.
	var dir := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, camera_rig.rotation.y)

	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := dir * target_speed

	var control := 1.0 if is_on_floor() else air_control
	var rate := (acceleration if dir.length_squared() > 0.0 else friction) * control

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.lerp(target, clampf(rate * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z

	if is_on_floor():
		_airborne_for = 0.0
		# Anular la vertical en el suelo. De quien mantiene el contacto en las
		# bajadas se encarga floor_snap_length, no nosotros: un empujón hacia
		# abajo propio se proyecta sobre la pendiente y se convierte en
		# deslizamiento, y el personaje baja las lomas solo.
		velocity.y = 0.0
	else:
		_airborne_for += delta
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and _airborne_for <= coyote_time:
		velocity.y = jump_velocity
		_airborne_for = coyote_time + 1.0

	move_and_slide()
	_face_movement(delta)
	_drive_animation()


func _face_movement(delta: float) -> void:
	if _apuntando > 0.0:
		visual.rotation.y = lerp_angle(
			visual.rotation.y, camera_rig.rotation.y, clampf(turn_speed * 1.8 * delta, 0.0, 1.0))
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.04:
		return
	# En Godot el "adelante" de un nodo es -Z, de ahí los signos.
	var target_yaw := atan2(-flat.x, -flat.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _drive_animation() -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var want := "idle"
	if _airborne_for > coyote_time:
		want = "jump"
	elif speed > sprint_speed * 0.6:
		want = "run"
	elif speed > 0.2:
		want = "walk"

	if _anim != null:
		var escala := 1.0
		if VEL_NATURAL.has(want):
			escala = clampf(speed / float(VEL_NATURAL[want]), 0.7, 1.6)
		_anim.speed_scale = escala

	# Mientras dura el ataque no lo pisamos con la locomoción.
	if _anim_state == "ataque" and _ataque_cd > 0.0:
		return
	if want == _anim_state:
		return
	_anim_state = want
	_play(want)


func _play(state: String) -> void:
	if _anim == null:
		return
	var anim_name: String = ANIMS.get(state, "")
	# El reposo cambia con el arma: con pistola es la pose de apuntar.
	if state == "idle" and ARMAS.has(arma_id):
		anim_name = ARMAS[arma_id]["idle"]
	if anim_name != "" and _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.15)


func _find_animation_player(root: Node) -> AnimationPlayer:
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
