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


## The balance pass's rules hold in the code: no sound call asks for more than a 3D sound may
## play (it would be cut silently), and a loop never goes through the one-shot pool.
func test_no_call_is_louder_than_the_cap() -> bool:
	var call := RegEx.create_from_string("Sfx\\.(play|play_at|play_for|loop_at)\\((.*)\\)")
	var volume_arg := {"play": 1, "play_for": 2, "play_at": 3, "loop_at": 3}
	for dir in ["res://game", "res://interior", "res://stations", "res://player", "res://ui", "res://world", "res://autoload"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in lines.size():
				var m := call.search(lines[i])
				if m == null:
					continue
				var where := "%s/%s:%d" % [dir, f, i + 1]
				var args := _top_level_args(m.get_string(2))
				if m.get_string(1) == "play" and not args.is_empty():
					runner.check(not args[0].ends_with("_loop\""), where + " a loop is not a one-shot")
				var k: int = volume_arg[m.get_string(1)]
				if args.size() > k and args[k].is_valid_float():
					runner.check(float(args[k]) <= Sfx.CAP_DB, where + " no louder than Sfx.CAP_DB")
	return true


func _top_level_args(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var depth := 0
	var cur := ""
	for c in text:
		if c in "([{":
			depth += 1
		elif c in ")]}":
			depth -= 1
			if depth < 0:
				break
		if c == "," and depth == 0:
			out.append(cur.strip_edges())
			cur = ""
		else:
			cur += c
	out.append(cur.strip_edges())
	return out


## A sound at a place fades out to nothing a fixed reach away, and the flat pool never loses
## the klaxon when it fills.
func test_3d_sounds_fade_out_and_the_pool_keeps_alarms() -> bool:
	var sfx: Node = load("res://autoload/sfx.gd").new()
	var room := Node3D.new()
	var loop: AudioStreamPlayer3D = sfx.loop_at(room, "water_loop", Vector3.ZERO, 0.0, 4.0)
	runner.check(is_equal_approx(loop.max_distance, 4.0 * sfx.REACH), "a loop fades out at its reach")
	runner.check(is_equal_approx(loop.max_db, sfx.CAP_DB), "capped like the muffling caps it")
	room.free()
	for i in sfx.POOL:
		var p := AudioStreamPlayer.new()
		p.set_meta("sound", "klaxon" if i == 0 else "click")
		p.set_meta("at", i)
		sfx._pool.append(p)
	# None of them is playing outside a tree, so the first idle one comes back.
	runner.check(sfx._free_player() == sfx._pool[0], "an idle player is reused before any is stolen")
	for p in sfx._pool:
		p.free()
	sfx.free()
	return true
