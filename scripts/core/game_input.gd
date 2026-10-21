extends Node
## Registra el mapa de controles por código en vez de en project.godot.
##
## Lo hacemos así por dos razones: project.godot serializa los InputEvent de
## forma muy frágil a mano, y más adelante vamos a necesitar re-mapear en
## caliente (controles táctiles en móvil, gamepad, remapeo del jugador).

const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back":    [KEY_S, KEY_DOWN],
	"move_left":    [KEY_A, KEY_LEFT],
	"move_right":   [KEY_D, KEY_RIGHT],
	"sprint":       [KEY_SHIFT],
	"jump":         [KEY_SPACE],
	"interact":     [KEY_E],
	"free_cursor":  [KEY_ESCAPE],
	"weapon_1":     [KEY_1],
	"weapon_2":     [KEY_2],
	"restart":      [KEY_R],
}

const MOUSE_ACTIONS := {
	"attack": MOUSE_BUTTON_LEFT,
	"aim":    MOUSE_BUTTON_RIGHT,
}


func _ready() -> void:
	for action in KEY_ACTIONS:
		_ensure(action)
		for keycode in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)

	for action in MOUSE_ACTIONS:
		_ensure(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_ACTIONS[action]
		InputMap.action_add_event(action, ev)


func _ensure(action: StringName) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, 0.2)
