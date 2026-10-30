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
var broken := false ## from the hull state; a broken station ignores its controls
var _sparks: CPUParticles3D
var _broken_label: Label3D
var _heard := {} ## key -> [last value seen, when it last sounded], for sound_on_change
var _loops := {} ## key -> AudioStreamPlayer3D, for sound_while


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


func get_prompt(player: Player) -> String:
	if broken:
		if Sim.world.hull.needs_parts.has(station_id):
			if player.held_tool == "parts":
				return "%s is WRECKED  —  [LMB] hold to fit the spare parts" % display_name
			return "%s is WRECKED  —  bring SPARE PARTS from stores (engine room), then a wrench" % display_name
		if player.held_tool == "wrench":
			return "%s is BROKEN  —  [LMB] hold to repair" % display_name
		return "%s is BROKEN  —  needs a wrench" % display_name
	var occupant := Game.instance.station_occupant(station_id)
	if occupant != 0 and occupant != multiplayer.get_unique_id():
		return "%s — manned by %s" % [display_name, Game.instance.crew_name(occupant)]
	return "[E] %s" % display_name


func interact(player: Player) -> void:
	if not broken:
		player.request_station(self)


func tool_target(tool: String) -> String:
	if not broken:
		return ""
	var wrecked := Sim.world.hull.needs_parts.has(station_id)
	if (tool == "parts" and wrecked) or (tool == "wrench" and not wrecked):
		return station_id
	return ""


## Sparks and a sign while broken. The hitbox centre is a good place for both.
func set_broken(b: bool) -> void:
	if b == broken:
		return
	broken = b
	if _sparks == null:
		var at := Vector3(0, 1.4, 0)
		for c in get_children():
			if c is StaticBody3D:
				at = c.position
				break
		_sparks = Build.particles(self, Color(1.0, 0.85, 0.4), 24, 0.5, Vector3.UP, 2.5, 70.0, Vector3(0, -9, 0), 0.04)
		_sparks.position = at
		_broken_label = Build.label(self, "BROKEN", at + Vector3(0, 0.45, 0), 36, Color("#E0533F"))
		_broken_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_broken_label.no_depth_test = true
	_sparks.emitting = b
	_broken_label.visible = b


func update_broken_label() -> void:
	if _broken_label != null and _broken_label.visible:
		_broken_label.text = "WRECKED" if Sim.world.hull.needs_parts.has(station_id) else "BROKEN"


## Plays `sound` here when `value` differs from last frame's. It is driven by the replicated
## state, so the whole crew hears a control being worked, whoever worked it. A client's own
## order is applied at once and can flicker back for one snapshot, so a key sounds at most
## every 0.2 s. Returns whether it changed.
func sound_on_change(key: String, value: Variant, sound: String, pos := Vector3(0, 1.2, 0), volume_db := 0.0) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if not _heard.has(key):
		_heard[key] = [value, 0.0]
		return false
	if _heard[key][0] == value:
		return false
	_heard[key][0] = value
	if now - float(_heard[key][1]) >= 0.2:
		_heard[key][1] = now
		Sfx.play_at(self, sound, pos, volume_db)
	return true


## A loop at `pos` that plays while `level` (0..1) is above zero, louder as it rises.
func sound_while(key: String, sound: String, level: float, pos := Vector3(0, 1.2, 0), full_db := 0.0) -> void:
	var p: AudioStreamPlayer3D = _loops.get(key)
	if p == null:
		if level <= 0.0:
			return
		p = Sfx.loop_at(self, sound, pos, -80.0)
		_loops[key] = p
	var target := full_db + linear_to_db(clampf(level, 0.001, 1.0)) if level > 0.0 else -60.0
	p.volume_db = move_toward(p.volume_db, target, 240.0 * get_process_delta_time())
	p.stream_paused = p.volume_db <= -59.0


## A single click from this station, heard by this player only (their own knob or dial).
func click(volume_db := 0.0, pitch := 1.0) -> void:
	Sfx.play_at(self, "click", Vector3(0, 1.2, 0), volume_db, pitch)


## Send an order for this station to the host, which validates and applies it.
func order(key: String, value: Variant = null) -> void:
	if broken:
		return
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
