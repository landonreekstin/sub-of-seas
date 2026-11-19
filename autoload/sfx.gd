extends Node
## Sound effects, recordings (tools/make_recorded.py) and a few synthesised ones
## (tools/make_sounds.sh). One-shots play flat or at a point in
## the boat's interior; loops are AudioStreamPlayer3Ds the caller keeps and fades.

const DIR := "res://assets/audio/%s.wav"

const MUFFLED := "Muffled" ## Effects heard through a shut watertight door: dull and low
const GROUP := "sfx_3d" ## every sound at a place in the boat, for SubInterior's muffling
## The loudest a 3D sound plays (SubInterior's muffling caps every one there): a call asking for
## more would be silently cut, so none does (tests/test_sfx.gd).
const CAP_DB := 3.0
## How far a 3D sound carries, in unit sizes: it fades out to nothing there (Godot fades to
## max_distance), so a lever in the bow isn't faintly heard in the stern.
const REACH := 15.0
const POOL := 32 ## flat one-shots at once; when full the oldest gives way (never an alarm)
const ALARMS: Array[String] = ["klaxon", "alarm"]

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
	# The mix's safety net: a gentle squeeze on the effects (a depth-charge pattern with the
	# klaxon and the alarm over it), and a limiter on everything so nothing ever clips.
	var fx := AudioServer.get_bus_index("Effects")
	if fx != -1:
		var squeeze := AudioEffectCompressor.new()
		squeeze.threshold = -14.0
		squeeze.ratio = 3.0
		squeeze.attack_us = 8000.0
		squeeze.release_ms = 250.0
		AudioServer.add_bus_effect(fx, squeeze)
	var limit := AudioEffectHardLimiter.new()
	limit.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limit)


func stream(sound: String) -> AudioStreamWAV:
	if not _streams.has(sound):
		var s: AudioStreamWAV = load(DIR % sound)
		if sound.ends_with("_loop"):
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate) # in samples; the data is compressed
		_streams[sound] = s
	return _streams[sound]


## A one-shot heard the same everywhere in the boat (it comes through the hull). A loop never
## finishes, so it goes through play_for instead.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if sound.ends_with("_loop"):
		play_for(sound, 3.0, volume_db, pitch)
		return
	var p := _free_player()
	if p == null:
		return
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.set_meta("sound", sound)
	p.set_meta("at", Time.get_ticks_msec())
	p.play()


## A loop heard flat for `seconds`, then faded out over two more (a roar that passes).
func play_for(sound: String, seconds: float, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "Effects"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, 2.0).set_delay(seconds)
	tw.tween_callback(p.queue_free)


## An idle pool player, or a new one, or, all POOL busy, the one playing longest that isn't an
## alarm: a burst of hits never loses the klaxon or the newest bang.
func _free_player() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			return q
		if not String(q.get_meta("sound", "")) in ALARMS and (oldest == null or int(q.get_meta("at", 0)) < int(oldest.get_meta("at", 0))):
			oldest = q
	if _pool.size() < POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_pool.append(p)
		return p
	if oldest != null:
		oldest.stop()
	return oldest


## A one-shot from a place inside `parent` (freed when done).
func play_at(parent: Node3D, sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, unit_size := 6.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Effects"
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.max_distance = unit_size * REACH
	p.max_db = CAP_DB
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
	p.max_distance = unit_size * REACH
	p.max_db = CAP_DB
	p.position = pos
	p.add_to_group(GROUP)
	parent.add_child(p)
	p.play()
	return p
