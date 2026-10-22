extends Node3D
## El Valle: mapa grande generado por código.
##
## Decisión central: TODA la vegetación va en MultiMeshInstance3D, no en nodos
## sueltos. Mil árboles como nodos son mil draw calls y hunden un celular de
## gama media; mil árboles en un MultiMesh son uno solo. Cuando tengamos
## modelos de árbol de verdad, basta con cambiar la malla del MultiMesh: el
## problema de rendimiento ya quedó resuelto.
##
## El terreno es una malla desplazada por ruido, con la colisión derivada de
## ella. La carretera no se modela aparte: se aplana el terreno en una franja
## y se pinta encima.

signal navigation_ready

@export_group("Dimensiones")
## Lado del mapa en metros. Es un mapa acotado y denso, no un mundo infinito:
## los bordes se cierran con un muro de árboles.
@export var size := 620.0
## Metros por celda del terreno. Más bajo = más detalle y más triángulos.
@export var resolution := 4.0
@export var hill_height := 16.0

@export_group("Carretera")
@export var road_half_width := 5.0
@export var road_blend := 20.0

@export_group("Vegetación")
## Bajado de 2.200 a 1.100: los pinos reales traen ~1.900 triángulos cada uno
## frente a los ~100 de la primitiva que había antes.
@export var tree_count := 3200
@export var bush_count := 1800
@export var rock_count := 800
## El mapa se divide en CHUNKS x CHUNKS celdas y cada celda lleva sus propios
## MultiMesh. Es la clave del rendimiento: Godot descarta un MultiMesh entero
## por su caja envolvente, así que uno solo que cubriera los 400 m dibujaría
## TODOS los árboles aunque tuvieras el bosque a la espalda.
@export var chunks := 7
## Más allá de esto los arbustos dejan de dibujarse. La niebla los tapa y
## no vale la pena pagarlos.
@export var bush_view_distance := 110.0
## Más allá de esto los árboles dejan de dibujarse. Con la niebla actual la
## visibilidad real ronda los 150 m, así que a 200 no se nota y recorta
## bastante trabajo de dibujado.
@export var tree_view_distance := 400.0

var nav_ready := false

var _noise := FastNoiseLite.new()
var _density := FastNoiseLite.new()
var _nav: NavigationRegion3D
var _occupied: Array[Vector3] = []


func _ready() -> void:
	add_to_group("level")
	seed(20261020)

	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0032
	_noise.fractal_octaves = 4

	_density.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_density.frequency = 0.012

	_nav = NavigationRegion3D.new()
	_nav.navigation_mesh = _make_navmesh()
	add_child(_nav)

	_build_terrain()
	_build_road()
	_build_town()
	_build_houses()
	_build_cars()
	_scatter_trees()
	_scatter_bushes()
	_scatter_rocks()
	_place_player()

	# En hilo: el mapa es grande y hornearlo bloquearía el arranque varios
	# segundos. Los zombies esperan la señal antes de pedir ruta.
	_nav.bake_finished.connect(_on_bake_finished)
	_nav.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	nav_ready = true
	navigation_ready.emit()


## Altura del terreno en un punto. Los spawners la usan para no dejar cosas
## flotando o enterradas.
func height_at(x: float, z: float) -> float:
	var base := _noise.get_noise_2d(x, z) * hill_height
	var rx := road_x(z)
	var d := absf(x - rx)
	if d >= road_blend:
		return base
	var road_h := _noise.get_noise_2d(rx, z) * hill_height * 0.3
	return lerpf(road_h, base, smoothstep(road_half_width, road_blend, d))


## La carretera serpentea: una recta se ve artificial y mata la orientación.
func road_x(z: float) -> float:
	return sin(z * 0.0075) * 46.0 + sin(z * 0.021) * 11.0


func spawn_point() -> Vector3:
	return Vector3(road_x(0.0), height_at(road_x(0.0), 0.0) + 1.0, 0.0)


## ¿Se puede soltar algo acá? Fuera de la carretera y lejos de los edificios.
func is_clear(x: float, z: float, margin := 4.0) -> bool:
	if absf(x - road_x(z)) < road_half_width + 2.0:
		return false
	for o in _occupied:
		if Vector2(x - o.x, z - o.z).length() < o.y + margin:
			return false
	return true


# ---------------------------------------------------------------- terreno

