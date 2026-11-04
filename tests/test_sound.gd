extends RefCounted
## The sounds the game plays: every loop goes round all of itself, not just its opening.

var runner: Object


func test_loops_cover_the_whole_sound() -> bool:
	var sfx: Node = load("res://autoload/sfx.gd").new()
	for sound in ["motor_loop", "diesel_loop", "water_loop", "whale_loop", "wheel_loop"]:
		var s: AudioStreamWAV = sfx.stream(sound)
		runner.check(s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % sound)
		runner.check(absf(float(s.loop_end) / s.mix_rate - s.get_length()) < 0.01, "%s plays right through" % sound)
	sfx.free()
	return true


func test_every_record_on_the_jukebox_is_there() -> bool:
	for rec: Array in Jukebox.RECORDS:
		if rec[1] != "":
			runner.check(ResourceLoader.exists("res://assets/audio/music_%s.ogg" % rec[1]), "record %s" % rec[0])
	return true
