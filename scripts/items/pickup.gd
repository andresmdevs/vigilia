extends Area3D
## Recurso tirado en el mapa. Se recoge al pasarle por encima.
##
## Deliberadamente tonto: un tipo y una cantidad. La economía de crafteo se
## construye encima de esto sin tener que cambiarlo.

@export var tipo := "chatarra"
@export var cantidad := 1
@export var color := Color(0.85, 0.65, 0.25)

var _giro := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var malla := get_node_or_null("Mesh") as MeshInstance3D
	if malla != null and malla.mesh is PrimitiveMesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
		(malla.mesh as PrimitiveMesh).material = mat


func _process(delta: float) -> void:
	# Girar y flotar: hace que se vean de lejos sin necesitar un icono.
	_giro += delta
	rotation.y = _giro * 1.6
	position.y = 0.6 + sin(_giro * 2.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("recoger"):
		body.recoger(tipo, cantidad)
	queue_free()