func _build_terrain() -> void:
	var half := size * 0.5
	var cells := int(size / resolution)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in cells:
		for ix in cells:
			var x0 := -half + ix * resolution
			var z0 := -half + iz * resolution
			var x1 := x0 + resolution
			var z1 := z0 + resolution
			var a := Vector3(x0, height_at(x0, z0), z0)
			var b := Vector3(x1, height_at(x1, z0), z0)
			var c := Vector3(x1, height_at(x1, z1), z1)
			var d := Vector3(x0, height_at(x0, z1), z1)
			# OJO con el orden: Godot calcula la normal como (v0-v2) x (v0-v1).
			# Con a,d,c sale (0,-1,0) y el terreno queda mirando al subsuelo:
			# invisible desde arriba y atravesable, porque ConcavePolygonShape3D
			# solo colisiona contra la cara frontal.
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.29, 0.21)
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)

	# Red de seguridad: si algún día alguien toca el orden de vértices, esto
	# avisa en vez de dejar un terreno fantasma que cuesta horas diagnosticar.
	var n: Vector3 = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	if n.y <= 0.0:
		push_error("El terreno tiene las normales invertidas (n=%s)" % n)

	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(mi)
	body.add_child(col)
	_nav.add_child(body)


func _build_road() -> void:
	# Cinta que sigue la curva, apoyada 6 cm sobre el terreno. Sin colisión:
	# el suelo de debajo ya la tiene.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var step := 4.0
	var z := -half
	while z < half - step:
		var z2 := z + step
		var x1 := road_x(z)
		var x2 := road_x(z2)
		var a := Vector3(x1 - road_half_width, height_at(x1, z) + 0.06, z)
		var b := Vector3(x1 + road_half_width, height_at(x1, z) + 0.06, z)
		var c := Vector3(x2 + road_half_width, height_at(x2, z2) + 0.06, z2)
		var d := Vector3(x2 - road_half_width, height_at(x2, z2) + 0.06, z2)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		z = z2
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.14, 0.15)
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


# ------------------------------------------------------------- edificios

const EDIFICIOS := [
	"res://assets/buildings/Building_Small_1.gltf",
	"res://assets/buildings/Building_Medium_2_001.gltf",
	"res://assets/buildings/Building_Large_2.gltf",
]
const CARROS := [
	"res://assets/vehicles/NormalCar1.obj",
	"res://assets/vehicles/NormalCar2.obj",
	"res://assets/vehicles/SUV.obj",
	"res://assets/vehicles/Taxi.obj",
	"res://assets/vehicles/Cop.obj",
	"res://assets/vehicles/SportsCar.obj",
]


func _build_town() -> void:
	## Pueblo abandonado en un tramo de la carretera.
	##
	## Estos modelos son bloques urbanos de 17 a 28 m de alto. Repartidos por
	## el bosque como "casas" quedarían absurdos; agrupados cuentan algo y le
	## dan al valle un hito por el que orientarse.
	var z := -70.0
	var lado := 1.0
	var i := 0
	while z < 90.0:
		var escena := load(EDIFICIOS[i % EDIFICIOS.size()]) as PackedScene
		if escena != null:
			var nodo := escena.instantiate() as Node3D
			var x := road_x(z) + lado * randf_range(17.0, 26.0)
			_nav.add_child(nodo)

			# Estos bloques están hechos para ir en hilera pegados unos a otros:
			# solo la fachada tiene detalle, los costados y la trasera son lisos.
			# Hay que girarlos para que la fachada mire a la carretera, no al
			# bosque. lado=+1 los pone a la derecha de la vía, así que miran -X.
			nodo.rotation.y = (-PI * 0.5 if lado > 0.0 else PI * 0.5) + randf_range(-0.12, 0.12)

			# Y el origen del modelo no está en la base: sin compensar el mínimo
			# de su envolvente, el edificio queda medio enterrado o flotando.
			var caja := _aabb_de(nodo, nodo)
			nodo.global_position = Vector3(x, height_at(x, z) - caja.position.y, z)
			_box_collision(nodo)
			_occupied.append(Vector3(x, 24.0, z))
		z += randf_range(30.0, 44.0)
		lado *= -1.0
		i += 1


func _build_houses() -> void:
	# Casas sencillas fuera del pueblo: cabañas sueltas por el valle.
	var z := -size * 0.5 + 70.0
	var lado := 1.0
	while z < size * 0.5 - 70.0:
		if absf(z) > 110.0:
			var x := road_x(z) + lado * randf_range(18.0, 34.0)
			if absf(x) < size * 0.5 - 30.0:
				_house(Vector3(x, height_at(x, z), z), randf() * TAU)
				_occupied.append(Vector3(x, 12.0, z))
		z += randf_range(58.0, 96.0)
		lado *= -1.0


