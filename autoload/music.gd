extends Node
## The soundtrack (tools/make_music.py) on the Music bus: one looping track at a time,
## crossfaded, plus one-shot stings. The menu plays the shanty; a patrol plays the calm track
## and switches to the hunted one while escorts are after the boat (Game decides).

const PATH := "res://assets/audio/music_%s.ogg"
## Each track's level under the effects: the patrol track sits well back.
const LEVEL := {"menu": -6.0, "patrol": -12.0, "hunted": -8.0, "win": -4.0, "lost": -4.0}

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _sting: AudioStreamPlayer
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)


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


## A one-shot over the top ("win", "lost"); the loop dips under it.
func sting(name: String) -> void:
	_sting.stream = _stream(name, false)
	_sting.volume_db = float(LEVEL.get(name, -4.0))
	_sting.play()
	var p := _players[_front]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -30.0, 0.4)
	tw.tween_interval(_sting.stream.get_length())
	tw.tween_property(p, "volume_db", float(LEVEL.get(current, -8.0)), 3.0)
