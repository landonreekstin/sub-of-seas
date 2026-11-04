extends Node
## The soundtrack (tools/make_music.py, real recorded instruments): one looping track at a time,
## crossfaded. Only the menu and the Typhoon play one (Blaney: no background music at sea, the
## music there comes from the instruments; a Typhoon has her own choir). It and the jukebox go on the Soundtrack bus, which feeds Music and
## falls silent while anyone aboard plays an instrument (Game calls `hush`).

const PATH := "res://assets/audio/music_%s.ogg"
## Each track's level under the effects: the patrol track sits well back.
const LEVEL := {"menu": -7.0, "typhoon": -7.0} ## the choir as loud as the menu: at -13 it was lost under the boat (Blaney)
const BUS := "Soundtrack"
const HUSHED_DB := -60.0
const HUSH_RATE := 80.0 ## dB a second, so it clears the air in under a second

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _streams := {}
var _hushed := false
var _bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.add_bus()
	_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_bus, BUS)
	AudioServer.set_bus_send(_bus, "Music")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	var at := AudioServer.get_bus_volume_db(_bus)
	AudioServer.set_bus_volume_db(_bus, move_toward(at, HUSHED_DB if _hushed else 0.0, HUSH_RATE * delta))


## Silences the soundtrack and the jukebox while an instrument plays, and lets them back.
func hush(on: bool) -> void:
	_hushed = on


func _stream(track: String, loop: bool) -> AudioStream:
	if not _streams.has(track):
		var s: AudioStreamOggVorbis = load(PATH % track)
		s.loop = loop
		_streams[track] = s
	return _streams[track]


## Crossfades to `track` ("" fades out to silence).
func play(track: String, fade := 2.5) -> void:
	if track == current:
		return
	current = track
	var old := _players[_front]
	_front = 1 - _front
	var new := _players[_front]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade)
	tw.chain().tween_callback(old.stop)
	if track == "":
		return
	new.stream = _stream(track, true)
	new.volume_db = -60.0
	new.play()
	create_tween().tween_property(new, "volume_db", float(LEVEL.get(track, -8.0)), fade)

