class_name Station
extends Node3D
## A piece of equipment a player mans. Interacting asks the host for the station; once
## granted, the player's camera moves to `view` and input comes here until they leave.
## Stations sharing a `cluster` switch with Tab without leaving station mode.

var station_id := ""
var display_name := ""
var cluster := ""
var view := Transform3D.IDENTITY ## camera transform, local to this station
var overlay: Control ## the on-screen panel while the local player mans this station


func setup(id: String, title: String, cluster_name := "") -> Station:
	station_id = id
	display_name = title
	cluster = cluster_name
	name = id
	return self


## Camera at `eye` looking at `target`, both in this station's local space.
func set_view(eye: Vector3, target: Vector3) -> void:
	view = Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP)
	view.origin = eye


func get_view_transform() -> Transform3D:
	return global_transform * view


func get_prompt(_player: Player) -> String:
	var occupant := Game.instance.station_occupant(station_id)
	if occupant != 0 and occupant != multiplayer.get_unique_id():
		return "%s — manned by %s" % [display_name, Game.instance.crew_name(occupant)]
	return "[E] %s" % display_name


func interact(player: Player) -> void:
	player.request_station(self)


## Send an order for this station to the host, which validates and applies it.
func order(key: String, value: Variant = null) -> void:
	Game.instance.rq_order.rpc_id(1, station_id, key, value)


func make_overlay() -> Control:
	overlay = UiKit.overlay_root()
	_build_overlay(overlay)
	return overlay


func on_enter() -> void:
	pass


func on_leave() -> void:
	overlay = null


# Subclasses override these.
func _build_overlay(_root: Control) -> void:
	pass


func station_input(_event: InputEvent) -> void:
	pass


static func key_pressed(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and event.physical_keycode == key


static func footer(cluster_hint: bool) -> String:
	return "[Q] leave station" + ("    [Tab] next station" if cluster_hint else "")