func _build_cars() -> void:
	# Carros abandonados en la carretera. Es la postal del género y cuesta
	# casi nada: siete modelos low-poly, 1 MB en total.
	var z := -size * 0.5 + 25.0
	while z < size * 0.5 - 25.0:
		if randf() < 0.6:
			var malla := load(CARROS[randi() % CARROS.size()]) as Mesh
			if malla != null:
				var x := road_x(z) + randf_range(-road_half_width * 0.75, road_half_width * 0.75)
				var raiz := StaticBody3D.new()
				_nav.add_child(raiz)
				var cajac := malla.get_aabb()
				raiz.global_position = Vector3(x, height_at(x, z) - cajac.position.y + 0.02, z)
				# Unos alineados con la vía, otros cruzados o volteados: un
				# atasco congelado, no un parqueadero.
				raiz.rotation.y = randf() * TAU if randf() < 0.35 else randf_range(-0.5, 0.5)

				var mi := MeshInstance3D.new()
				mi.mesh = malla
				raiz.add_child(mi)

				var caja := malla.get_aabb()
				var cs := CollisionShape3D.new()
				var forma := BoxShape3D.new()
				forma.size = caja.size
				cs.shape = forma
				cs.position = caja.get_center()
				raiz.add_child(cs)
		z += randf_range(16.0, 42.0)


## Colisión de caja a partir de la envolvente de las mallas del nodo. Para un
## edificio cerrado es buena aproximación y cuesta una fracción de lo que
## costaría una malla de colisión de 45.000 triángulos, que además alargaría
## muchísimo el horneado del navmesh.
func _box_collision(nodo: Node3D) -> void:
	var caja := _aabb_de(nodo, nodo)
	if caja.size.length_squared() <= 0.0:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = caja.size
	cs.shape = forma
	cs.position = caja.get_center()
	body.add_child(cs)
	nodo.add_child(body)


func _aabb_de(nodo: Node, raiz: Node3D) -> AABB:
	var total := AABB()
	var primero := true
	for hijo in nodo.get_children():
		if hijo is MeshInstance3D:
			var mi := hijo as MeshInstance3D
			var local := raiz.global_transform.affine_inverse() * mi.global_transform
			var caja := local * mi.get_aabb()
			total = caja if primero else total.merge(caja)
			primero = false
		var sub := _aabb_de(hijo, raiz)
		if sub.size.length_squared() > 0.0:
			total = sub if primero else total.merge(sub)
			primero = false
	return total


func _house(base: Vector3, yaw: float) -> void:
	var root := StaticBody3D.new()
	_nav.add_child(root)
	root.global_position = base
	root.rotation.y = yaw

	var ancho := randf_range(7.0, 11.0)
	var fondo := randf_range(6.0, 9.0)
	var alto := randf_range(3.0, 4.2)
	var pared := Color(0.42, 0.40, 0.36).lerp(Color(0.55, 0.47, 0.40), randf())

	_part(root, Vector3(0, alto * 0.5, 0), Vector3(ancho, alto, fondo), pared)
	_part(root, Vector3(0, alto + 0.35, 0), Vector3(ancho + 0.9, 0.7, fondo + 0.9),
		Color(0.26, 0.22, 0.20))
	_part(root, Vector3(0, 0.15, fondo * 0.5 + 1.0), Vector3(ancho * 0.7, 0.3, 2.0),
		Color(0.34, 0.30, 0.26))


