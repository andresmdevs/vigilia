extends Node3D
## Cámara orbital de tercera persona.
##
## El rig vive como hijo del jugador (lo sigue en posición) pero su rotación es
## independiente, porque el cuerpo del jugador nunca rota. El SpringArm3D que
## cuelga de aquí acerca la cámara cuando hay una pared detrás.

@export var sensitivity := 0.0024
@export var pitch_min_deg := -65.0
@export var pitch_max_deg := 28.0
@export var invert_y := false

var _yaw := 0.0
var _pitch := -0.18


func _ready() -> void:
	# A propósito no capturamos el mouse de entrada: en navegador el pointer
	# lock exige un gesto del usuario, así que lo engancha el primer clic.
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		var dy: float = event.relative.y * sensitivity
		_pitch += dy if invert_y else -dy
		_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
		return

	if event.is_action_pressed("free_cursor"):
		_capture(false)
	elif event is InputEventMouseButton and event.pressed:
		_capture(true)


func _process(_delta: float) -> void:
	# rotation_order por defecto es YXZ, que es justo lo que queremos:
	# primero el yaw sobre el eje del mundo, luego el pitch sobre el propio rig.
	rotation = Vector3(_pitch, _yaw, 0.0)


func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
