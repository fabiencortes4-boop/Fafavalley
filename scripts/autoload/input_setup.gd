extends Node
## Déclare les actions d'entrée au démarrage (clavier pour tester sur PC,
## le joystick tactile pilote les mêmes actions sur mobile).

const ACTIONS := {
	"move_left": [KEY_A, KEY_Q, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_Z, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"use_tool": [KEY_SPACE, KEY_E],
	"menu": [KEY_ESCAPE],
}


func _init() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