func _part(padre: Node3D, pos: Vector3, tam: Vector3, color: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = tam
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	bm.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	padre.add_child(mi)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tam
	cs.shape = shape
	cs.position = pos
	padre.add_child(cs)


# ------------------------------------------------------------ vegetación

const PINOS := [
	"res://assets/nature/PineTree_1.obj",
	"res://assets/nature/PineTree_3.obj",
	"res://assets/nature/PineTree_5.obj",
]
const MUERTOS := [
	"res://assets/nature/CommonTree_Dead_1.obj",
	"res://assets/nature/CommonTree_Dead_3.obj",
	"res://assets/nature/BirchTree_Dead_1.obj",
]
const ARBUSTOS := [
	"res://assets/nature/Bush_1.obj",
	"res://assets/nature/Bush_2.obj",
	"res://assets/nature/BushBerries_1.obj",
]
const PIEDRAS := [
	"res://assets/nature/Rock_1.obj",
	"res://assets/nature/Rock_2.obj",
	"res://assets/nature/Rock_Moss_1.obj",
	"res://assets/nature/WoodLog.obj",
]


func _scatter_trees() -> void:
	# Un tercio de árboles muertos: es lo que da el aire de bosque enfermo.
	# OJO con la escala: estos modelos vienen a 2,7–3,6 m de alto, que al lado
	# de un jugador de 1,80 m parecen arbolitos. Un pino de bosque real anda
	# por los 10–20 m, de ahí factores de 3 a 5.
	var vivos := int(tree_count * 0.68)
	_scatter(PINOS, vivos, 0.12, Vector2(2.8, 5.4), tree_view_distance, true)
	_scatter(MUERTOS, tree_count - vivos, 0.04, Vector2(2.4, 4.6), tree_view_distance, true)


func _scatter_bushes() -> void:
	_scatter(ARBUSTOS, bush_count, -0.1, Vector2(0.9, 1.8), bush_view_distance, false)


func _scatter_rocks() -> void:
	_scatter(PIEDRAS, rock_count, -0.3, Vector2(0.7, 2.2), 140.0, false)


## Reparte `count` instancias de las mallas de `paths` por el mapa, agrupadas
## por celda. Cada (celda, malla) acaba en su propio MultiMesh.
func _scatter(paths: Array, count: int, threshold: float, escala: Vector2,
		view_distance: float, con_colision: bool) -> void:
	var mallas: Array[Mesh] = []
	for ruta in paths:
		var m := load(ruta) as Mesh
		if m != null:
			mallas.append(m)
	if mallas.is_empty():
		push_warning("sin mallas para dispersar: %s" % str(paths))
		return

	var troncos: StaticBody3D = null
	if con_colision:
		troncos = StaticBody3D.new()
		# Capa 2, aparte del mundo. El brazo de la cámara solo mira la capa 1,
		# así que atraviesa los troncos en vez de pegarse a ellos: antes un pino
		# entre tú y la cámara te tapaba la pantalla entera con corteza.
		troncos.collision_layer = 2
		add_child(troncos)

	var cubos := {}
	for punto in _pick_spots(count, threshold):
		var mi := randi() % mallas.size()
		var clave := Vector2i(_chunk_of(punto.x, punto.z), mi)
		if not cubos.has(clave):
			cubos[clave] = []
		var f := randf_range(escala.x, escala.y)
		cubos[clave].append(
			Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * f), punto))

		if troncos != null:
			# Colisión aparte del MultiMesh (que no tiene), y fuera de la región
			# de navegación: así no atraviesas un árbol, pero el horneado del
			# navmesh no tiene que digerir mil cilindros.
			var cs := CollisionShape3D.new()
			var cil := CylinderShape3D.new()
			cil.radius = 0.22 * f
			cil.height = 3.0 * f
			cs.shape = cil
			cs.position = punto + Vector3(0, 1.5 * f, 0)
			troncos.add_child(cs)

	for clave in cubos:
		var lista: Array = cubos[clave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mallas[clave.y]
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if view_distance > 0.0:
			mmi.visibility_range_end = view_distance
			mmi.visibility_range_end_margin = 15.0
		add_child(mmi)


func _chunk_of(x: float, z: float) -> int:
	var paso := size / float(chunks)
	var cx := clampi(int((x + size * 0.5) / paso), 0, chunks - 1)
	var cz := clampi(int((z + size * 0.5) / paso), 0, chunks - 1)
	return cz * chunks + cx


func _pick_spots(wanted: int, threshold: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var half := size * 0.5 - 6.0
	var borde := size * 0.5 - 55.0
	var intentos := wanted * 14
	while out.size() < wanted and intentos > 0:
		intentos -= 1
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		# Cinturón denso en el perímetro: es lo que cierra el mapa sin un muro
		# invisible, que siempre se siente barato.
		var en_borde := maxf(absf(x), absf(z)) > borde
		if not en_borde and _density.get_noise_2d(x, z) < threshold:
			continue
		if not is_clear(x, z):
			continue
		out.append(Vector3(x, height_at(x, z), z))
	return out


# ------------------------------------------------------------ navegación

func _make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 1.0
	nm.agent_height = 2.0
	nm.agent_max_climb = 1.0
	nm.agent_max_slope = 50.0
	# Celda gruesa a propósito. Sobre 400x400 m una celda de 0.25 serían 2.5
	# millones de columnas y el horneado tardaría muchísimo. Un zombie
	# persiguiéndote por un bosque no necesita precisión de centímetro.
	nm.cell_size = 1.0
	nm.cell_height = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	return nm


func _place_player() -> void:
	# El jugador vive en main.tscn y no sabe nada del relieve; lo colocamos
	# nosotros, que somos quienes conocemos la altura del suelo. Esperamos un
	# frame porque el nivel está antes que el jugador en el árbol y su _ready
	# (donde se registra en el grupo) todavía no ha corrido.
	await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null:
		p.global_position = spawn_point()
