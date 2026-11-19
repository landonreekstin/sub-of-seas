extends RefCounted
## The boat's motion (SubMotion): strong on a rough surface, near still deep, never quite still.

const GATO := preload("res://data/subs/gato.tres")

var runner: Object


## The biggest roll over two minutes, in degrees.
func _max_roll(sub: SubState, sea: float) -> float:
	var most := 0.0
	for i in 1200:
		most = maxf(most, absf(SubMotion.attitude(sub, sea, i * 0.1).z))
	return most


func test_rough_surface_rolls_hard_and_deep_is_steady() -> bool:
	var sub := SubState.new(GATO)
	sub.depth = 0.0
	var rough := _max_roll(sub, 2.0)
	var calm := _max_roll(sub, 0.0)
	runner.check(rough > 6.0 and rough < 10.0, "rough seas roll her about 7° (%.1f)" % rough)
	runner.check(calm < 2.0, "a calm sea barely rolls her (%.1f)" % calm)
	sub.depth = 22.0
	var scope := _max_roll(sub, 2.0)
	runner.check(scope < rough * 0.4, "at periscope depth much less (%.1f)" % scope)
	sub.depth = 100.0
	var deep := _max_roll(sub, 2.0)
	runner.check(deep < 0.4, "deep she's nearly still (%.2f)" % deep)
	runner.check(deep > 0.05, "but never quite still (%.2f)" % deep)
	return true


func test_she_heels_in_a_turn_and_heaves_on_the_surface() -> bool:
	var sub := SubState.new(GATO)
	sub.depth = 100.0
	sub.turn_rate = 3.0
	runner.check(SubMotion.attitude(sub, 1.0, 0.0).z > 3.0, "heels in a hard turn")
	sub.turn_rate = 0.0
	var most := 0.0
	sub.depth = 0.0
	for i in 200:
		most = maxf(most, absf(SubMotion.heave(sub, 2.0, i * 0.1)))
	runner.check(most > 0.3, "lifts and drops on a rough sea (%.2f m)" % most)
	return true
