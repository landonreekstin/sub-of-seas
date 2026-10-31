extends RefCounted
## Wrestling on deck (Blaney's list): the moves counter each other, a lock sets up the suplex,
## and driving a man past his edge wins.

var runner: Object


func _turn(bout: Dictionary, ma: String, mb: String) -> Dictionary:
	var r := Wrestling.resolve(bout, ma, mb, "A", "B")
	bout.pos += r.shift
	bout.lock = r.lock
	bout.off = r.off
	return r


func test_counters() -> bool:
	var b := Wrestling.new_bout(1, 2, 0.0)
	runner.check(Wrestling.resolve(b, "drag", "push", "A", "B").shift > 0.5, "an arm drag beats a push")
	runner.check(Wrestling.resolve(b, "push", "lock", "A", "B").shift > 0.5, "a push beats a body lock attempt")
	runner.check(Wrestling.resolve(b, "lock", "drag", "A", "B").lock == 1, "a body lock beats an arm drag and holds")
	runner.check(absf(Wrestling.resolve(b, "brace", "brace", "A", "B").shift) < 0.01, "two braces: nothing")
	runner.check(Wrestling.resolve(b, "push", "drag", "A", "B").shift < -0.5, "mirrored: the dragger wins from either side")
	var r := Wrestling.resolve(b, "suplex", "brace", "A", "B")
	runner.check(r.off == 1 and r.shift <= 0.0, "a suplex with no hold leaves you off balance")
	runner.check(r.text.contains("A: Suplex"), "the turn says what both picked")
	return true


func test_lock_then_suplex_wins() -> bool:
	var b := Wrestling.new_bout(1, 2, 0.0)
	_turn(b, "lock", "brace")
	runner.check(b.lock == 1, "A has the body lock")
	_turn(b, "brace", "brace")
	runner.check(b.lock == 1, "the lock is kept while nobody uses or breaks it")
	var r := _turn(b, "suplex", "push")
	runner.check(r.shift >= 2.0, "the suplex throws B toward his edge")
	runner.check(b.lock == 0, "a suplex uses up the lock")
	runner.check(Wrestling.winner(b, 2.5) == 1, "past B's edge: A wins")
	runner.check(Wrestling.winner(b, 4.0) == 0, "on a wider deck B is still on")
	b.lock = 2
	runner.check(_turn(b, "drag", "suplex").lock == 0, "an arm drag breaks the lock")
	return true


func test_off_balance_doubles() -> bool:
	var b := Wrestling.new_bout(1, 2, 0.0)
	_turn(b, "drag", "brace")
	runner.check(b.off == 2, "the arm drag puts B off balance")
	var before: float = b.pos
	var r := _turn(b, "push", "brace")
	runner.check(is_equal_approx(r.shift, 0.4), "off balance, a braced push goes twice as far")
	runner.check(b.pos > before, "toward B's edge")
	return true
