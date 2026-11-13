extends Node
## Sound effects, recordings (tools/make_recorded.py) and a few synthesised ones
## (tools/make_sounds.sh). One-shots play flat or at a point in
## the boat's interior; loops are AudioStreamPlayer3Ds the caller keeps and fades.

const DIR := "res://assets/audio/%s.wav"

const MUFFLED := "Muffled" ## Effects heard through a shut watertight door: dull and low
const GROUP := "sfx_3d" ## every sound at a place in the boat, for SubInterior's muffling

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, MUFFLED)
	AudioServer.set_bus_send(i, "Effects")
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = 550.0
	AudioServer.add_bus_effect(i, low)


func stream(sound: String) -> AudioStreamWAV:
	if not _streams.has(sound):
		var s: AudioStreamWAV = load(DIR % sound)
		if sound.ends_with("_loop"):
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate) # in samples; the data is compressed
		_streams[sound] = s
	return _streams[sound]


## A one-shot heard the same everywhere in the boat (it comes through the hull).
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		if _pool.size() >= 16:
			return
		p = AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_pool.append(p)
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## A one-shot from a place inside `parent` (freed when done).
func play_at(parent: Node3D, sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, unit_size := 6.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Effects"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.position = pos
	p.add_to_group(GROUP)
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## A looping source at `pos` in `parent`, playing.
func loop_at(parent: Node3D, sound: String, pos := Vector3.ZERO, volume_db := 0.0, unit_size := 4.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Effects"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.position = pos
	p.add_to_group(GROUP)
	parent.add_child(p)
	p.play()
	return p
