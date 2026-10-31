class_name Band
extends RefCounted
## The crew's band (Blaney: "instruments of all types that all play parts of a sea shanty like
## Sea of Thieves, so when all the instruments are in then it is a complete song"). Each
## instrument (Tools.INSTRUMENTS) has its own part of the song in assets/audio/shanty_<kind>.ogg
## (tools/make_shanty.py); all the parts are the same length and run on one clock, the patrol's
## sim time, so whoever starts playing comes in on the same bar as everyone else.
## First song: "The Foggy Dew" (the traditional air; our own arrangement).

const SONG := "The Foggy Dew"
const DRIFT := 0.12 ## s a part may wander off the clock before it is put back

static var _streams := {}


static func stream(kind: String) -> AudioStreamOggVorbis:
	if not _streams.has(kind):
		var s: AudioStreamOggVorbis = load("res://assets/audio/shanty_%s.ogg" % kind)
		s.loop = true
		_streams[kind] = s
	return _streams[kind]


## Where the song is now, in seconds into a part `length` long.
static func clock(length: float) -> float:
	return fposmod(Sim.world.time if Sim.world != null else 0.0, length)


## Keeps `player` playing `kind` in time with the band, or stops it.
static func keep_time(player: AudioStreamPlayer3D, kind: String, on: bool) -> void:
	if not on:
		if player.playing:
			player.stop()
		return
	var s := stream(kind)
	if player.stream != s:
		player.stream = s
	var length := s.get_length()
	var at := clock(length)
	if not player.playing:
		player.play(at)
		return
	var off := absf(player.get_playback_position() - at)
	if minf(off, length - off) > DRIFT:
		player.seek(at)
