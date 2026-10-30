extends Node
## Registers the input map in code so all bindings are readable in one place.
## Station screens read raw keys for their dials; these are the walking-around actions.
## The first key of each can be rebound in the settings menu (Settings.keys); Esc (pause)
## can't, so there is always a way back to the menus.

const BINDINGS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"crouch": [KEY_CTRL], # hold
	"interact": [KEY_E],
	"leave_station": [KEY_Q],
	"next_station": [KEY_TAB],
	"quit_to_menu": [KEY_F10],
	"drop_tool": [KEY_G],
	"voice": [KEY_CAPSLOCK], # push to talk
	"pause": [KEY_ESCAPE],
	"bot": [KEY_B], # post a bot crewman to an empty station, or stand one down
}
## The rebindable actions, in the settings menu's order, with their names there.
const REBINDABLE := {
	"move_forward": "Walk forward", "move_back": "Walk back", "move_left": "Step left",
	"move_right": "Step right", "jump": "Jump", "crouch": "Crouch (hold)", "interact": "Use / man a station",
	"leave_station": "Leave a station", "next_station": "Next station in a cluster",
	"drop_tool": "Put a tool down", "voice": "Talk (hold)", "bot": "Post / stand down a bot", "quit_to_menu": "Leave to the menu",
}
## Mouse-button actions.
const MOUSE_BINDINGS := {
	"use_tool": [MOUSE_BUTTON_LEFT],
}


func _ready() -> void:
	for action: String in BINDINGS:
		bind(action)
	for action: String in MOUSE_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button: MouseButton in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


## (Re)builds an action's keys: the player's choice for the first, then the other defaults.
func bind(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var list: Array = BINDINGS[action].duplicate()
	if REBINDABLE.has(action):
		list[0] = Settings.key_for(action)
	for key: Key in list:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
