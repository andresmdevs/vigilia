extends Node3D
## Banco de pruebas generado por código: suelo, edificios, rampa y pilares.
##
## No es el mapa del juego. Existe para probar movimiento, colisión de cámara
## y pendientes sin tener que mantener un .tscn enorme a mano.

const GROUND := 80.0

var _nav: NavigationRegion3D


func _ready() -> void:
	# Toda la geometría sólida cuelga de la región de navegación, porque el
	# horneado del navmesh parsea sus hijos. La carretera NO: es decorativa y
	# va pegada al suelo, así que solo ensuciaría el resultado.
	_nav = NavigationRegion3D.new()
	_nav.navigation_mesh = _make_navmesh()
	add_child(_nav)

	_box(Vector3(0, -0.5, 0), Vector3(GROUND, 1, GROUND), Color(0.26, 0.30, 0.22))
	_road()

	# volúmenes tipo edificio
	_box(Vector3(-14, 2.0, -10), Vector3(10, 4.0, 8), Color(0.40, 0.37, 0.34))
	_box(Vector3(12, 1.6, -16), Vector3(7, 3.2, 7), Color(0.44, 0.40, 0.35))
	_box(Vector3(20, 1.2, 4), Vector3(6, 2.4, 10), Color(0.38, 0.36, 0.33))
	_box(Vector3(-20, 1.2, 14), Vector3(8, 2.4, 6), Color(0.42, 0.38, 0.33))

	# cajas bajas: sirven para ver si la cámara se mete en geometría
	_box(Vector3(-3.0, 0.5, -3.0), Vector3(1.2, 1, 1.2), Color(0.50, 0.42, 0.30))
	_box(Vector3(-1.5, 0.5, -4.5), Vector3(1.2, 1, 1.2), Color(0.50, 0.42, 0.30))
	_box(Vector3(-2.2, 1.5, -3.7), Vector3(1.2, 1, 1.2), Color(0.50, 0.42, 0.30))

	# rampa, para probar pendientes
	_box(Vector3(6, 0.9, 10), Vector3(5, 0.4, 9), Color(0.46, 0.44, 0.40), Vector3(deg_to_rad(-14), 0, 0))

	# pilares en círculo: referencia visual de distancia al correr
	for i in 6:
		var a := TAU * float(i) / 6.0
		_box(Vector3(cos(a) * 28.0, 2.5, sin(a) * 28.0), Vector3(1.4, 5, 1.4), Color(0.33, 0.33, 0.36))

	# Sincrónico a propósito: los zombies piden ruta en los primeros frames.
	_nav.bake_navigation_mesh(false)


func _make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 45.0
	# cell_size y cell_height deben coincidir con los del mapa de navegación,
	# o el rasterizado deja bordes mal puestos (Godot avisa en consola).
	nm.cell_size = 1.0
	nm.cell_height = 0.25
	# Horneamos en runtime porque el nivel se genera por código. En ese caso
	# hay que parsear COLISIONES y no mallas: leer del RenderingServer en
	# caliente es lento y Godot lo desaconseja explícitamente.
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	return nm


func _road() -> void:
	# Franja decorativa, sin colisión: va 2 cm por encima del suelo.
	var bm := BoxMesh.new()
	bm.size = Vector3(7, 0.05, GROUND)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.17, 0.18)
	bm.material = mat

	var mesh := MeshInstance3D.new()
	mesh.mesh = bm
	mesh.position = Vector3(0, 0.02, 0)
	add_child(mesh)


func _box(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot

	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	bm.material = mat

	var mesh := MeshInstance3D.new()
	mesh.mesh = bm

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape

	body.add_child(mesh)
	body.add_child(col)
	_nav.add_child(body)
