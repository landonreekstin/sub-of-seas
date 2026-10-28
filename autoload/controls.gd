extends Node
## Registers the input map in code so all bindings are readable in one place.
## Station screens read raw keys for their dials; these are the walking-around actions.

const BINDINGS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"leave_station": [KEY_Q, KEY_ESCAPE],
	"next_station": [KEY_TAB],
	"quit_to_menu": [KEY_F10],
	"drop_tool": [KEY_G],
}
## Mouse-button actions.
const MOUSE_BINDINGS := {
	"use_tool": [MOUSE_BUTTON_LEFT],
}


func _ready() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button: MouseButton in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
