extends RefCounted
## The pastimes' rules (Pastimes): arm wrestling, blackjack, the galley, fishing.

var runner: Object


func test_arm_wrestling_bout() -> bool:
	var crew := {}
	runner.check(Pastimes.arm_step(crew, "Ann", "", 0.0) == "", "no bout with an empty seat")
	runner.check(Pastimes.arm_step(crew, "Ann", "Bob", 0.0).contains("lock hands"), "two seated: a bout starts")
	for k in 30:
		Pastimes.arm_push(crew, "arm_a", 2)
	var said := Pastimes.arm_step(crew, "Ann", "Bob", 1.0)
	runner.check(said.contains("Ann slams Bob"), "the harder heaver wins (%s)" % said)
	runner.check(int(crew.arm_wins.Ann) == 1, "the win is chalked up")
	runner.check(Pastimes.arm_step(crew, "Ann", "Bob", 2.0) == "", "a rest before the next bout")
	runner.check(Pastimes.arm_step(crew, "Ann", "Bob", 1.0 + Pastimes.ARM_REST + 0.1) != "", "then they go again")
	return true


func test_blackjack_hands() -> bool:
	runner.check(Pastimes.hand_value([0, 12]) == 21, "ace and king is 21")
	runner.check(Pastimes.hand_value([0, 0, 8]) == 21, "two aces and a nine: 11 + 1 + 9")
	runner.check(Pastimes.hand_value([9, 10, 11]) == 30, "three tens bust")
	var crew := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 40:
		Pastimes.cards_order(crew, "cards_1", "deal", "Ann", rng)
		var t: Dictionary = crew.cards.cards_1
		while t.state == "play" and Pastimes.hand_value(t.hand) < 17:
			Pastimes.cards_order(crew, "cards_1", "hit", "Ann", rng)
		Pastimes.cards_order(crew, "cards_1", "stand", "Ann", rng)
		runner.check(t.state == "done" and t.result != "", "every hand ends")
		runner.check(t.result == "BUST" or Pastimes.hand_value(t.house) >= 17, "the house draws to 17")
	runner.check(int(crew.get("cards_wins", {}).get("Ann", 0)) > 5, "Ann wins some (%d of 40)" % int(crew.get("cards_wins", {}).get("Ann", 0)))
	return true


func test_galley_and_fishing() -> bool:
	var crew := {}
	runner.check(Pastimes.meal(crew, "Cookie", 3).contains("cheer"), "a perfect meal gets a cheer")
	Pastimes.meal(crew, "Cookie", 1)
	runner.check(int(crew.meals.Cookie) == 3, "the best meal is kept")
	var rng := RandomNumberGenerator.new()
	for k in 50:
		var f := Pastimes.catch_fish(rng)
		runner.check(Pastimes.landed(crew, "Ann", int(f[0]), float(f[1])) != "", "a real catch is landed")
	runner.check(Pastimes.landed(crew, "Ann", 6, 500.0) == "", "no 500 kg yellowfin")
	runner.check(crew.has("fish"), "the biggest fish is kept")
	return true
