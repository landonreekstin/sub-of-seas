extends Node
## Runs the OceanWorld. The host steps it authoritatively and broadcasts snapshots at 10 Hz;
## clients keep stepping it locally between snapshots so motion stays smooth.

## Re-emitted world events ("fired", "hit", "dud", "sunk") on every peer.
signal event(kind: String, data: Dictionary)

const SNAPSHOT_INTERVAL := 0.1

var world: OceanWorld
var running := false
var _snap_timer := 0.0


func start(sub_class: SubClassData) -> void:
	world = OceanWorld.new(sub_class, randi())
	world.event.connect(_on_world_event)
	running = true


func stop() -> void:
	running = false
	world = null


func _physics_process(delta: float) -> void:
	if not running:
		return
	var host := multiplayer.is_server()
	world.step(delta, host)
	if host and not multiplayer.get_peers().is_empty():
		_snap_timer += delta
		if _snap_timer >= SNAPSHOT_INTERVAL:
			_snap_timer = 0.0
			_snapshot.rpc(world.to_snapshot())


func _on_world_event(kind: String, data: Dictionary) -> void:
	if multiplayer.is_server():
		_event.rpc(kind, data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(s: Dictionary) -> void:
	if world != null:
		world.apply_snapshot(s)


@rpc("authority", "call_local", "reliable")
func _event(kind: String, data: Dictionary) -> void:
	event.emit(kind, data)
