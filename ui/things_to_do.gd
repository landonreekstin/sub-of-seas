class_name ThingsToDo
extends Control
## The "things to do" card (Blaney: "clearer ways to access them and see a list the things we can
## do"; a key easier to hit than F1, so T, next to WASD): every pastime aboard this boat, which
## room it is in and how to use it, what needs her on the surface, and the crew's bests. T opens
## and shuts it; you can still walk about with it up. A small reminder sits in the corner.

var _card: PanelContainer
var _list: Label
var _hint: Label
var _refresh := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = UiKit.label("", 15, UiKit.BRASS)
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position += Vector2(18, -30)
	_card = UiKit.panel()
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_card.position.x = 24
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	box.add_child(UiKit.label("THINGS TO DO ABOARD", 22, UiKit.BRASS))
	_list = UiKit.label("", 15)
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.custom_minimum_size.x = 560
	box.add_child(_list)
	_card.visible = false


func toggle() -> void:
	_card.visible = not _card.visible
	_refresh = 0.0


func is_open() -> bool:
	return _card.visible


func _process(delta: float) -> void:
	var key := OS.get_keycode_string(Settings.key_for("things_to_do"))
	_hint.text = "[%s] %s things to do" % [key, "hide" if _card.visible else ""]
	if not _card.visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.5
	_list.text = text()


## The card's text: the boat's own fun spots, then out on deck, then everywhere, then the bests.
static func text() -> String:
	var lines: Array[String] = []
	var spots := Game.instance.get_tree().get_nodes_in_group(FunSpot.GROUP)
	spots.sort_custom(func(a: FunSpot, b: FunSpot) -> bool: return a.global_position.z < b.global_position.z)
	for f: FunSpot in spots:
		lines.append("• %s  (%s)\n    %s" % [f.title.to_upper(), f.room(), f.how])
	var up := Sim.world != null and Sim.world.sub.is_surfaced()
	var deck := "on the surface" if up else "SURFACE FIRST"
	lines.append("• OUT ON DECK  (%s)\n    climb the bridge-hatch ladder in the conning tower and look up: [E] climbs out" % deck)
	lines.append("• FISHING  (out on deck, the stern)\n    [E] at the stern rail; [Space] strikes when it bites, hold [LMB] to reel, keep the line in the green")
	lines.append("• DECK WRESTLING  (out on deck, the painted ring aft)\n    two step in; [1] push [2] arm drag [3] body lock [4] suplex [5] brace")
	lines.append("• SWIMMING  (over the side)\n    walk off the casing; [E] at a side ladder climbs back aboard")
	lines.append("• EMOTES  (anywhere)\n    [1] wave  [2] salute  [3] jig  [4] point  [5] cheer")
	var bests := records()
	if bests != "":
		lines.append("\nCREW RECORDS\n" + bests)
	return "\n".join(lines)


## The crew's bests at every pastime, from crew state.
static func records() -> String:
	var crew: Dictionary = Game.instance.crew
	var out: Array[String] = []
	for k: Array in [["darts", "Darts, best turn: %s %d"], ["arm_wins", "Arm wrestling, most wins: %s %d"], ["cards_wins", "Blackjack, most hands won: %s %d"]]:
		var d: Dictionary = crew.get(k[0], {})
		if d.is_empty():
			continue
		var best: String = d.keys()[0]
		for n: String in d:
			if int(d[n]) > int(d[best]):
				best = n
		out.append(String(k[1]) % [best, int(d[best])])
	var meals: Dictionary = crew.get("meals", {})
	if not meals.is_empty():
		var cook: String = meals.keys()[0]
		for n: String in meals:
			if int(meals[n]) > int(meals[cook]):
				cook = n
		out.append("Best cook: %s (%s)" % [cook, Pastimes.MEALS[int(meals[cook])]])
	var fish: Dictionary = crew.get("fish", {})
	if not fish.is_empty():
		var who: String = fish.keys()[0]
		for n: String in fish:
			if float(fish[n][1]) > float(fish[who][1]):
				who = n
		out.append("Biggest fish: %s, a %.1f kg %s" % [who, float(fish[who][1]), fish[who][0]])
	return "\n".join(out)
