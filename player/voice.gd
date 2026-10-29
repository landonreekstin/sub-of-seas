class_name Voice
extends Node3D
## Proximity voice. Hold Caps Lock to talk: the microphone (opened only while talking) is
## mixed to mono, cut to 16 kHz 16-bit and sent unreliably to everyone; each crewman's voice
## plays from his head, so it fades with distance and through the boat.

const RATE := 16000
const SEND_EVERY := 0.06 ## s
const BUS := "Mic"

var player: Player
var talking := false
var test_tone := false ## testing aid: send a tone instead of the microphone
var _mic: AudioStreamPlayer
var _capture: AudioEffectCapture
var _out: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _send_timer := 0.0
var _phase := 0.0
var _carry := 0.0 ## fractional input sample carried between chunks when resampling


func _ready() -> void:
	if player.is_local():
		_capture = _mic_bus()
	else:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.4
		_out = AudioStreamPlayer3D.new()
		_out.stream = gen
		_out.unit_size = 3.0
		_out.max_distance = 30.0
		add_child(_out)
		_out.play()
		_playback = _out.get_stream_playback()


## A muted bus with a capture effect: the microphone plays into it, we read it back.
static func _mic_bus() -> AudioEffectCapture:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_mute(i, true)
		AudioServer.add_bus_effect(i, AudioEffectCapture.new())
	return AudioServer.get_bus_effect(i, 0) as AudioEffectCapture


func _process(delta: float) -> void:
	if not player.is_local():
		return
	var want := test_tone or (Input.is_action_pressed("voice") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if want != talking:
		talking = want
		_set_mic(talking and not test_tone)
		Game.instance.hud.set_talking(talking)
	if not talking:
		return
	_send_timer += delta
	if _send_timer < SEND_EVERY:
		return
	var samples := _tone(_send_timer) if test_tone else _from_mic()
	_send_timer = 0.0
	if not samples.is_empty():
		hear.rpc(encode(samples))


func _set_mic(on: bool) -> void:
	if on and _mic == null:
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = BUS
		add_child(_mic)
		_mic.play()
	elif not on and _mic != null:
		_mic.queue_free()
		_mic = null
		_capture.clear_buffer()


func _from_mic() -> PackedFloat32Array:
	var frames := _capture.get_buffer(_capture.get_frames_available())
	var step := AudioServer.get_mix_rate() / RATE
	var out := PackedFloat32Array()
	var t := _carry
	while t < frames.size():
		var f := frames[int(t)]
		out.append((f.x + f.y) * 0.5)
		t += step
	_carry = t - frames.size()
	return out


func _tone(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in int(seconds * RATE):
		_phase += TAU * 440.0 / RATE
		out.append(sin(_phase) * 0.5)
	return out


static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	return b


static func decode(b: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(b.size() / 2)
	for i in out.size():
		out[i] = b.decode_s16(i * 2) / 32767.0
	return out


@rpc("authority", "call_remote", "unreliable_ordered")
func hear(data: PackedByteArray) -> void:
	if _playback == null or data.size() > RATE: # half a second at most per packet
		return
	for s in decode(data):
		if not _playback.can_push_buffer(1):
			break
		_playback.push_frame(Vector2(s, s))
