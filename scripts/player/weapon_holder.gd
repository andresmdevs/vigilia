extends Node3D
## Sujeta el arma en la mano derecha del personaje.
##
## Cuelga de un BoneAttachment3D sobre el hueso `hand_r` del esqueleto, así
## que sigue la animación sola: no hay que mover nada por código cada frame.
##
## El offset y la rotación son exportados porque el eje local de un hueso no
## coincide con el de la malla del arma, y la única forma sensata de cuadrarlo
## es mirarlo y ajustar.

@export var weapon_mesh: Mesh:
	set(value):
		weapon_mesh = value
		if is_node_ready():
			_rebuild()

@export var offset := Vector3(0.0, 0.0, 0.0):
	set(value):
		offset = value
		if is_node_ready():
			_apply()

@export var euler_deg := Vector3(0.0, 0.0, 0.0):
	set(value):
		euler_deg = value
		if is_node_ready():
			_apply()

## Largo real del arma en metros (una pistola ronda 0,22; una escopeta, 0,95).
## La escala se deduce de aquí en vez de a ojo: los modelos vienen en una
## escala cualquiera y, encima, el hueso de la mano arrastra la suya propia.
## Midiendo la malla y descontando la escala heredada, el arma sale del tamaño
## correcto venga como venga el modelo.
@export var target_length := 0.22:
	set(value):
		target_length = value
		if is_node_ready():
			_apply()

var _mesh_node: MeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if _mesh_node != null:
		_mesh_node.queue_free()
		_mesh_node = null
	if weapon_mesh == null:
		return
	_mesh_node = MeshInstance3D.new()
	_mesh_node.mesh = weapon_mesh
	add_child(_mesh_node)
	_apply()


func _apply() -> void:
	if _mesh_node == null:
		return
	_mesh_node.position = offset
	_mesh_node.rotation = Vector3(
		deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z))
	var aabb := weapon_mesh.get_aabb().size
	var largo: float = maxf(aabb.x, maxf(aabb.y, aabb.z))
	if largo <= 0.0:
		return
	var heredada: float = global_transform.basis.get_scale().x
	if heredada <= 0.0:
		heredada = 1.0
	_mesh_node.scale = Vector3.ONE * (target_length / largo / heredada)
